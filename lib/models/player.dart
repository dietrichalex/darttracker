import 'dart_throw.dart';
import 'dart:math';

class LegStat {
  final int legIndex;
  final double average;
  final int dartsThrown;
  final bool won;
  final double firstNineAvg; 
  final int checkoutAttempts; 

  LegStat({
    required this.legIndex, 
    required this.average, 
    required this.dartsThrown, 
    required this.won,
    required this.firstNineAvg,
    required this.checkoutAttempts,
  });

  double get checkoutPercent {
    if (checkoutAttempts == 0) return 0.0;
    return (won ? 1 : 0) / checkoutAttempts * 100;
  }
}

class Player {
  final String name;
  int currentScore = 501;
  
  // MATCH PROGRESS
  int legsWon = 0;
  int setsWon = 0;
  int totalLegsWon = 0; // Cumulative across sets
  
  // STATS TRACKING
  int checkoutAttempts = 0; 
  List<DartThrow> history = [];
  List<LegStat> legStats = [];
  
  // INTERNAL HELPERS
  int _historyIndexAtLegStart = 0;

  Player(this.name);

  // --- 1. STABLE MATCH AVERAGE ---
  // Calculates average based only on COMPLETED turns (or busts/wins).
  // Prevents the "20 score -> 60 avg" spike.
  double get average {
    if (history.isEmpty) return 0.0;
    
    int totalPoints = 0;
    int totalDarts = 0;

    // Logic: Group darts by Turn Index
    List<DartThrow> currentBatch = [];
    int currentBatchIndex = -1;

    for (var t in history) {
      if (t.turnIndex != currentBatchIndex) {
        // Process the previous (completed) batch
        if (currentBatch.isNotEmpty) {
           for (var d in currentBatch) {
             if (d.scoreCounted) totalPoints += d.total;
             totalDarts++;
           }
        }
        // Start new batch
        currentBatch = [t];
        currentBatchIndex = t.turnIndex;
      } else {
        currentBatch.add(t);
      }
    }

    // Process the FINAL batch (Current turn)
    if (currentBatch.isNotEmpty) {
      bool isBust = currentBatch.any((t) => !t.scoreCounted);
      bool isComplete = currentBatch.length == 3;
      bool isWin = (currentScore == 0); 

      // Only count if the turn is effectively "over"
      if (isBust || isComplete || isWin) {
         for (var d in currentBatch) {
             if (d.scoreCounted) totalPoints += d.total;
             totalDarts++;
         }
      }
    }

    if (totalDarts == 0) return 0.0;
    return totalPoints / (totalDarts / 3); 
  }

  // --- 2. CURRENT LEG AVERAGE ---
  // Same logic as Match Average, but filtered for specific leg number
  double currentLegAverage(int currentLegNum) {
    var legDarts = history.where((t) => t.legNumber == currentLegNum).toList();
    if (legDarts.isEmpty) return 0.0;
    
    int totalPoints = 0;
    int totalDarts = 0;
    
    List<DartThrow> currentBatch = [];
    int currentBatchIndex = -1;

    for (var t in legDarts) {
       if (t.turnIndex != currentBatchIndex) {
          if (currentBatch.isNotEmpty) {
             for (var d in currentBatch) {
               if (d.scoreCounted) totalPoints += d.total;
               totalDarts++;
             }
          }
          currentBatch = [t];
          currentBatchIndex = t.turnIndex;
       } else {
         currentBatch.add(t);
       }
    }

    // Process final batch
    if (currentBatch.isNotEmpty) {
      bool isBust = currentBatch.any((t) => !t.scoreCounted);
      bool isComplete = currentBatch.length == 3;
      bool isWin = (currentScore == 0); 
      if (isBust || isComplete || isWin) {
         for (var d in currentBatch) {
             if (d.scoreCounted) totalPoints += d.total;
             totalDarts++;
         }
      }
    }

    if (totalDarts == 0) return 0.0;
    return totalPoints / (totalDarts / 3);
  }

