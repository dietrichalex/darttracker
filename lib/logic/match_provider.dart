import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/dart_throw.dart';
import '../models/match_config.dart';
import '../ui/summary_screen.dart';
import 'db_helper.dart';

class MatchProvider with ChangeNotifier {
  late MatchConfig config;
  List<Player> players = [];
  List<DartThrow> globalHistory = []; 
  
  int currentPlayerIndex = 0;
  int currentDartCount = 0;
  int multiplier = 1;

  void setupMatch(MatchConfig newConfig) {
    config = newConfig;
    players = config.playerNames.map((name) => Player(name)..currentScore = config.startingScore).toList();
    globalHistory = [];
    currentPlayerIndex = 0;
    currentDartCount = 0;
    notifyListeners();
  }

  Player get activePlayer => players[currentPlayerIndex];

  void setMultiplier(int m) {
    multiplier = (multiplier == m) ? 1 : m;
    notifyListeners();
  }

  // handleInput calls the async _winLeg
  void handleInput(int val, BuildContext context) async {
    int score = val * multiplier;
    Player p = activePlayer;
    int scoreBefore = p.currentScore;

    if (p.currentScore <= 170 && multiplier == 2) {
     p.checkoutAttempts++;
  }

    if (p.currentScore - score == 0 && multiplier == 2) {
      final t = DartThrow(value: val, multiplier: multiplier, scoreBefore: scoreBefore, playerId: currentPlayerIndex);
      p.history.add(t);
      globalHistory.add(t);
      await _winLeg(p, context);
    } 
    else if (p.currentScore - score <= 1) {
      _endTurn(); 
    } 
    else {
      final t = DartThrow(value: val, multiplier: multiplier, scoreBefore: scoreBefore, playerId: currentPlayerIndex);
      p.history.add(t);
      globalHistory.add(t);
      p.currentScore -= score;
      
      currentDartCount++;
      if (currentDartCount == 3) _endTurn();
    }
    
    multiplier = 1;
    notifyListeners();
  }

  Future<void> _winLeg(Player p, BuildContext context) async {
    p.legsWon++;

    if (p.legsWon >= config.legsToWinSet) {
      p.setsWon++;
      for (var pl in players) pl.legsWon = 0;
    }

    if (p.setsWon >= config.setsToWin) {
      // Save to Database
      try {
        final db = await DBHelper.database;
        await db.insert('matches', {
          'winner': p.name,
          'avg': p.average.toStringAsFixed(1),
          'date': DateTime.now().toString().substring(0, 16),
        });
      } catch (e) {
        debugPrint("DB Save Error: $e");
      }

      // Navigate to Summary
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (c) => SummaryScreen(players: players)),
          (route) => false,
        );
      }
    } else {
      // Reset for next leg
      for (var pl in players) pl.currentScore = config.startingScore;
      currentDartCount = 0;
      currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
      notifyListeners();
    }
  }

  void undo() {
    if (globalHistory.isEmpty) return;
    final lastThrow = globalHistory.removeLast();
    currentPlayerIndex = lastThrow.playerId;
    players[currentPlayerIndex].currentScore = lastThrow.scoreBefore;
    players[currentPlayerIndex].history.removeLast();
    
    int count = 0;
    for (int i = globalHistory.length - 1; i >= 0; i--) {
      if (globalHistory[i].playerId == currentPlayerIndex) {
        count++;
        if (count == 3) break;
      } else { break; }
    }
    currentDartCount = count % 3;
    notifyListeners();
  }

  void _endTurn() {
    currentDartCount = 0;
    currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
  }
}