class MatchConfig {
  final List<String> playerNames;
  final int setsToWin;
  final int legsToWinSet;
  final int startingScore;

  MatchConfig({
    required this.playerNames,
    required this.setsToWin,
    required this.legsToWinSet,
    required this.startingScore,
  });
}