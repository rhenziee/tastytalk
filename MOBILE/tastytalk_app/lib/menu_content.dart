import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:translator/translator.dart';

import 'congratulationspage.dart';

class MenuContentPage extends StatefulWidget {
  final String title;
  final String imageUrl;
  final List<String> ingredients;
  final List<String> procedures;
  final String duration;

  const MenuContentPage({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.ingredients,
    required this.procedures,
    required this.duration,
  });

  @override
  MenuContentPageState createState() => MenuContentPageState();
}

class MenuContentPageState extends State<MenuContentPage> {
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  final translator = GoogleTranslator();

  bool _isListening = false;
  bool _waitingForResponse = false;
  String _lastWords = '';
  int _stateStep = 0;
  int _procedureIndex = 0;
  int _ingredientIndex = 0;
  bool _isSpeaking = false;

  String _language = 'en';
  List<String> translatedIngredients = [];
  List<String> translatedProcedures = [];

  Completer<void>? _speechCompleter;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _flutterTts.setLanguage("en-US");

    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
      if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
        _speechCompleter!.complete();
      }
      if (_waitingForResponse && !_isSpeaking && !_isListening) {
        Future.delayed(const Duration(milliseconds: 500), _startListening);
      }
    });
  }

  void _changeLanguage(String lang) async {
    setState(() => _language = lang);
    await _flutterTts.setLanguage(lang == 'en' ? 'en-US' : 'fil-PH');

    if (lang == 'fil') {
      // Translate only once
      if (translatedIngredients.isEmpty || translatedProcedures.isEmpty) {
        translatedIngredients = await _translateList(widget.ingredients);
        translatedProcedures = await _translateList(widget.procedures);
        setState(() {}); // trigger UI rebuild
      }
    }
  }

  Future<List<String>> _translateList(List<String> texts) async {
    final results = await Future.wait(
      texts.map((text) => translator.translate(text, to: 'tl')),
    );
    return results.map((t) => t.text).toList();
  }

  Future<void> _startListening() async {
    if (_isSpeaking) return;
    bool available = await _speech.initialize(
      onStatus: (val) async {
        if (val == "done" || val == "notListening") {
          setState(() => _isListening = false);
          if (_waitingForResponse && !_isSpeaking && !_isListening) {
            await Future.delayed(const Duration(milliseconds: 800));
            _startListening();
          }
        }
      },
      onError: (val) {
        print('Speech error: $val');
        setState(() => _isListening = false);
      },
    );

    if (available && !_isListening && !_isSpeaking) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            _lastWords = result.recognizedWords.toLowerCase();
            _processVoiceCommand(_lastWords);
          }
        },
        listenMode: stt.ListenMode.dictation,
        localeId: _language == 'en' ? 'en_US' : 'fil_PH',
        partialResults: true,
        cancelOnError: false,
      );
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _speak(String text, {bool expectResponse = false}) async {
    _stopListening();
    _waitingForResponse = expectResponse;
    _isSpeaking = true;
    await _flutterTts.stop();
    _speechCompleter = Completer<void>();
    await _flutterTts.speak(text);
    return _speechCompleter!.future;
  }

  void _processVoiceCommand(String command) {
    _stopListening();
    _waitingForResponse = false;

    final yes = _language == 'en' ? 'yes' : 'oo';
    final no = _language == 'en' ? 'no' : 'hindi';
    final repeat = _language == 'en' ? 'repeat' : 'ulitin';
    final nextIngredient =
        _language == 'en' ? 'next ingredient' : 'sunod na sangkap';
    final nextStep = _language == 'en' ? 'next step' : 'sunod na hakbang';
    final goBack = _language == 'en' ? 'go back' : 'bumalik';
    final okay = _language == 'en' ? 'okay' : 'sige';

    if (command.contains(yes)) {
      switch (_stateStep) {
        case 0:
          _stateStep = 1;
          _askIngredientsList();
          break;
        case 1:
          _stateStep = 2;
          _ingredientIndex = 0;
          _readNextIngredient();
          break;
        case 3:
          _stateStep = 4;
          _procedureIndex = 0;
          _readNextProcedure();
          break;
      }
    } else if (command.contains(no)) {
      switch (_stateStep) {
        case 0:
          _speak(
            _language == 'en'
                ? "Okay, we're going back to the menu."
                : "Sige, babalik tayo sa menu.",
          ).then((_) => Navigator.pop(context));
          break;
        case 1:
        case 2:
          _stateStep = 3;
          _askProcedureStart();
          break;
        case 3:
        case 4:
          _resetConversation();
          break;
      }
    } else if (command.contains(repeat)) {
      _repromptCurrentStep();
    } else if (command.contains(nextIngredient)) {
      if (_stateStep == 2) _readNextIngredient();
    } else if (command.contains(nextStep)) {
      if (_stateStep == 4) _readNextProcedure();
    } else if (command.contains(goBack)) {
      if (_stateStep == 2 && _ingredientIndex > 1) {
        _ingredientIndex--;
        final ing = _getIngredients()[_ingredientIndex - 1];
        _speak(ing, expectResponse: true);
      } else if (_stateStep == 4 && _procedureIndex > 1) {
        _procedureIndex--;
        final step = _getProcedures()[_procedureIndex - 1];
        _speak(
          _language == 'en'
              ? "Step $_procedureIndex. $step"
              : "Hakbang $_procedureIndex. $step",
          expectResponse: true,
        );
      } else {
        _repromptCurrentStep();
      }
    } else if (command.contains(okay)) {
      if (_stateStep == 2)
        _readNextIngredient();
      else if (_stateStep == 4)
        _readNextProcedure();
    } else {
      _repromptCurrentStep();
    }
  }

  void _askStartCooking() {
    _stateStep = 0;
    _speak(
      _language == 'en'
          ? "Do you want to start cooking ${widget.title}?"
          : "Gusto mo bang simulan ang pagluluto ng ${widget.title}?",
      expectResponse: true,
    );
  }

  void _askIngredientsList() {
    _stateStep = 1;
    _speak(
      _language == 'en'
          ? "Do you want to hear the list of ingredients?"
          : "Gusto mo bang marinig ang listahan ng mga sangkap?",
      expectResponse: true,
    );
  }

  void _askProcedureStart() {
    _stateStep = 3;
    _speak(
      _language == 'en'
          ? "Do you want to start the procedure?"
          : "Gusto mo bang simulan ang mga hakbang?",
      expectResponse: true,
    );
  }

  void _readNextIngredient() {
    final list = _getIngredients();
    if (_ingredientIndex < list.length) {
      _speak(list[_ingredientIndex], expectResponse: true);
      _ingredientIndex++;
    } else {
      _stateStep = 3;
      _askProcedureStart();
    }
  }

  void _readNextProcedure() {
    final list = _getProcedures();
    if (_procedureIndex < list.length) {
      _speak(
        _language == 'en'
            ? "Step ${_procedureIndex + 1}. ${list[_procedureIndex]}"
            : "Hakbang ${_procedureIndex + 1}. ${list[_procedureIndex]}",
        expectResponse: true,
      );
      _procedureIndex++;
    } else {
      _saveCookingHistory().then((_) {
        _speak(
          _language == 'en'
              ? "Congratulations for cooking ${widget.title} successfully! Please enjoy your meal."
              : "Binabati kita sa matagumpay na pagluluto ng ${widget.title}! I-enjoy mo ang iyong pagkain.",
        ).then((_) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => CongratulationsPage(recipeTitle: widget.title),
            ),
          );
        });
      });
    }
  }

  List<String> _getIngredients() =>
      _language == 'en' ? widget.ingredients : translatedIngredients;

  List<String> _getProcedures() =>
      _language == 'en' ? widget.procedures : translatedProcedures;

  void _repromptCurrentStep() {
    switch (_stateStep) {
      case 0:
        _askStartCooking();
        break;
      case 1:
        _askIngredientsList();
        break;
      case 2:
        if (_ingredientIndex > 0) {
          _speak(_getIngredients()[_ingredientIndex - 1], expectResponse: true);
        }
        break;
      case 3:
        _askProcedureStart();
        break;
      case 4:
        if (_procedureIndex > 0) {
          _speak(
            _language == 'en'
                ? "Step $_procedureIndex. ${_getProcedures()[_procedureIndex - 1]}"
                : "Hakbang $_procedureIndex. ${_getProcedures()[_procedureIndex - 1]}",
            expectResponse: true,
          );
        }
        break;
    }
  }

  void _resetConversation() {
    _stateStep = 0;
    _procedureIndex = 0;
    _ingredientIndex = 0;
    _waitingForResponse = false;
    _speak(
      _language == 'en'
          ? "Voice assistance ended."
          : "Tapos na ang boses na tulong.",
    );
  }

  Future<void> _saveCookingHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final docRef =
          FirebaseFirestore.instance
              .collection('cooking_history')
              .doc(user.uid)
              .collection('recipes')
              .doc();
      await docRef.set({
        'title': widget.title,
        'imageUrl': widget.imageUrl,
        'duration': widget.duration,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ingredientsList = _getIngredients();
    final proceduresList = _getProcedures();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        alignment: Alignment.center,
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(50),
                          bottomRight: Radius.circular(50),
                        ),
                        child: Image.network(
                          widget.imageUrl,
                          width: double.infinity,
                          height: 300,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const SizedBox(
                              height: 300,
                              child: Center(
                                child: Icon(Icons.error, size: 100),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      left: 16,
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              blurRadius: 5,
                              color: Colors.black54,
                              offset: Offset(1, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.schedule, color: Colors.orange),
                          const SizedBox(width: 5),
                          Text(widget.duration),
                          const SizedBox(width: 20),
                          const Icon(Icons.star, color: Colors.amber),
                          const SizedBox(width: 5),
                          const Text("4.5"),
                          const SizedBox(width: 25),
                          ElevatedButton(
                            onPressed: () {
                              if (!_isListening) {
                                _askStartCooking();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: Text(
                              _isListening
                                  ? (_language == 'en'
                                      ? "Listening..."
                                      : "Nakikinig...")
                                  : (_language == 'en'
                                      ? "Start cooking"
                                      : "Magluto"),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          DropdownButton<String>(
                            value: _language,
                            icon: const Icon(Icons.language),
                            items: const [
                              DropdownMenuItem(
                                value: 'en',
                                child: Text('English'),
                              ),
                              DropdownMenuItem(
                                value: 'fil',
                                child: Text('Tagalog'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                _changeLanguage(value);
                              }
                            },
                          ),
                          const SizedBox(width: 10),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _language == 'en' ? "Ingredients:" : "Mga Sangkap:",
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ...ingredientsList.map(
                  (ingredient) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_box_outline_blank, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(ingredient)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _language == 'en' ? "Procedure:" : "Paraan ng Pagluluto:",
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ...proceduresList.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 6,
                    ),
                    child: Text("${entry.key + 1}. ${entry.value}"),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
