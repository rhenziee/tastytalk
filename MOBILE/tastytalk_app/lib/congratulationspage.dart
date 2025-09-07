import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
// Upload flow moved to feedback.dart
import 'menu.dart';
import 'feedback.dart';

class CongratulationsPage extends StatefulWidget {
  final String recipeTitle;
  final String language;
  final String? recipeImageUrl;
  final List<Map<String, dynamic>>? originalIngredients;
  final List<String>? originalProcedures;
  final Map<String, String>? ingredientSubstitutions;
  final List<String>? modifiedProcedures;

  const CongratulationsPage({
    super.key,
    required this.recipeTitle,
    required this.language,
    this.recipeImageUrl,
    this.originalIngredients,
    this.originalProcedures,
    this.ingredientSubstitutions,
    this.modifiedProcedures,
  });

  @override
  State<CongratulationsPage> createState() => _CongratulationsPageState();
}

class _CongratulationsPageState extends State<CongratulationsPage> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 5),
    );
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange.shade50,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Centered celebration content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Center(
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 10,
                child: Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade200, Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Lottie.asset(
                        'lib/assets/animations/celebrations.json',
                        height: 150,
                        repeat: false,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "🎉 Congratulations!",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "You’ve finished cooking ${widget.recipeTitle}!",
                        style: const TextStyle(
                          fontSize: 20,
                          fontStyle: FontStyle.italic,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      // Upload button removed; moved to FeedbackPage
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      HomePage(language: widget.language),
                            ),
                            (route) => false,
                          );
                        },
                        icon: const Icon(Icons.home),
                        label: const Text("Return Home"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => FeedbackPage(
                                    dishName: widget.recipeTitle,
                                    recipeImageUrl: widget.recipeImageUrl,
                                    originalIngredients:
                                        widget.originalIngredients,
                                    originalProcedures:
                                        widget.originalProcedures,
                                    ingredientSubstitutions:
                                        widget.ingredientSubstitutions,
                                    modifiedProcedures:
                                        widget.modifiedProcedures,
                                  ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.star),
                        label: const Text("Rate Cooking Experience"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Confetti overlay
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            emissionFrequency: 0.08,
            numberOfParticles: 30,
            gravity: 0.1,
            colors: const [
              Colors.green,
              Colors.orange,
              Colors.pink,
              Colors.blue,
            ],
          ),
        ],
      ),
    );
  }
}
