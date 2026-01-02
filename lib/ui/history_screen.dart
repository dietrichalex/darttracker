import 'dart:convert';
import 'package:flutter/material.dart';
import '../logic/db_helper.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() async {
    final data = await DBHelper.getMatches();
    setState(() {
      _history = data;
    });
  }

  void _deleteMatch(int id) async {
    await DBHelper.deleteMatch(id);
    _loadHistory();
  }
  
  void _confirmDelete(int id) {
    showDialog(
      context: context, 
      builder: (c) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Delete Match?", style: TextStyle(color: Colors.white)),
        content: const Text("This cannot be undone.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              _deleteMatch(id);
            }, 
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent))
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("Match History"),
        backgroundColor: Colors.transparent,
      ),
      body: _history.isEmpty
          ? const Center(child: Text("No matches played yet.", style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final match = _history[index];
                return Card(
                  color: Colors.white.withOpacity(0.05),
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ExpansionTile(
                    title: Text(
                      "${match['winner']} won", 
                      style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)
                    ),
                    subtitle: Text(
                      "Match Avg: ${match['avg']}  •  ${match['date']}", 
                      style: const TextStyle(color: Colors.grey)
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _confirmDelete(match['id']),
                    ),
                    children: [
                       _buildMatchDetails(match['details'])
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildMatchDetails(String jsonDetails) {
    List<dynamic> legs = jsonDecode(jsonDetails);
    return Column(
      children: legs.map<Widget>((leg) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1)))
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Leg ${leg['leg_number']}", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...leg['players'].map<Widget>((p) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(5)
                  ),
                  child: Column(
                    children: [
                      // Header: Name and Win Status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(p['name'], style: TextStyle(color: p['won'] ? Colors.greenAccent : Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          if (p['won']) const Icon(Icons.check_circle, color: Colors.greenAccent, size: 16)
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Stats Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _statBox("Avg", p['avg']),
                          _statBox("1st 9", p['first9']),
                          _statBox("CO %", "${p['co_percent']}%"),
                          _statBox("Darts", "${p['darts']}"),
                        ],
                      )
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      }).toList(),
    );
  }
  
  Widget _statBox(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}