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
    int total = history.fold(0, (sum, t) => sum + t.total);
    return (total / (history.length / 3)); 
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
    
    int totalPoints = legThrows.fold(0, (sum, t) => sum + t.total);
    double legAvg = legThrows.isEmpty ? 0.0 : (totalPoints / (legThrows.length / 3));

    // Calculate First 9 Avg
    double first9 = 0.0;
    if (legThrows.isNotEmpty) {
      int dartsToCount = min(9, legThrows.length);
      int first9Total = legThrows.take(dartsToCount).fold(0, (sum, t) => sum + t.total);
      first9 = (first9Total / (dartsToCount / 3));
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