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
  int legsWon = 0;
  int setsWon = 0;
  
  // STATS
  int totalLegsWon = 0;
  int checkoutAttempts = 0; 
  List<DartThrow> history = [];
  List<LegStat> legStats = [];
  
  int _historyIndexAtLegStart = 0;

  Player(this.name);

  double get average {
    if (history.isEmpty) return 0.0;
    
    int totalPoints = 0;
    int totalDarts = 0;

    // 1. Group darts by Turn Index to analyze them as "Visits"
    List<DartThrow> currentBatch = [];
    int currentBatchIndex = -1;

    for (var t in history) {
      if (t.turnIndex != currentBatchIndex) {
        // New batch starting, process the old one (Previous batches are ALWAYS finalized)
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

    // 2. Process the FINAL batch (The one currently happening or just finished)
    if (currentBatch.isNotEmpty) {
      bool isBust = currentBatch.any((t) => !t.scoreCounted);
      bool isComplete = currentBatch.length == 3;
      // If score is 0, this last turn MUST be the winning turn
      bool isWin = (currentScore == 0); 

      // Only count this last turn if it's "Done" (Stable Average Rule)
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

  void snapshotLegStats(int legIndex, bool isWinner, int startScore) {
    List<DartThrow> legThrows = history.sublist(_historyIndexAtLegStart);
    
    // Calculate Leg Average
    int totalPoints = legThrows.where((t) => t.scoreCounted).fold(0, (sum, t) => sum + t.total);
    double legAvg = legThrows.isEmpty ? 0.0 : (totalPoints / (legThrows.length / 3));

    // Calculate First 9 Avg
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
      
      if (!t.scoreCounted) currentTurnValid = false; 
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