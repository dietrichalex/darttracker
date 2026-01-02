import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/dart_throw.dart';
import '../models/match_config.dart';
import '../ui/summary_screen.dart';
import '../utils/checkout_logic.dart';
import 'db_helper.dart';

class MatchProvider with ChangeNotifier {
  late MatchConfig config;
  List<Player> players = [];
  List<DartThrow> globalHistory = []; 
  List<String> matchLog = [];
  
  int currentPlayerIndex = 0;
  int currentDartCount = 0;
  int multiplier = 1;
  
  // Logic tracking
  int currentLegNumber = 1; // Global leg counter
  int currentSetIndex = 0;  // 0-based set counter
  int currentLegInSet = 1;  // 1-based leg counter for the current set
  int currentTurnIndex = 1;

  void setupMatch(MatchConfig newConfig) async {
    config = newConfig;
    players = config.playerNames.map((name) => Player(name)..currentScore = config.startingScore).toList();
    globalHistory = [];
    matchLog = [];
    currentPlayerIndex = 0;
    currentDartCount = 0;
    
    currentLegNumber = 1;
    currentSetIndex = 0;
    currentLegInSet = 1;
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
    // BUG FIX: Block Triple Bull (3 * 25 = 75 is invalid)
    if (val == 25 && multiplier == 3) {
      return; // Ignore invalid input
    }

    Player p = activePlayer;
    int scoreThisDart = val * multiplier;
    int scoreBefore = p.currentScore;
    int scoreRemaining = scoreBefore - scoreThisDart;

    // Checkout Stats Logic
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
    currentLegInSet++;

    if (winner.legsWon >= config.legsNeededToWin) {
      winner.setsWon++;
      // Reset for next set
      for (var pl in players) pl.legsWon = 0; 
      currentSetIndex++;
      currentLegInSet = 1; // Reset leg count for new set
    }

    if (winner.setsWon >= config.setsNeededToWin) {
      await _saveAndExit(winner, context);
    } else {
      // Reset Board
      for (var pl in players) pl.currentScore = config.startingScore;
      currentDartCount = 0;
      currentTurnIndex++;

      // BUG FIX: Set Rotation Logic
      // 1. Who starts this Set? (Rotates: Set 1->P1, Set 2->P2...)
      int setStarterIndex = currentSetIndex % players.length;
      
      // 2. Who starts this Leg within the Set? (Rotates based on set starter)
      // Leg 1: SetStarter, Leg 2: SetStarter + 1...
      int legStarterIndex = (setStarterIndex + (currentLegInSet - 1)) % players.length;

      currentPlayerIndex = legStarterIndex;
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

    // BUG FIX: Accurate Match Average Calculation
    // We sum ALL points and ALL darts from the history to get the pure mathematical average
    // This avoids discrepancies between "Current State Avg" and "Match History Avg"
    double winnerTotalPoints = 0;
    int winnerTotalDarts = 0;
    
    for (var t in winner.history) {
      if (t.scoreCounted) {
        winnerTotalPoints += t.total;
      }
      // Darts count even if score wasn't counted (busts)
      winnerTotalDarts++; 
    }
    
    double strictMatchAvg = (winnerTotalDarts == 0) 
        ? 0.0 
        : winnerTotalPoints / (winnerTotalDarts / 3);

    await DBHelper.saveMatch({
      'winner': winner.name,
      'avg': strictMatchAvg.toStringAsFixed(1), // Use the strict calc
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