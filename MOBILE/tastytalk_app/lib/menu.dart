// 👇 Your imports remain unchanged
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';

import 'recipe_model.dart';
import 'menu_content.dart';
import 'user_menupage.dart';
import 'notifications_page.dart';
import 'main.dart';
import 'cookinglevelpage.dart';
import 'cookinghistorypage.dart';

class HomePage extends StatefulWidget {
  final String language;
  const HomePage({super.key, required this.language});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  List<RecipeModel> allRecipes = [];
  List<RecipeModel> filteredRecipes = [];
  TextEditingController searchController = TextEditingController();

  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _navigating = false;
  String _lastWords = '';
  bool _initialized = false;
  late String _ttsLang;
  late String _sttLang;
  late String _textLang;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.orange,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    final lang = widget.language.toLowerCase();
    if (lang.contains('en')) {
      _ttsLang = 'en-US';
      _sttLang = 'en_US';
      _textLang = 'en';
    } else {
      _ttsLang = 'fil-PH';
      _sttLang = 'fil_PH';
      _textLang = 'fil';
    }

    fetchRecipes();
    _initSpeech();
    _initTTS();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);

    if (_initialized) return;
    _initialized = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _greetUser();
      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 200));
        return _isSpeaking;
      });
      _startListening();
    });
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _speech.stop();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  void didPopNext() {
    _navigating = false;
    _isSpeaking = false;
    _speech.stop();
    _flutterTts.stop();

    Future.delayed(const Duration(milliseconds: 300), () async {
      await _greetBackUser();
      await Future.delayed(const Duration(milliseconds: 500));
      _startListening();
    });
  }

  void _initSpeech() async {
    _speech = stt.SpeechToText();
    await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
          if (!_isSpeaking && !_navigating) {
            Future.delayed(const Duration(milliseconds: 600), _startListening);
          }
        }
      },
      onError: (error) {
        setState(() => _isListening = false);
        Future.delayed(const Duration(seconds: 1), _startListening);
      },
    );
  }

  void _initTTS() {
    _flutterTts = FlutterTts();
    _flutterTts.setLanguage(_ttsLang);
    _flutterTts.awaitSpeakCompletion(true);

    _flutterTts.setStartHandler(() {
      _isSpeaking = true;
    });

    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
      if (!_navigating) _startListening();
    });

    _flutterTts.setErrorHandler((msg) {
      debugPrint("TTS Error: $msg");
      _isSpeaking = false;
    });

    // ⛔ Prevent interruption by stopping previous TTS if ongoing
    _flutterTts.setCancelHandler(() {
      _isSpeaking = false;
      debugPrint("TTS Cancelled");
    });
  }

  Future<void> _greetUser() async {
    if (_isSpeaking || _navigating) return;

    String greeting =
        _textLang == 'en'
            ? "Welcome! How may I help you?"
            : "Maligayang pagdating! Paano kita matutulungan?";

    _isSpeaking = true;
    await _speech.stop();
    await _flutterTts.speak(greeting);
    await _flutterTts.awaitSpeakCompletion(true);
    _isSpeaking = false;
  }

  Future<void> _greetBackUser() async {
    if (_isSpeaking || _navigating) return;

    String greeting =
        _textLang == 'en'
            ? "Welcome back! How may I help you?"
            : "Welcome back! Paano kita matutulungan?";

    _isSpeaking = true;
    await _speech.stop();
    await _flutterTts.awaitSpeakCompletion(true); // make sure it's set
    await _flutterTts.speak(greeting);
    await _flutterTts.awaitSpeakCompletion(true);
    _isSpeaking = false;
  }

  Future<void> _startListening() async {
    if (_isListening || _navigating || _isSpeaking) return;

    setState(() => _isListening = true);
    await _speech.listen(
      localeId: _sttLang,
      onResult: (result) {
        if (result.finalResult) {
          _lastWords = result.recognizedWords.toLowerCase();
          _processCommand(_lastWords);
        }
      },
    );
  }

  Future<void> _processCommand(String command) async {
    final normalized = command.toLowerCase();

    if (normalized.contains("view my cooking level") ||
        normalized.contains("cooking level") ||
        normalized.contains("aking antas sa pagluluto")) {
      _isSpeaking = true;
      await _flutterTts.speak(
        _textLang == 'en'
            ? "Opening your cooking level page."
            : "Binubuksan ang iyong cooking level.",
      );
      await _flutterTts.awaitSpeakCompletion(true);
      _speech.stop();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CookingLevelPage()),
      );
      return;
    }

    if (normalized.contains("view my cooking history") ||
        normalized.contains("my history") ||
        normalized.contains("aking kasaysayan") ||
        normalized.contains("kasaysayan ng pagluluto")) {
      _isSpeaking = true;
      await _flutterTts.speak(
        _textLang == 'en'
            ? "Opening your cooking history."
            : "Binubuksan ang iyong kasaysayan sa pagluluto.",
      );
      await _flutterTts.awaitSpeakCompletion(true);
      _speech.stop();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CookingHistoryPage()),
      );
      return;
    }

    final triggers = [
      'search for',
      'i want to cook',
      'i want to eat',
      'gusto kong magluto ng',
      'gusto kong kumain ng',
      'hanapin ang',
      'hanapin mo',
      'cook',
      'eat',
    ];

    String? extractedDish;
    for (final trigger in triggers) {
      if (normalized.contains(trigger)) {
        extractedDish = normalized.split(trigger).last.trim();
        break;
      }
    }

    if (extractedDish == null || extractedDish.isEmpty) {
      await _flutterTts.speak(
        _textLang == 'en' ? "How may I help you?" : "Papano kita matutulungan",
      );
      await _flutterTts.awaitSpeakCompletion(true);
      _isSpeaking = false;
      return;
    }

    _isSpeaking = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    await _flutterTts.speak(
      _textLang == 'en'
          ? "Searching for the recipe $extractedDish..."
          : "Hinahanap ang resipe na $extractedDish...",
    );
    await _flutterTts.awaitSpeakCompletion(true);

    for (var recipe in allRecipes) {
      final recipeName = recipe.title.toLowerCase();
      if (extractedDish.contains(recipeName) ||
          recipeName.contains(extractedDish)) {
        await _flutterTts.speak(
          _textLang == 'en'
              ? "Here's the recipe guide for ${recipe.title}."
              : "Narito ang gabay sa pagluluto ng ${recipe.title}.",
        );
        await _flutterTts.awaitSpeakCompletion(true);

        _isSpeaking = false;
        _speech.stop();
        if (!mounted) return;
        Navigator.pop(context);
        _navigating = true;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => MenuContentPage(
                  title: recipe.title,
                  imageUrl: recipe.image,
                  ingredients: List<Map<String, dynamic>>.from(
                    recipe.ingredients,
                  ),
                  procedures: recipe.procedures,
                  duration: recipe.duration,
                  language: _textLang,
                ),
          ),
        );
        _navigating = false;
        return;
      }
    }

    await _flutterTts.speak(
      _textLang == 'en'
          ? "Sorry, that recipe is not available in the app."
          : "Paumanhin, ang resipe na iyon ay wala sa app.",
    );
    await _flutterTts.awaitSpeakCompletion(true);

    _isSpeaking = false;
    if (mounted) Navigator.pop(context);
  }

  Future<void> fetchRecipes() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('dishes').get();
    final recipes =
        snapshot.docs
            .where((doc) => doc.data()['archived'] != true)
            .map((doc) => RecipeModel.fromMap(doc.data()))
            .toList();

    setState(() {
      allRecipes = recipes;
      filteredRecipes = recipes;
    });
  }

  void filterRecipes(String query) {
    final results =
        allRecipes
            .where(
              (recipe) =>
                  recipe.title.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();

    setState(() => filteredRecipes = results);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.orange,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: false,
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            Container(
              height: MediaQuery.of(context).padding.top,
              color: Colors.orange,
            ),
            SafeArea(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(25),
                        bottomRight: Radius.circular(25),
                      ),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const UserMenuPage(),
                              ),
                            );
                          },
                          child: const CircleAvatar(
                            backgroundColor: Colors.white,
                            child: Icon(Icons.person, color: Colors.orange),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            onChanged: filterRecipes,
                            decoration: InputDecoration(
                              hintText: 'Search here',
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: const Icon(
                            Icons.notifications,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotificationsPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ListView(
                        children: [
                          const SizedBox(height: 20),
                          const Text(
                            "Popular Recipes",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (filteredRecipes.isEmpty)
                            const Text('No recipes available.')
                          else
                            Column(
                              children:
                                  filteredRecipes.map((dish) {
                                    return GestureDetector(
                                      onTap: () async {
                                        _navigating = true;
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (_) => MenuContentPage(
                                                  title: dish.title,
                                                  imageUrl: dish.image,
                                                  ingredients: dish.ingredients,
                                                  procedures: dish.procedures,
                                                  duration: dish.duration,
                                                  language: _textLang,
                                                ),
                                          ),
                                        );
                                        _navigating = false;
                                      },
                                      child: RecipeCard(
                                        image: dish.image,
                                        title: dish.title,
                                        duration: dish.duration,
                                        rating: dish.rating,
                                      ),
                                    );
                                  }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ✅ REUSABLE RECIPE CARD
class RecipeCard extends StatelessWidget {
  final String image;
  final String title;
  final String duration;
  final double rating;

  const RecipeCard({
    super.key,
    required this.image,
    required this.title,
    required this.duration,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.15),
            blurRadius: 12,
            spreadRadius: 2,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Image.network(
              image,
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.orange, size: 16),
                    const SizedBox(width: 5),
                    Text(rating.toStringAsFixed(1)),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.timer, size: 16),
                    const SizedBox(width: 5),
                    Text(duration),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
