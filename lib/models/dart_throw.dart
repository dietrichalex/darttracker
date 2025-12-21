class DartThrow {
  final int value;
  final int multiplier;
  final int scoreBefore;
  final int playerId;
  final int legNumber;
  final int turnIndex;
  final bool scoreCounted;

  DartThrow({
    required this.value,
    required this.multiplier,
    required this.scoreBefore,
    required this.playerId,
    required this.legNumber,
    required this.turnIndex,
    this.scoreCounted = true,
  });

  int get total => value * multiplier;
}