  // --- 3. LAST N SCORES ---
  // Returns a list of strings like ["60", "100", "BUST", "45"]
  List<String> getLastScores(int count) {
    List<String> scores = [];
    if (history.isEmpty) return [];

    int currentTIdx = -1;
    int currentSum = 0;
    bool currentValid = true;

    // Iterate backwards to get newest first
    for (var t in history.reversed) {
      if (t.turnIndex != currentTIdx) {
        if (currentTIdx != -1) {
          scores.add(currentValid ? "$currentSum" : "BUST");
          if (scores.length >= count) return scores;
        }
        currentTIdx = t.turnIndex;
        currentSum = 0;
        currentValid = true;
      }
      
      if (!t.scoreCounted) currentValid = false;
      currentSum += t.total;
    }
    // Add the final one processed
    scores.add(currentValid ? "$currentSum" : "BUST");
    return scores;
  }

  // --- 4. STANDARD STATS GETTERS ---

  double get checkoutPercentage {
    if (checkoutAttempts == 0) return 0.0;
    return (totalLegsWon / checkoutAttempts) * 100;
  }

  String get bestLeg {
    var wins = legStats.where((l) => l.won);
    if (wins.isEmpty) return "-";
    int minDarts = wins.map((l) => l.dartsThrown).reduce(min);
    return "$minDarts";
  }

  double get firstNineAverage {
    if (legStats.isEmpty) return 0.0;
    double total = legStats.fold(0.0, (sum, l) => sum + l.firstNineAvg);
    return total / legStats.length;
  }

  // --- 5. LEG SNAPSHOT ---
  // Called when a leg finishes to save permanent stats
  void snapshotLegStats(int legIndex, bool isWinner, int startScore) {
    List<DartThrow> legThrows = history.sublist(_historyIndexAtLegStart);
    
    // Calculate Average for this leg
    int totalPoints = legThrows.where((t) => t.scoreCounted).fold(0, (sum, t) => sum + t.total);
    double legAvg = legThrows.isEmpty ? 0.0 : (totalPoints / (legThrows.length / 3));

    // Calculate First 9 Average
    double first9 = 0.0;
    if (legThrows.isNotEmpty) {
      int dartsToCount = min(9, legThrows.length);
      int first9Points = legThrows.take(dartsToCount)
          .where((t) => t.scoreCounted)
          .fold(0, (sum, t) => sum + t.total);
      first9 = (first9Points / (dartsToCount / 3));
    }

    int previousLegAttempts = legStats.fold(0, (sum, l) => sum + l.checkoutAttempts);
    int attemptsThisLeg = checkoutAttempts - previousLegAttempts;

    legStats.add(LegStat(
      legIndex: legIndex,
      average: legAvg,
      dartsThrown: legThrows.length,
      won: isWinner,
      firstNineAvg: first9,
      checkoutAttempts: attemptsThisLeg,
    ));
    
    _historyIndexAtLegStart = history.length; 
  }

  // --- 6. HIGH SCORES (100+, 140+, 180) ---
  int countScore(int min, [int? max]) {
    int count = 0;
    if (history.isEmpty) return 0;
    
    int currentTurn = history.first.turnIndex;
    int currentTurnTotal = 0;
    bool currentTurnValid = true;
    
    for (var t in history) {
      if (t.turnIndex != currentTurn) {
        // Evaluate previous turn
        if (currentTurnValid) {
           if (max != null) {
             if (currentTurnTotal >= min && currentTurnTotal < max) count++;
           } else {
             if (currentTurnTotal >= min) count++;
           }
        }
        // Reset
        currentTurn = t.turnIndex;
        currentTurnTotal = 0;
        currentTurnValid = true;
      }
      
      if (!t.scoreCounted) currentTurnValid = false; // Bust voids the turn
      currentTurnTotal += t.total;
    }
    
    // Evaluate last turn
    if (currentTurnValid) {
       if (max != null) {
         if (currentTurnTotal >= min && currentTurnTotal < max) count++;
       } else {
         if (currentTurnTotal >= min) count++;
       }
    }
    
    return count;
  }
}