import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final TextEditingController _manualInputController = TextEditingController();
  int _prevPlayerIndex = -1;
  final double _cardHeight = 140.0; 
  
  bool _isManualInput = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final match = Provider.of<MatchProvider>(context);
    
    // Auto-scroll
    if (match.currentPlayerIndex != _prevPlayerIndex) {
      _prevPlayerIndex = match.currentPlayerIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0) {
           _scrollController.animateTo(
             match.currentPlayerIndex * _cardHeight, 
             duration: const Duration(milliseconds: 300), 
             curve: Curves.easeOut
           );
        }
      });
    }

    if (match.waitingForContinuation) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showContinuationDialog(context, match));
    }
    else if (match.matchWinner != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showWinDialog(context, match));
    }
  }

  void _showContinuationDialog(BuildContext context, MatchProvider match) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text("${match.activePlayer.name} Finished!", style: const TextStyle(color: Colors.greenAccent)),
        content: const Text("What would you like to do?", style: TextStyle(color: Colors.white)),
        actions: [
          // 1. UNDO
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              match.undo(); 
            },
            child: const Text("Undo", style: TextStyle(color: Colors.orange)),
          ),
          // 2. CONTINUE (Only if >1 player)
          if (match.players.length > 1)
            TextButton(
              onPressed: () {
                Navigator.pop(c);
                match.continueLeg(context);
              },
              child: const Text("Continue Playing", style: TextStyle(color: Colors.blueAccent)),
            ),
          // 3. END LEG/MATCH
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
            onPressed: () {
              Navigator.pop(c);
              match.stopLegNow(context); 
            },
            child: const Text("End Leg"),
          ),
        ],
      ),
    );
  }

  // Final Match Save Dialog
  void _showWinDialog(BuildContext context, MatchProvider match) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text("${match.matchWinner!.name} Wins Match!", style: const TextStyle(color: Colors.greenAccent)),
        content: const Text("The match is finished. Save results?", style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              match.undoWin(); 
            },
            child: const Text("Undo Last Throw", style: TextStyle(color: Colors.orange)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
            onPressed: () {
              Navigator.pop(c);
              match.confirmMatchEnd(context); 
            },
            child: const Text("Finish & Save"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _manualInputController.dispose();
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
          
          _isManualInput 
              ? _buildManualInputPanel(match)
              : _buildKeypad(match, context),
          
          const SizedBox(height: 15), // Spacer (Reduced)
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
            int lastTurnIdx = p.history.last.turnIndex;
            displayThrows = p.history.where((t) => t.turnIndex == lastTurnIdx).toList();
          }
        }
        
        int turnSum = displayThrows.fold(0, (sum, t) => sum + t.total);
        bool isFinished = match.legPlacements.contains(index);

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
                    if (isFinished)
                      const Text("FINISHED", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))
                    else
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
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text("AVG", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                            Text(p.average.toStringAsFixed(1), 
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isActive ? Colors.white : Colors.white30)
                            ),
                          ],
                        ),
                        const SizedBox(width: 20),
                        Text("${p.currentScore}", 
                          style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold, color: Colors.greenAccent, height: 1.0)
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (displayThrows.isNotEmpty)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (turnSum > 0 && !displayThrows.first.isManual)
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Text("$turnSum", style: const TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                          
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(6)),
                            child: _buildDartsOrManual(displayThrows, isActive),
                          ),
                        ],
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

  Widget _buildDartsOrManual(List<DartThrow> throws, bool isActive) {
    if (throws.any((t) => t.isManual)) {
       int val = throws.first.value; 
       Color c = isActive ? Colors.white : Colors.grey;
       if (!throws.first.scoreCounted) c = Colors.redAccent;
       return Text("$val (Manual)", style: TextStyle(color: c, fontSize: 20, fontWeight: FontWeight.bold));
    }

    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      children: throws.map((t) {
        Color c = Colors.white;
        if (!isActive) c = c.withOpacity(0.7);
        int rem = t.scoreBefore - t.total;
        bool isWin = (rem == 0 && t.multiplier == 2);
        bool isBust = (rem <= 1 && !isWin);
        if (isBust) c = Colors.redAccent;
        else if (t.multiplier == 2) c = Colors.yellowAccent;
        else if (t.multiplier == 3) c = Colors.amber;
        return Text(_formatDart(t), style: TextStyle(color: c, fontSize: 20, fontWeight: FontWeight.bold));
      }).toList(),
    );
  }

  Widget _infoBadge(String label, String val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white24)),
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
            child: Text(route.isEmpty ? "No Checkout" : route, 
              style: TextStyle(color: route.isEmpty ? Colors.grey : Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16), 
              overflow: TextOverflow.ellipsis
            ),
          ),
          const SizedBox(width: 15),
          InkWell(
            onTap: () {
               setState(() {
                 _isManualInput = !_isManualInput;
                 _manualInputController.clear();
               });
            },
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(5)),
              child: Icon(_isManualInput ? Icons.grid_view : Icons.keyboard, color: Colors.white, size: 20),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildManualInputPanel(MatchProvider match) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.black,
      height: 250, 
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Enter Total Turn Score", style: TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualInputController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: "0",
                    hintStyle: TextStyle(color: Colors.grey),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.greenAccent)),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 60,
                width: 80,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                  onPressed: () {
                    if (_manualInputController.text.isNotEmpty) {
                      int score = int.tryParse(_manualInputController.text) ?? 0;
                      match.handleManualInput(score, context);
                      _manualInputController.clear();
                    }
                  },
                  child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                ),
              )
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
             width: double.infinity,
             child: ElevatedButton.icon(
               style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
               onPressed: () => match.undo(),
               icon: const Icon(Icons.undo),
               label: const Text("Undo Last"),
             ),
          )
        ],
      ),
    );
  }

  Widget _buildKeypad(MatchProvider match, BuildContext context) {
    const double numberBtnHeight = 65.0; 
    const double actionBtnHeight = 60.0;
    bool isTripleActive = (match.multiplier == 3);

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
               return SizedBox(width: w, height: numberBtnHeight, child: _btn("${i + 1}", () => match.handleInput(i + 1, context)));
            }),
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: actionBtnHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _btn("0", () => match.handleInput(0, context), color: Colors.grey[800])),
                const SizedBox(width: 2),
                Expanded(
                  child: IgnorePointer(
                    ignoring: isTripleActive, 
                    child: _btn("25", () => match.handleInput(25, context), 
                      color: isTripleActive ? Colors.grey[900] : Colors.green, 
                      textColor: isTripleActive ? Colors.grey[700] : Colors.white
                    ),
                  )
                ),
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

  Widget _btn(String txt, VoidCallback tap, {Color? color, Color? textColor, bool active = false}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: active ? Colors.white : (color ?? Colors.grey[900]),
        foregroundColor: active ? Colors.black : (textColor ?? Colors.white),
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
                        Text("Match Avg: ${p.average.toStringAsFixed(1)}", style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Text("Leg Avg: ${p.currentLegAverage(match.currentLegNumber).toStringAsFixed(1)}", style: const TextStyle(color: Colors.amber)),
                         Text("Last: ${p.getLastScores(5).join(', ')}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                       ],
                    ),
                    const Divider(color: Colors.white10),
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