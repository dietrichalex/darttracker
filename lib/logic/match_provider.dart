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

  List<DartThrow> get currentTurnDarts {
    // Only show darts from the CURRENT LEG and CURRENT PLAYER
    if (activePlayer.history.isEmpty || currentDartCount == 0) return [];
    
    // We take the last 'currentDartCount' throws
    // But we doubly ensure they belong to the current leg
    var recent = activePlayer.history.reversed.take(currentDartCount).toList();
    if (recent.any((t) => t.legNumber != currentLegNumber)) {
      return []; // Should not happen with correct logic, but safe fallback
    }
    return recent.reversed.toList();
  }

  void setMultiplier(int m) {
    multiplier = (multiplier == m) ? 1 : m;
    notifyListeners();
  }

  void handleInput(int val, BuildContext context) async {
    Player p = activePlayer;
    int scoreThisDart = val * multiplier;
    int scoreBefore = p.currentScore;

    // Checkout Stats Logic
    bool isFinishable = CheckoutLogic.getRoute(scoreBefore) != "No Checkout";
    if (val == 0 && isFinishable) p.checkoutAttempts++;
    if (multiplier == 2 && (scoreBefore - scoreThisDart == 0)) p.checkoutAttempts++;

    // Create Throw Object with Leg Number
    final t = DartThrow(
      value: val, 
      multiplier: multiplier, 
      scoreBefore: scoreBefore, 
      playerId: currentPlayerIndex,
      legNumber: currentLegNumber // Save Leg ID
    );

    if (scoreBefore - scoreThisDart == 0 && multiplier == 2) {
      // WIN
      p.history.add(t);
      globalHistory.add(t);
      await _finalizeLeg(p, context);
    } 
    else if (scoreBefore - scoreThisDart <= 1) {
      // BUST
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

    if (winner.setsWon >= config.setsToWin) {
      await _saveAndExit(winner, context);
    } else {
      for (var pl in players) pl.currentScore = config.startingScore;
      currentDartCount = 0;
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

    // SAFETY CHECK: Do not allow undoing if it belongs to a previous leg.
    // This prevents breaking the game state (score resets, leg counts, etc.)
    if (globalHistory.last.legNumber != currentLegNumber) {
      debugPrint("Cannot undo past a leg finish.");
      return; 
    }

    final lastThrow = globalHistory.removeLast();
    
    // Revert Checkout Stats
    if (lastThrow.value == 0 && lastThrow.scoreBefore <= 170) {
      players[lastThrow.playerId].checkoutAttempts--;
    }

    currentPlayerIndex = lastThrow.playerId;
    players[currentPlayerIndex].currentScore = lastThrow.scoreBefore;
    players[currentPlayerIndex].history.removeLast();
    
    // Recalculate Dart Count for UI
    // We count how many darts the current player has thrown IN THIS LEG
    int count = 0;
    for (int i = globalHistory.length - 1; i >= 0; i--) {
      // Stop if we hit a different player OR a different leg
      if (globalHistory[i].playerId == currentPlayerIndex && 
          globalHistory[i].legNumber == currentLegNumber) {
        count++;
        if (count == 3) break;
      } else { 
        break; 
      }
    }
    
    // Logic: If we found 2 previous darts in this turn, count is 2.
    // However, if we just undid the 1st dart of a turn, count is 0.
    // But what if we undid the 1st dart of a turn, and the PREVIOUS turn was also this player? 
    // (e.g. bust logic or end of set).
    // The "break" above handles player switch.
    currentDartCount = count % 3;
    
    notifyListeners();
  }

  void _endTurn({bool bust = false}) {
    if (bust) {
      // Revert score to start of turn state
      int dartsInThisVisit = currentDartCount + 1;
      if (activePlayer.history.length >= dartsInThisVisit) {
         var firstDart = activePlayer.history[activePlayer.history.length - dartsInThisVisit];
         activePlayer.currentScore = firstDart.scoreBefore;
      }
    }
    currentDartCount = 0;
    currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
  }
}