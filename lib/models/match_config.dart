enum MatchMode { firstTo, bestOf }

class MatchConfig {
  final List<String> playerNames;
  final MatchMode mode; // Best Of vs First To
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

  // LOGIC:
  // First to 5 -> Target is 5.
  // Best of 5 -> Target is 3 (Floor(5/2) + 1).

  int get legsNeededToWin {
    if (mode == MatchMode.firstTo) return legsToWinSet;
    return (legsToWinSet / 2).floor() + 1; 
  }

  int get setsNeededToWin {
    if (mode == MatchMode.firstTo) return setsToWin;
    return (setsToWin / 2).floor() + 1; 
  }
}