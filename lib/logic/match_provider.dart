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
  int currentSetIndex = 0;
  int currentLegInSet = 1;
  int currentTurnIndex = 1;

  List<int> legPlacements = []; 
  Player? matchWinner; 
  
  // Pauses game when someone finishes (only for 3+ players)
  bool waitingForContinuation = false; 

  void setupMatch(MatchConfig newConfig) async {
    config = newConfig;
    players = config.playerNames.map((name) => Player(name)..currentScore = config.startingScore).toList();
    globalHistory = [];
    matchLog = [];
    legPlacements = [];
    matchWinner = null;
    waitingForContinuation = false;
    
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
  
  int get currentTurnScore {
    return currentTurnDarts.fold(0, (sum, t) => sum + t.total);
  }

  void setMultiplier(int m) {
    multiplier = (multiplier == m) ? 1 : m;
    notifyListeners();
  }

  // --- MANUAL INPUT HANDLING ---
  void handleManualInput(int totalScore, BuildContext context) {
    if (totalScore > 180) return;

    int scoreRemaining = activePlayer.currentScore - totalScore;
    
    bool isBust = (scoreRemaining <= 1 && scoreRemaining != 0); 

    List<int> values = [totalScore, 0, 0];
    
    for (int i = 0; i < 3; i++) {
      final t = DartThrow(
        value: values[i], 
        multiplier: 1, 
        scoreBefore: activePlayer.currentScore, 
        playerId: currentPlayerIndex,
        legNumber: currentLegNumber,
        turnIndex: currentTurnIndex,
        // If it's a bust, points don't count for the average numerator
        scoreCounted: !isBust, 
        isManual: true 
      );
      
      activePlayer.history.add(t);
      globalHistory.add(t);
      
      // Only subtract score on the first virtual dart, IF it wasn't a bust
      if (i == 0 && !isBust) {
         activePlayer.currentScore -= totalScore;
      }
    }

    if (!isBust && scoreRemaining == 0) {
      // CHECKOUT
      activePlayer.checkoutAttempts++;
      _handleCheckout(activePlayer, context);
    } else if (isBust) { 
      // BUST - End turn immediately
      _endTurn(bust: true);
    } else {
      // NORMAL
      _endTurn();
    }
    notifyListeners();
  }

  void handleInput(int val, BuildContext context) async {
    if (val == 25 && multiplier == 3) return;

    Player p = activePlayer;
    int scoreThisDart = val * multiplier;
    int scoreBefore = p.currentScore;
    int scoreRemaining = scoreBefore - scoreThisDart;

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
      scoreCounted: true,
      isManual: false 
    );

    if (scoreRemaining == 0 && multiplier == 2) {
      p.history.add(t);
      globalHistory.add(t);
      _handleCheckout(p, context);
    } 
    else if (scoreRemaining <= 1) {
      p.history.add(t);     
      globalHistory.add(t); 
      _endTurn(bust: true); 
    } 
    else {
      p.history.add(t);
      globalHistory.add(t);
      p.currentScore -= scoreThisDart;
      currentDartCount++;
      if (currentDartCount == 3) _endTurn();
    }
    multiplier = 1;
    notifyListeners();
  }

  void _handleCheckout(Player p, BuildContext context) {
    if (!legPlacements.contains(currentPlayerIndex)) {
      legPlacements.add(currentPlayerIndex);
    }
    
    if (legPlacements.length == 1 && players.length > 2) {
      waitingForContinuation = true;
      notifyListeners();
      return; 
    }

    // Standard flow (2 players OR subsequent players in MP)
    int playersRemaining = players.length - legPlacements.length;
    
    if (playersRemaining <= 1 || players.length == 1) {
      _finalizeLeg(context);
    } else {
      currentDartCount = 0;
      currentTurnIndex++;
      _advanceToNextActivePlayer();
      notifyListeners();
    }
  }

  // CALLED BY UI: "End Leg/Match"
  void stopLegNow(BuildContext context) {
    waitingForContinuation = false;
    _finalizeLeg(context);
  }

  // CALLED BY UI: "Continue" (Let others play)
  void continueLeg(BuildContext context) {
    waitingForContinuation = false;
    int playersRemaining = players.length - legPlacements.length;
    
    if (playersRemaining <= 1 || players.length == 1) {
      _finalizeLeg(context);
    } else {
      currentDartCount = 0;
      currentTurnIndex++;
      _advanceToNextActivePlayer();
      notifyListeners();
    }
  }

  void _advanceToNextActivePlayer() {
    int attempts = 0;
    do {
      currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
      attempts++;
    } while (legPlacements.contains(currentPlayerIndex) && attempts < players.length);
  }

  Future<void> _finalizeLeg(BuildContext context) async {
    Player winner = players[legPlacements.first];
    winner.legsWon++;
    winner.totalLegsWon++;
    matchLog.add("Leg $currentLegNumber: Won by ${winner.name}");

    for (var p in players) {
      bool isWin = (p == winner);
      p.snapshotLegStats(currentLegNumber, isWin, config.startingScore);
    }
    
    currentLegNumber++;
    currentLegInSet++;
    legPlacements.clear();

    if (winner.legsWon >= config.legsNeededToWin) {
      winner.setsWon++;
      for (var pl in players) pl.legsWon = 0; 
      currentSetIndex++;
      currentLegInSet = 1; 
    }

    if (winner.setsWon >= config.setsNeededToWin) {
      matchWinner = winner; 
      notifyListeners();
    } else {
      for (var pl in players) pl.currentScore = config.startingScore;
      currentDartCount = 0;
      currentTurnIndex++;
      int setStarterIndex = currentSetIndex % players.length;
      int legStarterIndex = (setStarterIndex + (currentLegInSet - 1)) % players.length;
      currentPlayerIndex = legStarterIndex;
      notifyListeners();
    }
  }

  Future<void> confirmMatchEnd(BuildContext context) async {
    if (matchWinner == null) return;
    await _saveAndExit(matchWinner!, context);
  }

  void undoWin() {
    matchWinner = null;
    undo(); 
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

    double winnerTotalPoints = 0;
    int winnerTotalDarts = 0;
    for (var t in winner.history) {
      if (t.scoreCounted) winnerTotalPoints += t.total;
      winnerTotalDarts++; 
    }
    double strictMatchAvg = (winnerTotalDarts == 0) ? 0.0 : winnerTotalPoints / (winnerTotalDarts / 3);

    await DBHelper.saveMatch({
      'winner': winner.name,
      'avg': strictMatchAvg.toStringAsFixed(1),
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
    // Reset flags
    waitingForContinuation = false;
    matchWinner = null;

    if (globalHistory.isEmpty) return;
    if (globalHistory.last.legNumber != currentLegNumber) return;

    final lastThrow = globalHistory.removeLast();
    
    if (legPlacements.contains(lastThrow.playerId)) {
      legPlacements.remove(lastThrow.playerId);
    }

    bool wasDoubleTarget = (lastThrow.scoreBefore <= 40 && lastThrow.scoreBefore % 2 == 0) || (lastThrow.scoreBefore == 50);
    if (wasDoubleTarget) {
      players[lastThrow.playerId].checkoutAttempts--;
    }

    currentPlayerIndex = lastThrow.playerId;
    currentTurnIndex = lastThrow.turnIndex; 
    
    players[currentPlayerIndex].currentScore = lastThrow.scoreBefore;
    players[currentPlayerIndex].history.removeLast();
    
    // Undo Manual Input (3 items)
    if (players[currentPlayerIndex].history.isNotEmpty) {
      var prev = players[currentPlayerIndex].history.last;
      if (lastThrow.isManual && prev.turnIndex == currentTurnIndex && prev.value == 0) {
        players[currentPlayerIndex].history.removeLast(); 
        globalHistory.removeLast();
        if (players[currentPlayerIndex].history.isNotEmpty) {
           players[currentPlayerIndex].history.removeLast(); 
           globalHistory.removeLast();
        }
      }
    }

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
            isManual: old.isManual 
          );
        }
      }
    }
    currentDartCount = 0;
    currentTurnIndex++; 
    _advanceToNextActivePlayer();
  }
}