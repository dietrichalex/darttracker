import 'package:flutter/material.dart';
import '../models/player.dart';
import 'setup_screen.dart';

class SummaryScreen extends StatelessWidget {
  final List<Player> players;
  const SummaryScreen({super.key, required this.players});

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
            Text("WINNER: ${winner.name}", style: const TextStyle(fontSize: 28, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            // STATS TABLE
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 25,
                headingRowColor: MaterialStateProperty.all(Colors.white10),
                columns: [
                  const DataColumn(label: Text("Stat")),
                  ...players.map((p) => DataColumn(label: Text(p.name, style: const TextStyle(color: Colors.amber)))),
                ],
                rows: [
                  _buildRow("3-Dart Avg", players.map((p) => p.average.toStringAsFixed(1)).toList()),
                  _buildRow("Checkout %", players.map((p) => "${p.checkoutPercentage.toStringAsFixed(1)}%").toList()),
                  _buildRow("100+", players.map((p) => "${p.countScore(100, 140)}").toList()),
                  _buildRow("140+", players.map((p) => "${p.countScore(140, 180)}").toList()),
                  _buildRow("180s", players.map((p) => "${p.countScore(180)}").toList()),
                  _buildRow("Highest Out", players.map((p) => "TBD").toList()), // Optional: track highest finish
                ],
              ),
            ),

            const SizedBox(height: 40),
            _buildLegHistory(),
            
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
      DataCell(Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
      ...values.map((v) => DataCell(Text(v))),
    ]);
  }

  Widget _buildLegHistory() {
    return Column(
      children: [
        const Text("Match Flow", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        // This is where you'd map through a list of who won which leg
        // e.g., "Leg 1: Player 1 (14 Darts)"
      ],
    );
  }
}