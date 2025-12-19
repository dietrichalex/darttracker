import 'package:flutter/material.dart';
import '../logic/db_helper.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Match History")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        // This assumes you saved match data in DBHelper
        future: _loadHistory(), 
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No matches played yet."));
          }

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final match = snapshot.data![index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                color: Colors.white10,
                child: ListTile(
                  leading: const Icon(Icons.history, color: Colors.amber),
                  title: Text("Winner: ${match['winner']}"),
                  subtitle: Text("Avg: ${match['avg']} | ${match['date']}"),
                  trailing: const Icon(Icons.chevron_right),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadHistory() async {
    final db = await DBHelper.database;
    return await db.query('matches', orderBy: 'id DESC');
  }
}