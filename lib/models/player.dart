import 'dart_throw.dart';

// New helper model for a single leg's performance
class LegStat {
  final int legIndex; // 1, 2, 3...
  final double average;
  final int dartsThrown;
  final bool won;
  
  LegStat({required this.legIndex, required this.average, required this.dartsThrown, required this.won});
}

class Player {
  final String name;
  int currentScore = 501;
  int legsWon = 0;
  int setsWon = 0;
  int totalLegsWon = 0;
  int checkoutAttempts = 0;
  
  List<DartThrow> history = []; // ALL throws in the match (for Overall Avg)
  List<LegStat> legStats = [];  // Snapshots of finished legs
  
  // Helper to track where the current leg started in the history list
  int _historyIndexAtLegStart = 0;

  Player(this.name);

  // Overall Match Average
  double get average {
    if (history.isEmpty) return 0.0;
    int total = history.fold(0, (sum, t) => sum + t.total);
    return (total / (history.length / 3));
  }

  double get checkoutPercentage {
    if (checkoutAttempts == 0) return 0.0;
    return (totalLegsWon / checkoutAttempts) * 100;
  }

  // Called when a leg finishes to snapshot stats
  void snapshotLegStats(int legIndex, bool isWinner, int startScore) {
    // Get throws only for this specific leg
    // We slice the history from where the leg started to now
    List<DartThrow> legThrows = history.sublist(_historyIndexAtLegStart);
    
    int totalPoints = legThrows.fold(0, (sum, t) => sum + t.total);
    double legAvg = legThrows.isEmpty ? 0.0 : (totalPoints / (legThrows.length / 3));
    
    legStats.add(LegStat(
      legIndex: legIndex,
      average: legAvg,
      dartsThrown: legThrows.length,
      won: isWinner
    ));
    
    // Reset the marker for the next leg
    _historyIndexAtLegStart = history.length; 
  }

  int countScore(int min, [int? max]) {
    int count = 0;
    for (int i = 0; i <= history.length - 3; i += 3) {
      int visitTotal = history[i].total + history[i+1].total + history[i+2].total;
      if (max != null) {
        if (visitTotal >= min && visitTotal < max) count++;
      } else {
        if (visitTotal >= min) count++;
      }
    }
    return count;
  }
}