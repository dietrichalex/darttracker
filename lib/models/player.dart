import 'dart_throw.dart';

class Player {
  final String name;
  int currentScore = 501;
  int legsWon = 0;
  int setsWon = 0;
  int checkoutAttempts = 0;
  List<DartThrow> history = [];

  Player(this.name);

  double get average {
    if (history.isEmpty) return 0.0;
    int total = history.fold(0, (sum, t) => sum + t.total);
    return (total / (history.length / 3));
  }

  double get checkoutPercentage {
    if (checkoutAttempts == 0) return 0.0;
    return (legsWon / checkoutAttempts) * 100;
  }

  int countScore(int min, [int? max]) {
    int count = 0;
    for (int i = 0; i <= history.length - 3; i += 3) {
      int visitTotal = 0;
      for (int j = 0; j < 3 && (i + j) < history.length; j++) {
        visitTotal += history[i + j].total;
      }
      if (max != null) {
        if (visitTotal >= min && visitTotal < max) count++;
      } else {
        if (visitTotal >= min) count++;
      }
    }
    return count;
  }
}