// 👇 Your imports remain unchanged
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
                !_isProcessingCommand) {
              _restartTimer?.cancel();
              _restartTimer = Timer(const Duration(milliseconds: 800), () {
                if (mounted && !_isSpeaking && !_navigating && _micEnabled) {
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
          !_isProcessingCommand) {
        debugPrint("🔄 Restarting listening due to inactivity...");
        _startListening();
      }
    });
  }

  Future<void> _startListening() async {
    if (_navigating || _isSpeaking || !_micEnabled || _isProcessingCommand) {
      debugPrint("🚫 Cannot start listening: navigating=$_navigating, speaking=$_isSpeaking, micEnabled=$_micEnabled, processing=$_isProcessingCommand");
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
          debugPrint("🎤 Speech result: ${result.recognizedWords} (final: ${result.finalResult})");
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

  // ✅ New: Toggle microphone function
  void _toggleMicrophone() {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
    } else if (_micEnabled && !_isSpeaking && !_navigating) {
      _startListening();
    }
  }

  // ✅ New: Enable/disable microphone
  void _setMicrophoneEnabled(bool enabled) {
    setState(() => _micEnabled = enabled);
    if (!enabled) {
      _speech.stop();
      setState(() => _isListening = false);
    } else if (!_isSpeaking && !_navigating) {
      Future.delayed(const Duration(milliseconds: 500), _startListening);
    }
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
                          // Voice listening indicator
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color:
                                  _isListening
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : _micEnabled
                                      ? Colors.blue.withValues(alpha: 0.1)
                                      : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color:
                                    _isListening
                                        ? Colors.green
                                        : _micEnabled
                                        ? Colors.blue
                                        : Colors.red,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                // ✅ Animated microphone icon
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: Icon(
                                    _isListening
                                        ? Icons.mic
                                        : _micEnabled
                                        ? Icons.mic_off
                                        : Icons.mic_off,
                                    key: ValueKey(_isListening),
                                    color:
                                        _isListening
                                            ? Colors.green
                                            : _micEnabled
                                            ? Colors.blue
                                            : Colors.red,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
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
                                                  ? Colors.blue[600]
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
                                // ✅ Toggle microphone button
                                IconButton(
                                  onPressed:
                                      _isListening || _isSpeaking
                                          ? null
                                          : _toggleMicrophone,
                                  icon: Icon(
                                    _isListening ? Icons.mic : Icons.mic,
                                    color:
                                        _isListening
                                            ? Colors.green
                                            : _micEnabled
                                            ? Colors.blue
                                            : Colors.grey,
                                  ),
                                  tooltip:
                                      _textLang == 'en'
                                          ? "Toggle microphone"
                                          : "I-toggle ang microphone",
                                ),
                                const SizedBox(width: 8),
                                // ✅ Enable/disable microphone button
                                IconButton(
                                  onPressed:
                                      _isListening || _isSpeaking
                                          ? null
                                          : () => _setMicrophoneEnabled(
                                            !_micEnabled,
                                          ),
                                  icon: Icon(
                                    _micEnabled
                                        ? Icons.block
                                        : Icons.check_circle,
                                    color:
                                        _micEnabled ? Colors.red : Colors.green,
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
                                const SizedBox(width: 8),
                                // ✅ Test voice button
                                IconButton(
                                  onPressed:
                                      _isListening || _isSpeaking
                                          ? null
                                          : () => _greetUser(),
                                  icon: const Icon(
                                    Icons.volume_up,
                                    color: Colors.orange,
                                  ),
                                  tooltip:
                                      _textLang == 'en'
                                          ? "Test voice"
                                          : "I-test ang boses",
                                ),
                              ],
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
                    const Icon(Icons.star, color: Colors.orange, size: 16),
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
