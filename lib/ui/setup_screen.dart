import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/match_provider.dart';
import '../models/match_config.dart';
import '../logic/db_helper.dart';
import 'match_screen.dart';
import 'history_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  _SetupScreenState createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  // Config Defaults
  int sets = 1;
  int legs = 1;
  int startScore = 501;
  MatchMode mode = MatchMode.bestOf; // Default mode

  // Roster
  List<String> _roster = [];
  final List<String> _selectedPlayers = [];
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRoster();
  }

  void _loadRoster() async {
    final list = await DBHelper.getPlayers();
    setState(() => _roster = list);
  }

  void _addPlayerToRoster() async {
    if (_nameController.text.isNotEmpty) {
      await DBHelper.addPlayer(_nameController.text);
      _nameController.clear();
      _loadRoster();
    }
  }

  void _deletePlayer(String name) async {
    await DBHelper.deletePlayer(name);
    setState(() => _selectedPlayers.remove(name));
    _loadRoster();
  }

  void _toggleSelection(String name) {
    setState(() {
      if (_selectedPlayers.contains(name)) {
        _selectedPlayers.remove(name);
      } else {
        _selectedPlayers.add(name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Match Setup"),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const HistoryScreen())),
          )
        ],
      ),
      body: Column(
        children: [
          // SETTINGS PANEL
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white.withOpacity(0.05),
            child: Column(
              children: [
                _buildScorePicker(),
                const SizedBox(height: 10),
                
                // MODE SELECTOR
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Match Mode:", style: TextStyle(fontSize: 16)),
                    DropdownButton<MatchMode>(
                      value: mode,
                      dropdownColor: Colors.grey[900],
                      items: const [
                        DropdownMenuItem(value: MatchMode.bestOf, child: Text("Best of")),
                        DropdownMenuItem(value: MatchMode.firstTo, child: Text("First to")),
                      ],
                      onChanged: (val) => setState(() => mode = val!),
                    ),
                  ],
                ),
                
                // DYNAMIC LABELS FOR BOTH
                _buildCounter(
                  mode == MatchMode.bestOf ? "Sets (Best Of)" : "Sets (Target)", 
                  sets, 
                  (val) => setState(() => sets = val)
                ),
                _buildCounter(
                  mode == MatchMode.bestOf ? "Legs (Best Of)" : "Legs (Target)", 
                  legs, 
                  (val) => setState(() => legs = val)
                ),
              ],
            ),
          ),

          // PLAYER LIST
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text("Select Players", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(hintText: "Add friend's name", isDense: true, border: OutlineInputBorder()),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.add_circle, color: Colors.greenAccent), onPressed: _addPlayerToRoster)
                  ],
                ),
                const SizedBox(height: 20),

                if (_roster.isEmpty) const Text("No players saved.", style: TextStyle(color: Colors.grey)),

                ..._roster.map((name) {
                  final isSelected = _selectedPlayers.contains(name);
                  return Card(
                    color: isSelected ? Colors.greenAccent.withOpacity(0.2) : Colors.white10,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      onTap: () => _toggleSelection(name),
                      leading: Icon(isSelected ? Icons.check_box : Icons.check_box_outline_blank, color: isSelected ? Colors.greenAccent : Colors.grey),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20), onPressed: () => _deletePlayer(name)),
                    ),
                  );
                }),
              ],
            ),
          ),

          // START BUTTON
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                  onPressed: () {
                    if (_selectedPlayers.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select at least 1 player")));
                      return;
                    }

                    final config = MatchConfig(
                      playerNames: _selectedPlayers,
                      mode: mode,
                      setsToWin: sets,
                      legsToWinSet: legs,
                      startingScore: startScore,
                    );
                    Provider.of<MatchProvider>(context, listen: false).setupMatch(config);
                    Navigator.push(context, MaterialPageRoute(builder: (c) => const MatchScreen()));
                  },
                  child: Text("START MATCH (${_selectedPlayers.length})", style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScorePicker() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Start Score:", style: TextStyle(fontSize: 16)),
        DropdownButton<int>(
          value: startScore,
          items: [101, 201, 301, 501].map((int val) => DropdownMenuItem(value: val, child: Text("$val"))).toList(),
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