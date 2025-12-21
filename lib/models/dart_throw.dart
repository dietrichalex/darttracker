class DartThrow {
  final int value;
  final int multiplier;
  final int scoreBefore;
  final int playerId;
  final int legNumber;
  final int turnIndex;

  DartThrow({
    required this.value,
    required this.multiplier,
    required this.scoreBefore,
    required this.playerId,
    required this.legNumber,
    required this.turnIndex,
  });

  int get total => value * multiplier;
}