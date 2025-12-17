// 👇 Your imports remain unchanged
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'dart:async';

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
  String selectedCategory = 'All';

  final List<String> categories = [
    'All',
    'Chicken',
    'Pork',
    'Beef',
    'Fish',
    'Vegetable',
    'Noodles',
    'Pasta',
  ];

  IconData getCategoryIcon(String category) {
    switch (category) {
      case 'All':
        return Icons.restaurant_menu;
      case 'Chicken':
        return Icons.egg_alt;
      case 'Pork':
        return Icons.lunch_dining;
      case 'Beef':
        return Icons.local_dining;
      case 'Fish':
        return Icons.set_meal;
      case 'Vegetable':
        return Icons.eco;
      case 'Noodles':
        return Icons.ramen_dining;
      case 'Pasta':
        return Icons.dining;
      default:
        return Icons.fastfood;
    }
  }

  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _navigating = false;
  bool _activated = false; // ✅ New flag: true only after "hey tata"
  String _lastWords = '';
  bool _initialized = false;
  late String _ttsLang;
  late String _sttLang;
  late String _textLang;

  // ✅ New: Better state management
  Timer? _restartTimer;
  Timer? _continuousTimer;
  bool _isProcessingCommand = false;
  bool _micEnabled = true;
  bool _isInitializing = false;
  bool _manualStop =
      false; // Flag to prevent auto-restart when manually stopped

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFFF3642B),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    final lang = widget.language.toLowerCase();
    if (lang.contains('en')) {
      _ttsLang = 'en-US';
      _sttLang = 'en-US';
      _textLang = 'en';
    } else {
      _ttsLang = 'fil-PH';
      _sttLang = 'en-US'; // still English for "hey tata" detection
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
      Future.delayed(const Duration(milliseconds: 1500), () {
        debugPrint("Starting initial voice recognition...");
        _startListening();
        _setupContinuousListening();
      });
    });
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _restartTimer?.cancel();
    _continuousTimer?.cancel();
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

    // reset wake word
    _activated = false;
    debugPrint("🔄 Assistant deactivated. Say 'Hey Tata' to activate again.");

    // restart mic with proper delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && _micEnabled) _startListening();
    });
  }

  void _initSpeech() async {
    if (_isInitializing) {
      debugPrint("⚠️ Speech already initializing, skipping...");
      return;
    }

    _isInitializing = true;

    try {
      _speech = stt.SpeechToText();

      // Check if speech recognition is available first
      bool available = await _speech.initialize(
        onStatus: (status) {
          debugPrint("Speech status: $status");

          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);

            // ✅ Better restart logic with debouncing
            if (!_isSpeaking &&
                !_navigating &&
                mounted &&
                _micEnabled &&
                !_isProcessingCommand &&
                !_manualStop) {
              _restartTimer?.cancel();
              _restartTimer = Timer(const Duration(milliseconds: 800), () {
                if (mounted &&
                    !_isSpeaking &&
                    !_navigating &&
                    _micEnabled &&
                    !_manualStop) {
                  debugPrint("🔄 Auto-restarting listening...");
                  _startListening();
                }
              });
            }
          }
        },
        onError: (error) {
          debugPrint("Speech error: $error");
          setState(() => _isListening = false);

          // ✅ Better error handling with longer delay
          _restartTimer?.cancel();
          _restartTimer = Timer(const Duration(seconds: 3), () {
            if (mounted && _micEnabled && !_isSpeaking && !_navigating) {
              _startListening();
            }
          });
        },
      );

      if (!available) {
        debugPrint("Speech recognition not available on this device");
        setState(() => _micEnabled = false);
      } else {
        debugPrint("Speech recognition initialized successfully");
        setState(() => _micEnabled = true);
      }
    } catch (e) {
      debugPrint("Error initializing speech: $e");
      setState(() => _micEnabled = false);
    } finally {
      _isInitializing = false;
    }
  }

  void _initTTS() async {
    _flutterTts = FlutterTts();

    // Optional: see all available voices on this device
    final voices = await _flutterTts.getVoices;
    debugPrint("📢 Available voices: $voices");

    // Check language support
    var langAvailable = await _flutterTts.isLanguageAvailable(_ttsLang);
    if (langAvailable == false) {
      debugPrint("⚠️ $_ttsLang not available, falling back to en-US");
      _ttsLang = "en-US";
    }

    await _flutterTts.setLanguage(_ttsLang);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      debugPrint("▶️ TTS start");
      setState(() => _isSpeaking = true);
    });

    _flutterTts.setCompletionHandler(() {
      debugPrint("✅ TTS done");
      setState(() => _isSpeaking = false);
      if (!_navigating && _micEnabled) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted && !_navigating && _micEnabled) {
            _startListening();
          }
        });
      }
    });

    _flutterTts.setErrorHandler((msg) {
      debugPrint("❌ TTS Error: $msg");
      setState(() => _isSpeaking = false);
    });

    _flutterTts.setCancelHandler(() {
      debugPrint("⏹️ TTS cancelled");
      setState(() => _isSpeaking = false);
    });
  }

  Future<void> _greetUser() async {
    if (_isSpeaking || _navigating) return;

    String greeting =
        _textLang == 'en'
            ? "Welcome! How may I help you?"
            : "Maligayang pagdating! Paano kita matutulungan?";

    setState(() => _isSpeaking = true);
    await _speech.stop();

    // siguraduhin lang na may language set
    await _flutterTts.setLanguage(_ttsLang);

    await _flutterTts.speak(greeting);
    await _flutterTts.awaitSpeakCompletion(true);

    setState(() => _isSpeaking = false);

    if (!_navigating && _micEnabled) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted && !_navigating && _micEnabled) {
          _startListening();
        }
      });
    }
  }

  void _setupContinuousListening() {
    _continuousTimer?.cancel();
    _continuousTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (!_isListening &&
          !_isSpeaking &&
          !_navigating &&
          mounted &&
          _micEnabled &&
          !_isProcessingCommand &&
          !_manualStop) {
        debugPrint("🔄 Restarting listening due to inactivity...");
        _startListening();
      }
    });
  }

  Future<void> _startListening() async {
    if (_navigating || _isSpeaking || !_micEnabled || _isProcessingCommand) {
      debugPrint(
        "🚫 Cannot start listening: navigating=$_navigating, speaking=$_isSpeaking, micEnabled=$_micEnabled, processing=$_isProcessingCommand",
      );
      return;
    }

    // ✅ Prevent rapid restarts
    if (_isListening) {
      debugPrint("⚠️ Already listening, skipping restart");
      return;
    }

    // Check if speech is available
    if (!_speech.isAvailable && !_isInitializing) {
      debugPrint("⚠️ Speech not available, requesting permissions...");
      _isInitializing = true;
      try {
        bool hasPermission = await _speech.initialize();
        if (!hasPermission) {
          debugPrint("❌ No microphone permission");
          return;
        }
      } finally {
        _isInitializing = false;
      }
    }

    // reset first
    setState(() => _isListening = false);

    try {
      debugPrint("🎤 Starting mic session...");
      bool started = await _speech.listen(
        localeId: _sttLang,
        onResult: (result) {
          debugPrint(
            "🎤 Speech result: ${result.recognizedWords} (final: ${result.finalResult})",
          );
          if (result.finalResult) {
            _lastWords = result.recognizedWords.toLowerCase();
            _processCommand(_lastWords);
          }
        },
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(
          seconds: 4,
        ), // ✅ Longer pause for better stability
      );

      if (started) {
        debugPrint("✅ Listening started successfully");
        setState(() => _isListening = true);
      } else {
        debugPrint("⚠️ Failed to start listening, retrying...");
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _micEnabled && !_isSpeaking && !_navigating) {
            _startListening();
          }
        });
      }
    } catch (e) {
      debugPrint("❌ Error starting listening: $e");
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _micEnabled && !_isSpeaking && !_navigating) {
          _startListening();
        }
      });
    }
  }

  Future<void> _processCommand(String command) async {
    if (_isProcessingCommand) return;

    _isProcessingCommand = true;
    final normalized = command.toLowerCase();
    debugPrint("Processing command: '$normalized'");

    // ✅ Phase 1: Wake word detection
    if (!_activated) {
      if (normalized.contains("hey tata") ||
          normalized.contains("heytata") ||
          normalized.contains("hi tata") ||
          normalized.contains("hello tata")) {
        _activated = true;
        await _speech.stop();
        await _greetUser(); // greet only once after activation
      }
      _isProcessingCommand = false;
      return; // ignore everything else until activated
    }

    // ✅ Phase 2: Commands only after activation
    if (normalized.contains("view my cooking level") ||
        normalized.contains("cooking level") ||
        normalized.contains("aking antas sa pagluluto")) {
      setState(() => _isSpeaking = true);
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
      _isProcessingCommand = false;
      return;
    }

    if (normalized.contains("view my cooking history") ||
        normalized.contains("my history") ||
        normalized.contains("aking kasaysayan") ||
        normalized.contains("kasaysayan ng pagluluto")) {
      setState(() => _isSpeaking = true);
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
      _isProcessingCommand = false;
      return;
    }

    // Search triggers
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
      _isProcessingCommand = false;
      return;
    }

    setState(() => _isSpeaking = true);

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

        _isProcessingCommand = false;
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
                  source: recipe.source,
                  rating: recipe.rating,
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

    _isProcessingCommand = false;
    if (mounted) Navigator.pop(context);
  }

  Future<void> fetchRecipes() async {
    // Fetch all dishes and feedback in parallel
    final results = await Future.wait([
      FirebaseFirestore.instance.collection('dishes').get(),
      FirebaseFirestore.instance.collection('feedback').get(),
    ]);

    final dishesSnapshot = results[0] as QuerySnapshot;
    final feedbackSnapshot = results[1] as QuerySnapshot;

    // Group feedback by dish name
    final Map<String, List<double>> feedbackByDish = {};
    for (final doc in feedbackSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final dishName = data['dishName'] as String;
      final rating = (data['rating'] as num).toDouble();

      feedbackByDish.putIfAbsent(dishName, () => []).add(rating);
    }

    final recipes = <RecipeModel>[];

    for (final doc in dishesSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['archived'] == true) continue;

      // Calculate average rating
      final dishName = data['name'] as String;
      double averageRating = 4.5; // Default rating

      if (feedbackByDish.containsKey(dishName)) {
        final ratings = feedbackByDish[dishName]!;
        averageRating = ratings.reduce((a, b) => a + b) / ratings.length;
      }

      // Add calculated rating to the data
      final dataWithRating = Map<String, dynamic>.from(data);
      dataWithRating['rating'] = averageRating;

      recipes.add(RecipeModel.fromMap(dataWithRating));
    }

    setState(() {
      allRecipes = recipes;
      filteredRecipes = recipes;
    });
  }

  void filterRecipes(String query) {
    List<RecipeModel> results = allRecipes;

    // Filter by category first
    if (selectedCategory != 'All') {
      results = results.where((recipe) {
        return recipe.category.toLowerCase() == selectedCategory.toLowerCase();
      }).toList();
    }

    // Then filter by search query
    if (query.isNotEmpty) {
      results = results.where((recipe) =>
        recipe.title.toLowerCase().contains(query.toLowerCase())
      ).toList();
    }

    setState(() => filteredRecipes = results);
  }

  void filterByCategory(String category) {
    setState(() => selectedCategory = category);
    filterRecipes(searchController.text);
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
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            Container(
              height: MediaQuery.of(context).padding.top,
              color: const Color(0xFFF3642B),
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
                      color: Color(0xFFF3642B),
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
                                builder:
                                    (_) => UserMenuPage(language: _textLang),
                              ),
                            );
                          },
                          child: const CircleAvatar(
                            backgroundColor: Colors.white,
                            child: Icon(Icons.person, color: Color(0xFFF3642B)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            onChanged: filterRecipes,
                            decoration: InputDecoration(
                              hintText:
                                  _textLang == 'en'
                                      ? 'Search here'
                                      : 'Maghanap dito',
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
                        StreamBuilder<QuerySnapshot>(
                          stream:
                              FirebaseFirestore.instance
                                  .collection('notifications')
                                  .orderBy('timestamp', descending: true)
                                  .snapshots(),
                          builder: (context, snapshot) {
                            int unreadCount = 0;
                            if (snapshot.hasData) {
                              final currentUserId =
                                  FirebaseAuth.instance.currentUser?.uid;
                              if (currentUserId != null) {
                                // Remove duplicates first
                                final allDocs = snapshot.data!.docs;
                                final seen = <String>{};
                                final uniqueDocs = <QueryDocumentSnapshot>[];

                                for (final doc in allDocs) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  final key =
                                      '${data['title']}_${data['message']}_${data['timestamp']}';

                                  if (!seen.contains(key)) {
                                    seen.add(key);
                                    uniqueDocs.add(doc);
                                  }
                                }

                                // Count unread from unique notifications
                                unreadCount =
                                    uniqueDocs.where((doc) {
                                      final data =
                                          doc.data() as Map<String, dynamic>;
                                      final readBy =
                                          data['readBy']
                                              as Map<String, dynamic>? ??
                                          {};
                                      return readBy[currentUserId] != true;
                                    }).length;
                              }
                            }

                            return Stack(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.notifications,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => const NotificationsPage(),
                                      ),
                                    );
                                  },
                                ),
                                if (unreadCount > 0)
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 16,
                                        minHeight: 16,
                                      ),
                                      child: Text(
                                        '$unreadCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
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
                          // Voice listening indicator
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  _isListening
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : _micEnabled
                                      ? const Color(0xFFF3642B).withValues(alpha: 0.1)
                                      : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color:
                                    _isListening
                                        ? Colors.green
                                        : _micEnabled
                                        ? const Color(0xFFF3642B)
                                        : Colors.red,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _isListening
                                            ? (_textLang == 'en'
                                                ? (!_activated
                                                    ? "Listening... Say 'Hey Tata' to activate!"
                                                    : "Listening for your command...")
                                                : (!_activated
                                                    ? "Nakikinig... Sabihin mo 'Hey Tata' para mag-activate!"
                                                    : "Nakikinig sa utos mo..."))
                                            : (_textLang == 'en'
                                                ? _micEnabled
                                                    ? "Voice assistant ready."
                                                    : "Microphone disabled"
                                                : _micEnabled
                                                ? "Handa na ang voice assistant."
                                                : "Naka-disable ang microphone"),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color:
                                              _isListening
                                                  ? Colors.green
                                                  : _micEnabled
                                                  ? const Color(0xFFF3642B)
                                                  : Colors.red[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (_isSpeaking)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Text(
                                            _textLang == 'en'
                                                ? "Speaking..."
                                                : "Nagsasalita...",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.orange[600],
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // ✅ Simple mic toggle button
                                IconButton(
                                  onPressed: () {
                                    if (_micEnabled) {
                                      // Disable mic
                                      _speech.stop();
                                      setState(() {
                                        _micEnabled = false;
                                        _isListening = false;
                                        _manualStop = true;
                                      });
                                    } else {
                                      // Enable mic
                                      setState(() {
                                        _micEnabled = true;
                                        _manualStop = false;
                                      });
                                      _startListening();
                                    }
                                  },
                                  icon: Icon(
                                    _isListening ? Icons.mic : Icons.mic_off,
                                    color:
                                        _isListening
                                            ? Colors.green // Green when listening
                                            : _micEnabled
                                            ? const Color(0xFFF3642B) // Orange when enabled
                                            : Colors.red, // Red when disabled
                                  ),
                                  tooltip:
                                      _textLang == 'en'
                                          ? (_micEnabled
                                              ? "Disable microphone"
                                              : "Enable microphone")
                                          : (_micEnabled
                                              ? "I-disable ang microphone"
                                              : "I-enable ang microphone"),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Category Filter Buttons
                          SizedBox(
                            height: 45,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              itemCount: categories.length,
                              itemBuilder: (context, index) {
                                final category = categories[index];
                                final isSelected = selectedCategory == category;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: FilterChip(
                                    selected: isSelected,
                                    onSelected: (_) => filterByCategory(category),
                                    avatar: Icon(
                                      getCategoryIcon(category),
                                      size: 18,
                                      color: isSelected ? Colors.white : const Color(0xFFF3642B),
                                    ),
                                    label: Text(
                                      category,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                        color: isSelected ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    backgroundColor: Colors.grey[100],
                                    selectedColor: const Color(0xFFF3642B),
                                    showCheckmark: false,
                                    elevation: isSelected ? 4 : 2,
                                    pressElevation: 6,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: BorderSide(
                                        color: isSelected ? const Color(0xFFF3642B) : Colors.grey[300]!,
                                        width: 1,
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _textLang == 'en'
                                ? "Popular Recipes"
                                : "Mga Sikat na Resipe",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (filteredRecipes.isEmpty)
                            Text(
                              _textLang == 'en'
                                  ? 'No recipes available.'
                                  : 'Walang available na resipe.',
                            )
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
                                                  source: dish.source,
                                                  rating: dish.rating,
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
                                        source: dish.source,
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
  final String source;

  const RecipeCard({
    super.key,
    required this.image,
    required this.title,
    required this.duration,
    required this.rating,
    required this.source,
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
                    const Icon(Icons.star, color: Color(0xFFF3642B), size: 16),
                    const SizedBox(width: 5),
                    Text(rating.toStringAsFixed(1)),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (source.isNotEmpty)
                      Text(
                        source,
                        style: TextStyle(
                          fontSize: 13,
                          // fontStyle: FontStyle.italic,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
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
