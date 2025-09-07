import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class CookingHistoryPage extends StatefulWidget {
  const CookingHistoryPage({super.key});

  @override
  State<CookingHistoryPage> createState() => _CookingHistoryPageState();
}

class _CookingHistoryPageState extends State<CookingHistoryPage> {
  Future<Map<String, dynamic>> _fetchHistoryData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    try {
      // Fetch cooking history
      final historySnapshot =
          await FirebaseFirestore.instance
              .collection('cooking_history')
              .doc(user.uid)
              .collection('recipes')
              .orderBy('timestamp', descending: true)
              .get();

      final history = historySnapshot.docs.map((doc) => doc.data()).toList();

      // Fetch feedback for each recipe
      final feedbackSnapshot =
          await FirebaseFirestore.instance
              .collection('feedback')
              .where('userId', isEqualTo: user.uid)
              .get();

      final feedback = feedbackSnapshot.docs.map((doc) => doc.data()).toList();

      return {'history': history, 'feedback': feedback};
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching history data: $e');
      }
      return {};
    }
  }

  Widget _buildHistoryCard(
    Map<String, dynamic> recipe,
    List<Map<String, dynamic>> feedback,
  ) {
    final recipeTitle = recipe['title'] ?? 'Unknown Recipe';
    final recipeTimestamp = recipe['timestamp'];

    // Match feedback by dish name AND cooking session timestamp
    final recipeFeedback =
        feedback.where((f) {
          final sameDish = f['dishName'] == recipeTitle;
          final sameSession = _isSameCookingSession(
            recipeTimestamp,
            f['timestamp'],
          );
          return sameDish && sameSession;
        }).toList();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        leading:
            recipe['imageUrl'] != null
                ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    recipe['imageUrl'],
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.restaurant_menu,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                )
                : Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.restaurant_menu, color: Colors.grey),
                ),
        title: Text(
          recipeTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(recipe['duration'] ?? 'No duration'),
            if (recipe['timestamp'] != null)
              Text(
                'Cooked on: ${_formatTimestamp(recipe['timestamp'])}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
        trailing: const Icon(Icons.expand_more),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recipe details
                if (recipe['ingredients'] != null) ...[
                  const Text(
                    'Ingredients Used:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate((recipe['ingredients'] as List).length, (
                    index,
                  ) {
                    final ingredient = recipe['ingredients'][index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${ingredient['quantity'] ?? ''} ${ingredient['unit'] ?? ''} ${ingredient['name'] ?? ''}'
                                  .trim(),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],

                // Feedback section
                if (recipeFeedback.isNotEmpty) ...[
                  const Text(
                    'Your Feedback:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  ...recipeFeedback.map(
                    (f) => Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ...List.generate(
                                5,
                                (index) => Icon(
                                  index < (f['rating'] ?? 0)
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('${f['rating'] ?? 0}/5'),
                            ],
                          ),
                          if (f['comment'] != null &&
                              f['comment'].toString().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              f['comment'],
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          if (f['finishedImageUrl'] != null &&
                              f['finishedImageUrl'].toString().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Your Finished Product:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                f['finishedImageUrl'],
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 120,
                                    height: 120,
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.error,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                          if (f['recipeImageUrl'] != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.restaurant_menu,
                                  color: Colors.green,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Recipe image included',
                                    style: TextStyle(
                                      color: Colors.green[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (f['ingredientSubstitutions'] != null &&
                              (f['ingredientSubstitutions'] as Map)
                                  .isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.swap_horiz,
                                  color: Colors.orange,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Alternative ingredients used',
                                    style: TextStyle(
                                      color: Colors.orange[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (f['modifiedProcedures'] != null &&
                              (f['modifiedProcedures'] as List).isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.edit,
                                  color: Colors.purple,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Modified procedures used',
                                    style: TextStyle(
                                      color: Colors.purple[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // No feedback message
                if (recipeFeedback.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'No feedback or finished product uploaded yet',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameCookingSession(
    dynamic recipeTimestamp,
    dynamic feedbackTimestamp,
  ) {
    // If either timestamp is null, they're not the same session
    if (recipeTimestamp == null || feedbackTimestamp == null) return false;

    // Convert to DateTime for comparison
    DateTime? recipeDate;
    DateTime? feedbackDate;

    if (recipeTimestamp is Timestamp) {
      recipeDate = recipeTimestamp.toDate();
    }

    if (feedbackTimestamp is Timestamp) {
      feedbackDate = feedbackTimestamp.toDate();
    }

    // If we can't convert either, they're not the same session
    if (recipeDate == null || feedbackDate == null) return false;

    // Consider it the same session if within 1 hour of each other
    // This accounts for the time between cooking completion and feedback submission
    final difference = recipeDate.difference(feedbackDate).abs();
    return difference.inHours <= 1;
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return 'Unknown date';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cooking History'),
        backgroundColor: Colors.orange,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchHistoryData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data ?? {};
          final history = data['history'] ?? [];
          final feedback = data['feedback'] ?? [];

          if (history.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "No cooking history found.",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Start cooking to see your history here!",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final recipe = history[index];
              return _buildHistoryCard(recipe, feedback);
            },
          );
        },
      ),
    );
  }
}
