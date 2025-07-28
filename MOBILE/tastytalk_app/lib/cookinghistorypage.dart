import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CookingHistoryPage extends StatelessWidget {
  const CookingHistoryPage({super.key});

  Future<List<Map<String, dynamic>>> _fetchHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final snapshot =
        await FirebaseFirestore.instance
            .collection('cooking_history')
            .doc(user.uid)
            .collection('recipes')
            .orderBy('timestamp', descending: true)
            .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cooking History'),
        backgroundColor: Colors.orange,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final history = snapshot.data ?? [];

          if (history.isEmpty) {
            return const Center(child: Text("No cooking history found."));
          }

          return ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final recipe = history[index];
              return ListTile(
                leading:
                    recipe['imageUrl'] != null
                        ? CircleAvatar(
                          backgroundImage: NetworkImage(recipe['imageUrl']),
                        )
                        : const Icon(Icons.restaurant_menu),
                title: Text(recipe['title'] ?? 'Unknown Recipe'),
                subtitle: Text(recipe['duration'] ?? 'No duration'),
                trailing: const Icon(Icons.check_circle, color: Colors.green),
              );
            },
          );
        },
      ),
    );
  }
}
