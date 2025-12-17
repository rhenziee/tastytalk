import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class CookingLevelPage extends StatefulWidget {
  const CookingLevelPage({super.key});

  @override
  State<CookingLevelPage> createState() => _CookingLevelPageState();
}

class _CookingLevelPageState extends State<CookingLevelPage> {
  final FlutterTts flutterTts = FlutterTts();

  Future<Map<String, dynamic>> _fetchRatingsSummary() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'average': 0.0, 'count': 0};

    final snapshot =
        await FirebaseFirestore.instance
            .collection('feedback')
            .where('userId', isEqualTo: user.uid)
            .get();

    double total = 0.0;
    int count = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data.containsKey('rating')) {
        total += data['rating']?.toDouble() ?? 0.0;
        count++;
      }
    }

    double average = count > 0 ? total / count : 0.0;

    return {'average': average, 'count': count};
  }

  String _getCookingLevel(double avgRating) {
    if (avgRating >= 4.5) return "A Cook";
    if (avgRating >= 3.5) return "Better";
    if (avgRating >= 2.0) return "Good";
    return "Not Good";
  }

  Future<void> _speak(String level) async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.speak("Hi! Your skill level is currently $level");
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cooking Level Summary',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFFF3642B),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchRatingsSummary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          final double avg = data['average'];
          final int count = data['count'];
          final String level = _getCookingLevel(avg);

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _speak(level);
          });

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 10,
                shadowColor: Colors.orangeAccent,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3642B),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, size: 80, color: Colors.white),
                      const SizedBox(height: 10),
                      Text(
                        'Total Feedback Sent: $count',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Average Rating: ${avg.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Cooking Skill Level',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        level,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
