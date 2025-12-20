import 'package:flutter/material.dart';
import '../logic/db_helper.dart';
import 'dart:convert';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Match History")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DBHelper.getHistory(), 
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No matches played yet."));
          }

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final match = snapshot.data![index];
              return Card(
                color: Colors.white10,
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.emoji_events, color: Colors.amber),
                  title: Text("${match['winner']} won"),
                  subtitle: Text(match['date']),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (c) => MatchDetailScreen(match: match)
                    ));
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class MatchDetailScreen extends StatelessWidget {
  final Map<String, dynamic> match;
  const MatchDetailScreen({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    // 1. Decode the rich details
    List<dynamic> legs = [];
    try {
      if (match['details'] != null) {
        legs = jsonDecode(match['details']);
      }
    } catch (e) {
      // Fallback for old data format (List<String>)
      legs = []; 
    }

    // Check if data is in the old "Log String" format or new "Rich Map" format
    bool isRichData = legs.isNotEmpty && legs[0] is Map;

    return Scaffold(
      appBar: AppBar(title: const Text("Match Breakdown")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Stats
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("WINNER", style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                      Text(match['winner'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text("MATCH AVG", style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                      Text("${match['avg']}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            const Text("Leg Analysis", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            if (!isRichData)
              const Text("Detailed leg stats not available for this match.", style: TextStyle(color: Colors.grey))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: legs.length,
                itemBuilder: (context, i) {
                  final legData = legs[i]; // Map of 'leg_number' and 'players'
                  final int legNum = legData['leg_number'];
                  final List playersData = legData['players'];

                  return Card(
                    color: Colors.white10,
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blueGrey,
                        child: Text("$legNum", style: const TextStyle(color: Colors.white)),
                      ),
                      title: Text("Leg $legNum Stats"),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: Column(
                            children: playersData.map((p) {
                              bool won = p['won'] == true;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 5.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        if (won) const Icon(Icons.star, color: Colors.amber, size: 16),
                                        if (won) const SizedBox(width: 5),
                                        Text(p['name'], style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: won ? Colors.amber : Colors.white
                                        )),
                                      ],
                                    ),
                                    Text("Avg: ${p['avg']}", style: const TextStyle(color: Colors.grey)),
                                    Text("${p['darts']} Darts", style: const TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        )
                      ],
                    ),
                  );
                },
              )
          ],
        ),
      ),
    );
  }
}