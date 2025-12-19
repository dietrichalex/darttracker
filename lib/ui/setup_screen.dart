import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/match_provider.dart';
import '../models/match_config.dart';
import 'match_screen.dart';
import 'history_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  _SetupScreenState createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final List<TextEditingController> _controllers = [
    TextEditingController(text: "A"),
    TextEditingController(text: "B")
  ];
  
  int sets = 1;
  int legs = 1;
  int startScore = 501;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Match Setup"),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context, 
              MaterialPageRoute(builder: (c) => const HistoryScreen())
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Game Rules"),
            _buildScorePicker(),
            const SizedBox(height: 10),
            _buildCounter("Best of Sets", sets, (val) => setState(() => sets = val)),
            _buildCounter("Legs per Set", legs, (val) => setState(() => legs = val)),
            
            const Divider(height: 40),
            
            _buildSectionTitle("Players"),
            ..._controllers.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: entry.value,
                  decoration: InputDecoration(
                    labelText: "Player ${entry.key + 1}",
                    suffixIcon: _controllers.length > 1 
                      ? IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => setState(() => _controllers.removeAt(entry.key)),
                        )
                      : null,
                  ),
                ),
              );
            }),
            TextButton.icon(
              onPressed: () => setState(() => _controllers.add(TextEditingController())),
              icon: const Icon(Icons.add),
              label: const Text("Add Player"),
            ),
            
            const SizedBox(height: 40),
            
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                ),
                onPressed: () {
                  final config = MatchConfig(
                    playerNames: _controllers.map((c) => c.text).toList(),
                    setsToWin: sets,
                    legsToWinSet: legs,
                    startingScore: startScore,
                  );
                  Provider.of<MatchProvider>(context, listen: false).setupMatch(config);
                  Navigator.push(context, MaterialPageRoute(builder: (c) => const MatchScreen()));
                },
                child: const Text("START MATCH"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
    );
  }

  Widget _buildScorePicker() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Starting Points:", style: TextStyle(fontSize: 16)),
        DropdownButton<int>(
          value: startScore,
          items: [101, 201, 301, 501].map((int val) {
            return DropdownMenuItem<int>(value: val, child: Text("$val"));
          }).toList(),
          onChanged: (val) => setState(() => startScore = val!),
        ),
      ],
    );
  }

  Widget _buildCounter(String label, int value, Function(int) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        Row(
          children: [
            IconButton(icon: const Icon(Icons.remove), onPressed: () => value > 1 ? onChanged(value - 1) : null),
            Text("$value", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.add), onPressed: () => onChanged(value + 1)),
          ],
        ),
      ],
    );
  }
}