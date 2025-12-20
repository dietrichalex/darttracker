import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/match_provider.dart';
import '../utils/checkout_logic.dart';
import '../models/player.dart';
import '../models/dart_throw.dart';

class MatchScreen extends StatelessWidget {
  const MatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final match = Provider.of<MatchProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("Match in Progress"),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart, color: Colors.greenAccent),
            onPressed: () => _showLiveStats(context, match),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildScoreboard(match)),
          _buildCheckoutPanel(match),
          const SizedBox(height: 5),
          _buildKeypad(match, context),
        ],
      ),
    );
  }

  Widget _buildScoreboard(MatchProvider match) {
    return ListView.builder(
      itemCount: match.players.length,
      itemBuilder: (context, index) {
        final p = match.players[index];
        bool isActive = match.currentPlayerIndex == index;
        
        // --- LOGIC FIX START ---
        List<DartThrow> displayThrows = [];
        
        if (isActive) {
          // If it's my turn, show what I've thrown so far (0, 1, or 2 darts)
          displayThrows = match.currentTurnDarts;
        } else {
          // If it's NOT my turn, show the last 3 darts I threw
          // This ensures the previous player's score stays visible
          if (p.history.isNotEmpty) {
            int count = p.history.length >= 3 ? 3 : p.history.length;
            displayThrows = p.history.reversed.take(count).toList().reversed.toList();
          }
        }
        // --- LOGIC FIX END ---

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: isActive ? Colors.white.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isActive ? Border.all(color: Colors.greenAccent) : Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // LEFT SIDE: Name & Stats
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: TextStyle(fontSize: 18, color: isActive ? Colors.white : Colors.grey)),
                  const SizedBox(height: 4),
                  Text("Avg: ${p.average.toStringAsFixed(1)}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  Text("Sets: ${p.setsWon} Legs: ${p.legsWon}", style: const TextStyle(color: Colors.amber, fontSize: 12)),
                ],
              ),
              
              // RIGHT SIDE: Score & Throws Display
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("${p.currentScore}", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                  
                  // Display Darts (Visible for both Active and Inactive now)
                  if (displayThrows.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: displayThrows.map((t) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text(
                              _formatDart(t),
                              style: TextStyle(
                                // Dim the text slightly if it's the inactive player
                                color: isActive ? Colors.white : Colors.grey, 
                                fontSize: 16, 
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDart(DartThrow t) {
    if (t.value == 0) return "0";
    String prefix = "";
    if (t.multiplier == 2) prefix = "D";
    if (t.multiplier == 3) prefix = "T";
    if (t.value == 25) return t.multiplier == 2 ? "BULL" : "25";
    return "$prefix${t.value}";
  }

 Widget _buildCheckoutPanel(MatchProvider match) {
    final int score = match.activePlayer.currentScore;
    
    // CALCULATE DARTS REMAINING IN THIS TURN
    int dartsRemaining = 3 - match.currentDartCount;
    
    // Get recommendation based on ACTUAL darts left
    final String route = CheckoutLogic.getRecommendation(score, dartsRemaining);

    if (route.isEmpty) return const SizedBox(height: 50);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.gps_fixed, color: Colors.greenAccent, size: 16),
          const SizedBox(width: 8),
          Text(route, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildKeypad(MatchProvider match, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.black,
      child: Column(
        children: [
          Row(
            children: [
              _btn("D", () => match.setMultiplier(2), color: Colors.orange, active: match.multiplier == 2),
              _btn("T", () => match.setMultiplier(3), color: Colors.redAccent, active: match.multiplier == 3),
              _btn("UNDO", () => match.undo(), color: Colors.blueGrey),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.center,
            children: List.generate(20, (i) => SizedBox(width: MediaQuery.of(context).size.width / 5 - 8, child: _btn("${i + 1}", () => match.handleInput(i + 1, context)))),
          ),
          Row(
            children: [
              _btn("0", () => match.handleInput(0, context), color: Colors.grey),
              _btn("25", () => match.handleInput(25, context), color: Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _btn(String txt, VoidCallback tap, {Color? color, bool active = false}) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: active ? Colors.white : (color ?? Colors.grey[900]),
          foregroundColor: active ? Colors.black : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
        ),
        onPressed: tap,
        child: Text(txt, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showLiveStats(BuildContext context, MatchProvider match) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (c) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            const Text("Live Match Statistics", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const Divider(color: Colors.white24),
            
            ...match.players.map((Player p) => Card(
              color: Colors.white.withOpacity(0.05),
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(p.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                        Text("Avg: ${p.average.toStringAsFixed(1)}", style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _miniStat("100+", p.countScore(100, 140)),
                        _miniStat("140+", p.countScore(140, 180)),
                        _miniStat("180s", p.countScore(180)),
                        _miniStat("CO %", "${p.checkoutPercentage.toStringAsFixed(0)}%"),
                      ],
                    ),
                  ],
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
  
  Widget _miniStat(String label, dynamic val) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text("$val", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }
}