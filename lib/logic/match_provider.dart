import 'dart:convert';
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
  List<String> matchLog = [];
  
  int currentPlayerIndex = 0;
  int currentDartCount = 0;
  int multiplier = 1;
  int currentLegNumber = 1;

  void setupMatch(MatchConfig newConfig) async {
    config = newConfig;
    players = config.playerNames.map((name) => Player(name)..currentScore = config.startingScore).toList();
    globalHistory = [];
    matchLog = [];
    currentPlayerIndex = 0;
    currentDartCount = 0;
    currentLegNumber = 1;
    
    for (String name in config.playerNames) {
      await DBHelper.addPlayer(name);
    }
    notifyListeners();
  }

  Player get activePlayer => players[currentPlayerIndex];

  void setMultiplier(int m) {
    multiplier = (multiplier == m) ? 1 : m;
    notifyListeners();
  }

  void handleInput(int val, BuildContext context) async {
    Player p = activePlayer;
    int scoreThisDart = val * multiplier;
    int scoreBefore = p.currentScore;

    if (p.currentScore <= 170 && multiplier == 2) {
       p.checkoutAttempts++;
    }

    if (p.currentScore - scoreThisDart == 0 && multiplier == 2) {
      final t = DartThrow(value: val, multiplier: multiplier, scoreBefore: scoreBefore, playerId: currentPlayerIndex);
      p.history.add(t);
      globalHistory.add(t);
      await _winLeg(p, context);
    } 
    else if (p.currentScore - scoreThisDart <= 1) {
      _endTurn(); 
    } 
    else {
      final t = DartThrow(value: val, multiplier: multiplier, scoreBefore: scoreBefore, playerId: currentPlayerIndex);
      p.history.add(t);
      globalHistory.add(t);
      p.currentScore -= scoreThisDart;
      currentDartCount++;
      if (currentDartCount == 3) _endTurn();
    }
    multiplier = 1;
    notifyListeners();
  }

  Future<void> _winLeg(Player winner, BuildContext context) async {
    winner.legsWon++;
    winner.totalLegsWon++;
    matchLog.add("Leg $currentLegNumber: Won by ${winner.name}");

    // 1. SNAPSHOT STATS
    for (var p in players) {
      bool isWin = (p == winner);
      p.snapshotLegStats(currentLegNumber, isWin, config.startingScore);
    }
    currentLegNumber++;

    if (winner.legsWon >= config.legsToWinSet) {
      winner.setsWon++;
      for (var pl in players) pl.legsWon = 0;
    }

    if (winner.setsWon >= config.setsToWin) {
      // 2. BUILD RICH HISTORY JSON
      // We construct a list of legs, where each leg has stats for all players
      List<Map<String, dynamic>> fullHistory = [];
      
      // Assuming all players have the same number of recorded legs
      int totalLegsPlayed = players[0].legStats.length;
      
      for (int i = 0; i < totalLegsPlayed; i++) {
        List<Map<String, dynamic>> legPlayerStats = [];
        for (var p in players) {
          if (i < p.legStats.length) {
            final stat = p.legStats[i];
            legPlayerStats.add({
              'name': p.name,
              'avg': stat.average.toStringAsFixed(1),
              'darts': stat.dartsThrown,
              'won': stat.won
            });
          }
        }
        fullHistory.add({
          'leg_number': i + 1,
          'players': legPlayerStats
        });
      }

      // 3. SAVE TO DB
      await DBHelper.saveMatch({
        'winner': winner.name,
        'avg': winner.average.toStringAsFixed(1),
        'date': DateTime.now().toString().substring(0, 16),
        'details': jsonEncode(fullHistory), // Save the rich JSON
      });

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (c) => SummaryScreen(players: players, legLog: matchLog)),
          (route) => false,
        );
      }
    } else {
      for (var pl in players) pl.currentScore = config.startingScore;
      currentDartCount = 0;
      currentPlayerIndex = (currentLegNumber - 1) % players.length;
      notifyListeners();
    }
  }

  void undo() {
    if (globalHistory.isEmpty) return;
    final lastThrow = globalHistory.removeLast();
    
    if (lastThrow.scoreBefore <= 170 && lastThrow.multiplier == 2) {
       players[lastThrow.playerId].checkoutAttempts--;
    }

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