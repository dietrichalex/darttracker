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
  final double _cardHeight = 140.0; 

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final match = Provider.of<MatchProvider>(context);
    
    // Auto-scroll logic
    if (match.currentPlayerIndex != _prevPlayerIndex) {
      _prevPlayerIndex = match.currentPlayerIndex;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          // FIX: Only animate if the list is actually scrollable (maxScrollExtent > 0).
          // This prevents the "jittery" animation when you only have 2 players that fit perfectly.
          if (_scrollController.position.maxScrollExtent > 0) {
            _scrollController.animateTo(
              match.currentPlayerIndex * _cardHeight, 
              duration: const Duration(milliseconds: 300), 
              curve: Curves.easeOut
            );
          }
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
          // 1. Scoreboard takes all remaining space
          Expanded(child: _buildScoreboard(match)),
          
          // 2. Checkout Panel
          _buildCheckoutPanel(match),
          const SizedBox(height: 5),
          
          // 3. Keypad
          _buildKeypad(match, context),
          
          // 4. Empty space to push the keypad UP
          const SizedBox(height: 20), 
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
        
        // --- DISPLAY LOGIC ---
        List<DartThrow> displayThrows = [];
        
        if (isActive) {
          displayThrows = match.currentTurnDarts;
        } else {
          // If inactive, show darts from their LAST turn index
          if (p.history.isNotEmpty) {
            int lastTurnIdx = p.history.last.turnIndex;
            displayThrows = p.history.where((t) => t.turnIndex == lastTurnIdx).toList();
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
              // LEFT SIDE: Name & Sets
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(p.name, 
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isActive ? Colors.white : Colors.grey, overflow: TextOverflow.ellipsis),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _infoBadge("SETS", "${p.setsWon}"),
                        const SizedBox(width: 8),
                        _infoBadge("LEGS", "${p.legsWon}"),
                      ],
                    )
                  ],
                ),
              ),

              // RIGHT SIDE: Scores
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // TOP ROW: Average + Score
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // AVERAGE (Bigger)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text("AVG", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                            Text(p.average.toStringAsFixed(1), 
                              style: TextStyle(
                                fontSize: 24, 
                                fontWeight: FontWeight.bold, 
                                color: isActive ? Colors.white : Colors.white30
                              )
                            ),
                          ],
                        ),
                        const SizedBox(width: 20),
                        
                        // SCORE
                        Text("${p.currentScore}", 
                          style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold, color: Colors.greenAccent, height: 1.0)
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 6),
                    
                    // DARTS ROW
                    if (displayThrows.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 12,
                          children: displayThrows.map((t) {
                            // Color Logic
                            Color c = Colors.white;
                            if (!isActive) c = c.withOpacity(0.7);

                            int rem = t.scoreBefore - t.total;
                            bool isWin = (rem == 0 && t.multiplier == 2);
                            bool isBust = (rem <= 1 && !isWin);

                            if (isBust) {
                              c = Colors.redAccent;
                            } else {
                              if (t.multiplier == 2) c = Colors.yellowAccent;
                              if (t.multiplier == 3) c = Colors.amber;
                            }

                            return Text(
                              _formatDart(t),
                              style: TextStyle(color: c, fontSize: 20, fontWeight: FontWeight.bold),
                            );
                          }).toList(),
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

  Widget _infoBadge(String label, String val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white24)
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(width: 4),
          Text(val, style: const TextStyle(fontSize: 14, color: Colors.amber, fontWeight: FontWeight.bold)),
        ],
      ),
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
    // UPDATED: Taller buttons to fill the screen
    const double numberBtnHeight = 60.0; 
    const double actionBtnHeight = 60.0;

    return Container(
      padding: const EdgeInsets.all(5),
      color: Colors.black,
      child: Column(
        children: [
          // 1-20 GRID
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 2,
            runSpacing: 2,
            children: List.generate(20, (i) {
               double w = (MediaQuery.of(context).size.width - 20) / 5; 
               return SizedBox(
                 width: w, 
                 height: numberBtnHeight, // Taller (65)
                 child: _btn("${i + 1}", () => match.handleInput(i + 1, context))
               );
            }),
          ),
          
          const SizedBox(height: 5),

          // BOTTOM ROW
          SizedBox(
            height: actionBtnHeight, // Taller (60)
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch, // Fill height
              children: [
                Expanded(child: _btn("0", () => match.handleInput(0, context), color: Colors.grey[800])),
                const SizedBox(width: 2),
                Expanded(child: _btn("25", () => match.handleInput(25, context), color: Colors.green)),
                const SizedBox(width: 2),
                Expanded(child: _btn("D", () => match.setMultiplier(2), color: Colors.orange, active: match.multiplier == 2)),
                const SizedBox(width: 2),
                Expanded(child: _btn("T", () => match.setMultiplier(3), color: Colors.redAccent, active: match.multiplier == 3)),
                const SizedBox(width: 2),
                Expanded(child: _btn("UNDO", () => match.undo(), color: Colors.blueGrey)),
              ],
            ),
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