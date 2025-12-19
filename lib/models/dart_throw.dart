class DartThrow {
  final int value;
  final int multiplier;
  final int scoreBefore;
  final int playerId;

  DartThrow({
    required this.value,
    required this.multiplier,
    required this.scoreBefore,
    required this.playerId,
  });

  int get total => value * multiplier;
}