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
  int currentTurnIndex = 1;

  void setupMatch(MatchConfig newConfig) async {
    config = newConfig;
    players = config.playerNames.map((name) => Player(name)..currentScore = config.startingScore).toList();
    globalHistory = [];
    matchLog = [];
    currentPlayerIndex = 0;
    currentDartCount = 0;
    currentLegNumber = 1;
    currentTurnIndex = 1;
    
    for (String name in config.playerNames) {
      await DBHelper.addPlayer(name);
    }
    notifyListeners();
  }

  Player get activePlayer => players[currentPlayerIndex];

  List<DartThrow> get currentTurnDarts {
    return activePlayer.history.where((t) => t.turnIndex == currentTurnIndex).toList();
  }

  void setMultiplier(int m) {
    multiplier = (multiplier == m) ? 1 : m;
    notifyListeners();
  }

  void handleInput(int val, BuildContext context) async {
    Player p = activePlayer;
    int scoreThisDart = val * multiplier;
    int scoreBefore = p.currentScore;
    int scoreRemaining = scoreBefore - scoreThisDart;

    // --- IMPROVED CHECKOUT STATS LOGIC ---
    // A "Checkout Attempt" is defined as any dart thrown when the score 
    // is a valid "Double" target (Even number <= 40, or 50 for Bull).
    // This captures missed doubles (e.g. hitting S20 when on 40), which the old logic missed.
    bool isDoubleTarget = (scoreBefore <= 40 && scoreBefore % 2 == 0) || (scoreBefore == 50);
    
    if (isDoubleTarget) {
      p.checkoutAttempts++;
    }

    final t = DartThrow(
      value: val, 
      multiplier: multiplier, 
      scoreBefore: scoreBefore, 
      playerId: currentPlayerIndex,
      legNumber: currentLegNumber,
      turnIndex: currentTurnIndex,
      scoreCounted: true 
    );

    if (scoreRemaining == 0 && multiplier == 2) {
      // WIN
      p.history.add(t);
      globalHistory.add(t);
      await _finalizeLeg(p, context);
    } 
    else if (scoreRemaining <= 1) {
      // BUST
      p.history.add(t);     
      globalHistory.add(t); 
      _endTurn(bust: true); 
    } 
    else {
      // NORMAL
      p.history.add(t);
      globalHistory.add(t);
      p.currentScore -= scoreThisDart;
      currentDartCount++;
      if (currentDartCount == 3) _endTurn();
    }
    
    multiplier = 1;
    notifyListeners();
  }

  Future<void> _finalizeLeg(Player winner, BuildContext context) async {
    winner.legsWon++;
    winner.totalLegsWon++;
    matchLog.add("Leg $currentLegNumber: Won by ${winner.name}");

    for (var p in players) {
      bool isWin = (p == winner);
      p.snapshotLegStats(currentLegNumber, isWin, config.startingScore);
    }
    currentLegNumber++;

    if (winner.legsWon >= config.legsNeededToWin) {
      winner.setsWon++;
      for (var pl in players) pl.legsWon = 0; 
    }

    if (winner.setsWon >= config.setsNeededToWin) {
      await _saveAndExit(winner, context);
    } else {
      for (var pl in players) pl.currentScore = config.startingScore;
      currentDartCount = 0;
      currentTurnIndex++;
      currentPlayerIndex = (currentLegNumber - 1) % players.length;
      notifyListeners();
    }
  }

  Future<void> _saveAndExit(Player winner, BuildContext context) async {
    List<Map<String, dynamic>> fullHistory = [];
    int totalLegs = players[0].legStats.length;
      
    for (int i = 0; i < totalLegs; i++) {
      List<Map<String, dynamic>> legPlayerStats = [];
      for (var p in players) {
        if (i < p.legStats.length) {
          final stat = p.legStats[i];
          legPlayerStats.add({
            'name': p.name,
            'avg': stat.average.toStringAsFixed(1),
            'first9': stat.firstNineAvg.toStringAsFixed(1),
            'co_percent': stat.checkoutPercent.toStringAsFixed(0),
            'darts': stat.dartsThrown,
            'won': stat.won
          });
        }
      }
      fullHistory.add({'leg_number': i + 1, 'players': legPlayerStats});
    }

    await DBHelper.saveMatch({
      'winner': winner.name,
      'avg': winner.average.toStringAsFixed(1),
      'date': DateTime.now().toString().substring(0, 16),
      'details': jsonEncode(fullHistory),
    });

    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (c) => SummaryScreen(players: players, legLog: matchLog)),
        (route) => false,
      );
    }
  }

  void undo() {
    if (globalHistory.isEmpty) return;
    if (globalHistory.last.legNumber != currentLegNumber) return;

    final lastThrow = globalHistory.removeLast();
    
    // REVERSE NEW CHECKOUT LOGIC
    bool wasDoubleTarget = (lastThrow.scoreBefore <= 40 && lastThrow.scoreBefore % 2 == 0) || (lastThrow.scoreBefore == 50);
    
    if (wasDoubleTarget) {
      players[lastThrow.playerId].checkoutAttempts--;
    }

    currentPlayerIndex = lastThrow.playerId;
    currentTurnIndex = lastThrow.turnIndex; 
    
    players[currentPlayerIndex].currentScore = lastThrow.scoreBefore;
    players[currentPlayerIndex].history.removeLast();
    
    var turnDarts = players[currentPlayerIndex].history.where((t) => t.turnIndex == currentTurnIndex).toList();
    currentDartCount = turnDarts.length;
    
    notifyListeners();
  }

  void _endTurn({bool bust = false}) {
    if (bust) {
      var turnDarts = activePlayer.history.where((t) => t.turnIndex == currentTurnIndex).toList();
      if (turnDarts.isNotEmpty) {
        activePlayer.currentScore = turnDarts.first.scoreBefore;
      }

      for (int i = 0; i < activePlayer.history.length; i++) {
        if (activePlayer.history[i].turnIndex == currentTurnIndex) {
          var old = activePlayer.history[i];
          activePlayer.history[i] = DartThrow(
            value: old.value,
            multiplier: old.multiplier,
            scoreBefore: old.scoreBefore,
            playerId: old.playerId,
            legNumber: old.legNumber,
            turnIndex: old.turnIndex,
            scoreCounted: false,
          );
        }
      }
    }
    
    currentDartCount = 0;
    currentTurnIndex++; 
    currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
  }
}