import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FeedbackPage extends StatefulWidget {
  final String dishName;

  const FeedbackPage({super.key, required this.dishName});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final TextEditingController _feedbackController = TextEditingController();
  double _rating = 3;
  String skillLevel = "Unrated";

  @override
  void initState() {
    super.initState();
    _loadSkillLevel();
  }

  void _loadSkillLevel() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final feedbacks =
          await FirebaseFirestore.instance
              .collection('feedback')
              .where('userId', isEqualTo: user.uid)
              .get();

      if (feedbacks.docs.isNotEmpty) {
        double average =
            feedbacks.docs
                .map((doc) => doc['rating'] as num)
                .reduce((a, b) => a + b) /
            feedbacks.docs.length;

        setState(() {
          if (average < 2) {
            skillLevel = "Not Good";
          } else if (average < 3.5) {
            skillLevel = "Good";
          } else if (average < 4.5) {
            skillLevel = "Better";
          } else {
            skillLevel = "A Cook!";
          }
        });
      }
    }
  }

  Future<void> _submitFeedback() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('feedback').add({
        'userId': user.uid,
        'dishName': widget.dishName,
        'comment': _feedbackController.text.trim(),
        'rating': _rating,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(const SnackBar(content: Text("Feedback submitted!")));

      _feedbackController.clear();
      _loadSkillLevel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Cooking Feedback'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Dish: ${widget.dishName}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Your Current Cooking Skill Level: $skillLevel',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color:
                    skillLevel == "A Cook!"
                        ? Colors.green
                        : skillLevel == "Better"
                        ? Colors.lightGreen
                        : skillLevel == "Good"
                        ? Colors.orange
                        : Colors.red,
              ),
            ),
            const SizedBox(height: 30),
            const Text('Rate this Dish:', style: TextStyle(fontSize: 16)),
            Slider(
              value: _rating,
              min: 1,
              max: 5,
              divisions: 4,
              label: _rating.toString(),
              onChanged: (value) {
                setState(() {
                  _rating = value;
                });
              },
            ),
            TextField(
              controller: _feedbackController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Leave your feedback',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _submitFeedback,
              icon: const Icon(Icons.send),
              label: const Text('Submit Feedback'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            ),
          ],
        ),
      ),
    );
  }
}
