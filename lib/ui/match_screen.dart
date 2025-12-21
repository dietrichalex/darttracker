import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/match_provider.dart';
import '../utils/checkout_logic.dart';
import '../models/player.dart';
import '../models/dart_throw.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  final ScrollController _scrollController = ScrollController();
  int _prevPlayerIndex = -1;
  
  // CONSTANT: Fixed height for each player card
  final double _cardHeight = 130.0; 

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final match = Provider.of<MatchProvider>(context);
    
    if (match.currentPlayerIndex != _prevPlayerIndex) {
      _prevPlayerIndex = match.currentPlayerIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            match.currentPlayerIndex * _cardHeight, 
            duration: const Duration(milliseconds: 300), 
            curve: Curves.easeOut
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
      controller: _scrollController,
      itemExtent: _cardHeight, 
      itemCount: match.players.length,
      itemBuilder: (context, index) {
        final p = match.players[index];
        bool isActive = match.currentPlayerIndex == index;
        
        List<DartThrow> displayThrows = [];
        if (isActive) {
          displayThrows = match.currentTurnDarts;
        } else {
          if (p.history.isNotEmpty) {
            int count = p.history.length >= 3 ? 3 : p.history.length;
            displayThrows = p.history.reversed.take(count).toList().reversed.toList();
          }
        }

        return Container(
          height: _cardHeight,
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? Colors.white.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isActive ? Border.all(color: Colors.greenAccent) : Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // LEFT SIDE: Name & Stats
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(p.name, 
                      style: TextStyle(fontSize: 18, color: isActive ? Colors.white : Colors.grey, overflow: TextOverflow.ellipsis),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    Text("Avg: ${p.average.toStringAsFixed(1)}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    Text("Sets: ${p.setsWon} Legs: ${p.legsWon}", style: const TextStyle(color: Colors.amber, fontSize: 12)),
                  ],
                ),
              ),

              // RIGHT SIDE: Score & Throws
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Score
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text("${p.currentScore}", 
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.greenAccent)
                      ),
                    ),
                    
                    // Darts Display (Wrapped & Fitted)
                    if (displayThrows.isNotEmpty)
                      Flexible( // Allows vertical shrinking if needed
                        child: FittedBox( // Scales text down if it's too wide/tall
                          fit: BoxFit.scaleDown,
                          child: Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            constraints: const BoxConstraints(maxWidth: 160), // Force wrap earlier
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 8,
                              runSpacing: 2,
                              children: displayThrows.map((t) {
                                return Text(
                                  _formatDart(t),
                                  style: TextStyle(
                                    color: isActive ? Colors.white : Colors.grey, 
                                    fontSize: 14, 
                                    fontWeight: FontWeight.bold
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
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
    int dartsRemaining = 3 - match.currentDartCount;
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
          Flexible(
            child: Text(route, 
              style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeypad(MatchProvider match, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      color: Colors.black,
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 2,
            runSpacing: 2,
            children: List.generate(20, (i) {
               double w = (MediaQuery.of(context).size.width - 20) / 5; 
               return SizedBox(
                 width: w, 
                 height: 50,
                 child: _btn("${i + 1}", () => match.handleInput(i + 1, context))
               );
            }),
          ),
          
          const SizedBox(height: 5),

          Row(
            children: [
              Expanded(child: _btn("D", () => match.setMultiplier(2), color: Colors.orange, active: match.multiplier == 2)),
              const SizedBox(width: 2),
              Expanded(child: _btn("T", () => match.setMultiplier(3), color: Colors.redAccent, active: match.multiplier == 3)),
              const SizedBox(width: 2),
              Expanded(child: _btn("0", () => match.handleInput(0, context), color: Colors.grey[800])),
              const SizedBox(width: 2),
              Expanded(child: _btn("25", () => match.handleInput(25, context), color: Colors.green)),
              const SizedBox(width: 2),
              Expanded(child: _btn("UNDO", () => match.undo(), color: Colors.blueGrey)),
            ],
          ),
          const SizedBox(height: 5),
        ],
      ),
    );
  }

  Widget _btn(String txt, VoidCallback tap, {Color? color, bool active = false}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: active ? Colors.white : (color ?? Colors.grey[900]),
        foregroundColor: active ? Colors.black : Colors.white,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      onPressed: tap,
      child: Text(txt, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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