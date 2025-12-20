import 'package:flutter/material.dart';
import '../models/player.dart';
import 'setup_screen.dart';

class SummaryScreen extends StatelessWidget {
  final List<Player> players;
  final List<String> legLog;

  const SummaryScreen({super.key, required this.players, this.legLog = const []});

  @override
  Widget build(BuildContext context) {
    final winner = players.reduce((a, b) => a.setsWon > b.setsWon ? a : b);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(title: const Text("Match Report"), backgroundColor: Colors.transparent),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.emoji_events, size: 80, color: Colors.amber),
            Text("WINNER: ${winner.name}", style: const TextStyle(fontSize: 28, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            // FULL STATS TABLE
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                headingRowColor: MaterialStateProperty.all(Colors.white10),
                columns: [
                  const DataColumn(label: Text("Stat", style: TextStyle(fontWeight: FontWeight.bold))),
                  ...players.map((p) => DataColumn(label: Text(p.name, style: const TextStyle(color: Colors.amber)))),
                ],
                rows: [
                  _buildRow("3-Dart Avg", players.map((p) => p.average.toStringAsFixed(1)).toList()),
                  _buildRow("First 9 Avg", players.map((p) => p.firstNineAverage.toStringAsFixed(1)).toList()),
                  _buildRow("Checkout %", players.map((p) => "${p.checkoutPercentage.toStringAsFixed(1)}%").toList()),
                  _buildRow("Best Leg", players.map((p) => "${p.bestLeg} darts").toList()),
                  _buildRow("Total Legs", players.map((p) => "${p.totalLegsWon}").toList()),
                  _buildRow("100+", players.map((p) => "${p.countScore(100, 140)}").toList()),
                  _buildRow("140+", players.map((p) => "${p.countScore(140, 180)}").toList()),
                  _buildRow("180s", players.map((p) => "${p.countScore(180)}").toList()),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            const Text("Per-Leg Analysis", style: TextStyle(fontSize: 18, color: Colors.greenAccent)),
            
            // PER LEG LIST
            if (players.isNotEmpty && players[0].legStats.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: players[0].legStats.length,
                itemBuilder: (context, i) {
                  return Card(
                    color: Colors.white10,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ExpansionTile(
                      leading: Text("Leg ${i+1}", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                      title: Text(i < legLog.length ? legLog[i].replaceAll("Leg ${i+1}: ", "") : ""),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: players.map((p) {
                              if (i >= p.legStats.length) return const SizedBox();
                              final stats = p.legStats[i];
                              return Column(
                                children: [
                                  Text(p.name, style: const TextStyle(color: Colors.amber)),
                                  Text("Avg: ${stats.average.toStringAsFixed(1)}", style: const TextStyle(color: Colors.white)),
                                  Text("1st 9: ${stats.firstNineAvg.toStringAsFixed(1)}", style: const TextStyle(color: Colors.grey)),
                                  if (stats.won) const Text("WINNER", style: TextStyle(color: Colors.greenAccent, fontSize: 10)),
                                ],
                              );
                            }).toList(),
                          ),
                        )
                      ],
                    ),
                  );
                },
              ),

            Padding(
              padding: const EdgeInsets.all(30.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 50)),
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (c) => const SetupScreen()), (route) => false),
                child: const Text("NEW MATCH"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DataRow _buildRow(String label, List<String> values) {
    return DataRow(cells: [
      DataCell(Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
      ...values.map((v) => DataCell(Text(v, style: const TextStyle(color: Colors.white70)))),
    ]);
  }
}