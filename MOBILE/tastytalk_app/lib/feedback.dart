import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'cloudinary_service.dart';

class FeedbackPage extends StatefulWidget {
  final String dishName;
  final String? recipeImageUrl;
  final List<Map<String, dynamic>>? originalIngredients;
  final List<String>? originalProcedures;
  final Map<String, String>? ingredientSubstitutions;
  final List<String>? modifiedProcedures;

  const FeedbackPage({
    super.key,
    required this.dishName,
    this.recipeImageUrl,
    this.originalIngredients,
    this.originalProcedures,
    this.ingredientSubstitutions,
    this.modifiedProcedures,
  });

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final TextEditingController _feedbackController = TextEditingController();
  double _rating = 3;
  String skillLevel = "Unrated";
  bool _uploading = false;
  String? _uploadedUrl;
  final ImagePicker _picker = ImagePicker();
  final CloudinaryService _cloudinary = CloudinaryService(
    cloudName: 'dhhvbvxsl',
    uploadPreset: 'tastytalk_unsigned',
  );

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
        if (_uploadedUrl != null) 'finishedImageUrl': _uploadedUrl,
        if (widget.recipeImageUrl != null)
          'recipeImageUrl': widget.recipeImageUrl,
        if (widget.originalIngredients != null)
          'originalIngredients': widget.originalIngredients,
        if (widget.originalProcedures != null)
          'originalProcedures': widget.originalProcedures,
        if (widget.ingredientSubstitutions != null)
          'ingredientSubstitutions': widget.ingredientSubstitutions,

      });

      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(const SnackBar(content: Text("Feedback submitted!")));

      _feedbackController.clear();
      _loadSkillLevel();
      
      // Redirect to home after 1 second
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    }
  }

  Future<void> _pickAndUploadFinishedProduct() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _uploading = true);
      final file = File(picked.path);
      final url = await _cloudinary.uploadImage(file);

      setState(() {
        _uploadedUrl = url;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image uploaded! Will be saved with feedback.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Your Cooking Feedback'),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
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
            const SizedBox(height: 20),

            // Recipe Image Section
            if (widget.recipeImageUrl != null) ...[
              const Text(
                'Recipe Image:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    widget.recipeImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(
                            Icons.error,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Modified Recipe Section
            if (widget.ingredientSubstitutions != null &&
                widget.ingredientSubstitutions!.isNotEmpty) ...[
              const Text(
                'Modified Recipe:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      widget.ingredientSubstitutions!.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.swap_horiz,
                                color: Colors.blue,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${entry.key} → ${entry.value}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Recipe Section
            if (widget.originalIngredients != null &&
                widget.originalIngredients!.isNotEmpty) ...[
              const Text(
                'Recipe:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      widget.originalIngredients!.map((ingredient) {
                        final name = ingredient['name'] ?? '';
                        final quantity = ingredient['quantity'] ?? '';
                        final unit = ingredient['unit'] ?? '';
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.circle,
                                color: Colors.green,
                                size: 8,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '$quantity $unit $name'.trim(),
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],

            const SizedBox(height: 10),
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
            // Upload finished product image
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _uploading ? null : _pickAndUploadFinishedProduct,
                  icon:
                      _uploading
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Icon(Icons.cloud_upload),
                  label: Text(
                    _uploading ? 'Uploading...' : 'Upload finished product',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                if (_uploadedUrl != null)
                  Expanded(
                    child: Text(
                      _uploadedUrl!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
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
