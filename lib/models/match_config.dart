enum MatchMode { firstTo, bestOf }

class MatchConfig {
  final List<String> playerNames;
  final MatchMode mode; // New: Best Of vs First To
  final int setsToWin;
  final int legsToWinSet;
  final int startingScore;

  MatchConfig({
    required this.playerNames,
    required this.mode,
    required this.setsToWin,
    required this.legsToWinSet,
    required this.startingScore,
  });

  // Logic: "Best of 5" means you need 3 wins. "First to 3" means you need 3 wins.
  int get legsNeededToWin {
    if (mode == MatchMode.firstTo) return legsToWinSet;
    return (legsToWinSet / 2).floor() + 1; 
  }
}