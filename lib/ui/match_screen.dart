import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/match_provider.dart';
import '../utils/checkout_logic.dart';
import '../models/player.dart';

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
          const SizedBox(height: 10),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: TextStyle(fontSize: 18, color: isActive ? Colors.white : Colors.grey)),
                  // LIVE AVERAGE DISPLAY
                  Text("Avg: ${p.average.toStringAsFixed(1)}", 
                      style: TextStyle(color: isActive ? Colors.amber : Colors.white24, fontSize: 14)),
                  Text("Sets: ${p.setsWon} Legs: ${p.legsWon}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              Text("${p.currentScore}", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
            ],
          ),
        );
      },
    );
  }

 Widget _buildCheckoutPanel(MatchProvider match) {
  final int score = match.activePlayer.currentScore;
  final String route = CheckoutLogic.getRoute(score);
  
  if (route == "No Checkout" || score > 170) {
    return const SizedBox(height: 50); 
  }

  return TweenAnimationBuilder(
    duration: const Duration(milliseconds: 300),
    tween: Tween<double>(begin: 0, end: 1),
    builder: (context, double opacity, child) => Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.greenAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
        ),
        child: Text("Finish: $route", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
      ),
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
              _btn(
                "D", 
                () => match.setMultiplier(2), 
                color: Colors.orange, 
                active: match.multiplier == 2 // Highlights when active
              ),
              _btn(
                "T", 
                () => match.setMultiplier(3), 
                color: Colors.redAccent, 
                active: match.multiplier == 3 // Highlights when active
              ),
              _btn("UNDO", () => match.undo(), color: Colors.blueGrey),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.center,
            children: List.generate(20, (i) => SizedBox(
              width: MediaQuery.of(context).size.width / 5 - 8,
              child: _btn("${i + 1}", () => match.handleInput(i + 1, context)),
            )),
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
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (c) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          const Text("Live Match Statistics", 
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const Divider(color: Colors.white24),
          
          // Use .map().toList() explicitly to avoid type errors
          ...match.players.map((Player p) => _buildPlayerStatCard(p)).toList(),
          
          const SizedBox(height: 20),
          const Text("Turn History", style: TextStyle(color: Colors.grey)),
          const Divider(color: Colors.white10),
          
          // Show last 10 throws from global history
          ...match.globalHistory.reversed.take(10).map((t) => ListTile(
            dense: true,
            title: Text("Scored ${t.total}", style: const TextStyle(color: Colors.white70)),
            subtitle: Text("By ${match.players[t.playerId].name}"),
            trailing: Text("Left: ${t.scoreBefore - t.total}"),
          )).toList(),
        ],
      ),
    ),
  );
}

Widget _buildPlayerStatCard(Player p) {
  return Card(
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
              _miniStat("Out %", "${p.checkoutPercentage.toStringAsFixed(0)}%"),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _miniStat(String label, dynamic val) {
  return Column(
    children: [
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      Text("$val", style: const TextStyle(fontWeight: FontWeight.bold)),
    ],
  );
}
}