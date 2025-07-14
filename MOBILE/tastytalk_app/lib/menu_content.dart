// [All necessary imports remain unchanged]
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
  final String language;

  const MenuContentPage({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.ingredients,
    required this.procedures,
    required this.duration,
    required this.language,
  });

  @override
  MenuContentPageState createState() => MenuContentPageState();
}

class MenuContentPageState extends State<MenuContentPage> {
  int? _extractStepNumberFromSpeech(String text) {
    text = text.toLowerCase();

    // 1. Digit‑based (e.g., "2", "12")
    final digit = RegExp(r'\b(\d+)\b').firstMatch(text);
    if (digit != null) return int.tryParse(digit.group(1)!);

    // 2. Spelled‑out English / Tagalog (extend if needed)
    const words = {
      'one': 1,
      'two': 2,
      'three': 3,
      'four': 4,
      'five': 5,
      'six': 6,
      'seven': 7,
      'eight': 8,
      'nine': 9,
      'ten': 10,
      'isa': 1,
      'dalawa': 2,
      'tatlo': 3,
      'apat': 4,
      'lima': 5,
      'anim': 6,
      'pito': 7,
      'walo': 8,
      'siyam': 9,
      'sampu': 10,
    };

    final word = RegExp(
      r'\b(' + words.keys.join('|') + r')\b',
    ).firstMatch(text);
    if (word != null) return words[word.group(1)!];

    return null; // nothing found
  }

  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  final translator = GoogleTranslator();
  bool _dialogIsOpen = false;
  bool _stepCompleted = false;

  bool _waitingForResponse = false;
  bool _isListening = false;
  // ignore: unused_field
  int _stateStep = 0;
  int _procedureIndex = 0;
  int _ingredientIndex = 0;
  int _currentQuestionId = 0;

  String _language = 'en';
  List<String> translatedIngredients = [];
  List<String> translatedProcedures = [];

  @override
  void initState() {
    super.initState();
    _language = widget.language.toLowerCase().contains('fil') ? 'fil' : 'en';

    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();

    _flutterTts.setLanguage(_language == 'en' ? 'en-US' : 'fil-PH');
    _flutterTts.awaitSpeakCompletion(true);

    _speech.initialize();

    if (_language == 'fil') {
      _translateList(widget.ingredients).then((translated) {
        if (mounted) setState(() => translatedIngredients = translated);
      });
      _translateList(widget.procedures).then((translated) {
        if (mounted) setState(() => translatedProcedures = translated);
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _askStartCooking();
    });
  }

  Future<List<String>> _translateList(List<String> texts) async {
    final results = await Future.wait(
      texts.map((text) => translator.translate(text, to: 'tl')),
    );
    return results.map((t) => t.text).toList();
  }

  Future<void> _speak(String text) async {
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  Future<void> _askUntilAnswered({
    required String question,
    required List<String> validCommands,
    required Function(String) onRecognized,
  }) async {
    final int questionId = ++_currentQuestionId;
    _waitingForResponse = true;

    await _speak(question);

    _isListening = true;
    if (mounted) setState(() {});

    await _speech.listen(
      localeId: _language == 'fil' ? 'fil-PH' : 'en-US',
      onResult: (res) async {
        if (res.finalResult && res.recognizedWords.isNotEmpty) {
          if (questionId != _currentQuestionId) return;

          final result = res.recognizedWords.toLowerCase();

          if ((_language == 'en' &&
                  (result.contains("go back to main menu") ||
                      result.contains("main menu"))) ||
              (_language == 'fil' &&
                  (result.contains("bumalik") || result.contains("menu")))) {
            _speech.stop();
            _isListening = false;
            _waitingForResponse = false;
            if (mounted) setState(() {});
            await _speak(
              _language == 'en'
                  ? "Okay, going back to the main menu."
                  : "Sige, babalik sa main menu.",
            );
            if (mounted) Navigator.pop(context);
            return;
          }

          for (final command in validCommands) {
            if (result.contains(command)) {
              _speech.stop();
              _isListening = false;
              _waitingForResponse = false;
              if (mounted) setState(() {});
              onRecognized(result);
              return;
            }
          }

          if (questionId != _currentQuestionId) return;
          _speech.stop();
          _isListening = false;
          _waitingForResponse = false;
          if (mounted) setState(() {});
          await _askUntilAnswered(
            question: question,
            validCommands: validCommands,
            onRecognized: onRecognized,
          );
        }
      },
    );

    await Future.delayed(const Duration(seconds: 7));
    if (_waitingForResponse && questionId == _currentQuestionId) {
      _speech.stop();
      _isListening = false;
      _waitingForResponse = false;
      if (mounted) setState(() {});
      await _askUntilAnswered(
        question: question,
        validCommands: validCommands,
        onRecognized: onRecognized,
      );
    }
  }

  void _askStartCooking() {
    _stateStep = 0;
    final question =
        _language == 'en'
            ? "Do you want to start cooking ${widget.title}?"
            : "Gusto mo bang simulan ang pagluluto ng ${widget.title}?";

    final yes = _language == 'en' ? 'yes' : 'oo';
    final no = _language == 'en' ? 'no' : 'hindi';

    _askUntilAnswered(
      question: question,
      validCommands: [yes, no],
      onRecognized: (command) {
        if (command.contains(yes)) {
          _stateStep = 1;
          _askIngredientsList();
        } else {
          _speak(
            _language == 'en'
                ? "Okay, going back to the menu."
                : "Sige, babalik tayo sa menu.",
          ).then((_) {
            if (mounted) Navigator.pop(context);
          });
        }
      },
    );
  }

  void _askIngredientsList() {
    _stateStep = 1;
    final question =
        _language == 'en'
            ? "Do you want to hear the list of ingredients?"
            : "Gusto mo bang marinig ang listahan ng mga sangkap?";

    final yes = _language == 'en' ? 'yes' : 'oo';
    final no = _language == 'en' ? 'no' : 'hindi';

    _askUntilAnswered(
      question: question,
      validCommands: [yes, no],
      onRecognized: (command) {
        if (command.contains(yes)) {
          _stateStep = 2;
          _ingredientIndex = 0;
          _readNextIngredient();
        } else {
          _stateStep = 3;
          _askProcedureStart();
        }
      },
    );
  }

  void _askProcedureStart() {
    _stateStep = 3;
    final question =
        _language == 'en'
            ? "Do you want to start the procedure?"
            : "Simulan na ba ang pagluluto?";

    final yes = _language == 'en' ? 'yes' : 'oo';
    final no = _language == 'en' ? 'no' : 'hindi';

    _askUntilAnswered(
      question: question,
      validCommands: [yes, no],
      onRecognized: (command) {
        if (command.contains(yes)) {
          _stateStep = 4;
          _procedureIndex = 0;

          _readNextProcedure();
        } else {
          _resetConversation();
        }
      },
    );
  }

  void _readNextIngredient() {
    final list = _getIngredients();
    if (_ingredientIndex < list.length) {
      final item = list[_ingredientIndex];
      _ingredientIndex++;

      final okay = _language == 'en' ? 'okay' : 'sige';
      final repeat = _language == 'en' ? 'again' : 'ulit';

      _askUntilAnswered(
        question: item,
        validCommands: [okay, repeat],
        onRecognized: (cmd) {
          if (cmd.contains(repeat)) _ingredientIndex--;
          _readNextIngredient();
        },
      );
    } else {
      _stateStep = 3;
      _askProcedureStart();
    }
  }

  void _readNextProcedure() {
    final list = _getProcedures();

    if (_procedureIndex < list.length) {
      _stepCompleted = false; // reset for the new step

      final currentStepNumber = _procedureIndex + 1;
      final step = list[_procedureIndex];

      final okay = _language == 'en' ? 'okay' : 'sige';
      final repeat = _language == 'en' ? 'again' : 'ulit';

      final prompt =
          _language == 'en'
              ? "Step $currentStepNumber. $step"
              : "Hakbang $currentStepNumber. $step";

      final duration = _extractDuration(step);

      void handleCommand(String cmd) {
        cmd = cmd.toLowerCase();
        if (_stepCompleted) return; // 🛑 huwag pumasok muli

        // 1. Ulitin ang kasalukuyang hakbang
        if (cmd.contains(repeat)) {
          _readNextProcedure();
          return;
        }

        // 2. Tingnan kung may "go back" / "back" / "bumalik" / "balik"
        final hasBackKeyword =
            _language == 'en'
                ? (cmd.contains('go back') || cmd.contains('back'))
                : (cmd.contains('bumalik') || cmd.contains('balik'));

        if (hasBackKeyword) {
          final num = _extractStepNumberFromSpeech(cmd);
          if (num != null && num > 0 && num <= list.length) {
            _procedureIndex = num - 1; // 🔙 lumundag sa tamang hakbang
            _stepCompleted = true;
            _readNextProcedure();
            return;
          }
        }

        // 3. Default → susunod na hakbang
        _stepCompleted = true;
        _procedureIndex++;
        _readNextProcedure();
      }

      if (duration != null) {
        _speak(prompt).then((_) {
          _startTimerWithVoiceInterrupt(duration, () {
            _procedureIndex++;
            _readNextProcedure();
          });
        });
      } else {
        final back1 = _language == 'en' ? 'go back' : 'bumalik';
        final back2 = _language == 'en' ? 'back to step' : 'balik sa hakbang';

        _askUntilAnswered(
          question: prompt,
          validCommands: [okay, repeat, back1, back2],
          onRecognized: handleCommand,
        );
      }
    } else {
      _saveCookingHistory().then((_) {
        _speak(
          _language == 'en'
              ? "Congratulations for cooking ${widget.title}!"
              : "Binabati kita sa pagluluto ng ${widget.title}!",
        ).then((_) {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => CongratulationsPage(
                      recipeTitle: widget.title,
                      language: _language,
                    ),
              ),
            );
          }
        });
      });
    }
  }

  Duration? _extractDuration(String text) {
    final regex = RegExp(
      r'((\d+)\s+)?(\d+\/\d+|\d+(\.\d+)?)\s*(hours?|oras|minutes?|mins?|minuto|seconds?|segundo|segundos)',
      caseSensitive: false,
    );

    int totalSeconds = 0;

    for (final match in regex.allMatches(text)) {
      String? wholeStr = match.group(2); // optional whole number like 1
      String valueStr = match.group(3)!; // e.g., 1.5 or 3/4
      String unit = match.group(5)!.toLowerCase();

      double value = 0;

      if (valueStr.contains('/')) {
        // Parse fraction like 3/4
        final parts = valueStr.split('/');
        if (parts.length == 2) {
          final numerator = double.tryParse(parts[0]);
          final denominator = double.tryParse(parts[1]);
          if (numerator != null && denominator != null && denominator != 0) {
            value = numerator / denominator;
          }
        }
      } else {
        value = double.tryParse(valueStr) ?? 0;
      }

      if (wholeStr != null) {
        value += double.tryParse(wholeStr) ?? 0;
      }

      if (unit.contains('hour') || unit.contains('oras')) {
        totalSeconds += (value * 3600).round();
      } else if (unit.contains('min')) {
        totalSeconds += (value * 60).round();
      } else if (unit.contains('second') || unit.contains('segundo')) {
        totalSeconds += value.round();
      }
    }

    return totalSeconds > 0 ? Duration(seconds: totalSeconds) : null;
  }

  /// Starts a countdown timer that can be interrupted by voice or by
  /// pressing **Cancel**.
  void _startTimerWithVoiceInterrupt(Duration duration, VoidCallback onDone) {
    int remainingSeconds = duration.inSeconds;
    int lastAnnouncedSeconds = 0;
    Timer? countdown;

    bool stoppedByVoice = false;
    bool hasCancelled = false; // ← renamed (no leading “_”)

    late StateSetter dialogSetState;
    late BuildContext dialogContext;

    /* ---------- Helper functions ---------- */

    // Renamed (no leading “_”)
    void startListening() {
      if (!_speech.isAvailable ||
          _speech.isListening ||
          stoppedByVoice ||
          hasCancelled) {
        return; // 🔒 wrapped in braces to satisfy curly_braces_in_flow_control_structures
      }

      _speech.listen(
        localeId: _language == 'fil' ? 'fil-PH' : 'en-US',
        onResult: (res) async {
          final spoken = res.recognizedWords.toLowerCase();
          if (spoken.contains('pwede na') || spoken.contains("it's ready")) {
            stoppedByVoice = true;
            countdown?.cancel();

            await _speech.stop();

            // don’t use dialogContext across async gap without a mounted check
            if (mounted &&
                dialogContext.mounted && // ✅ context‑specific check
                _dialogIsOpen &&
                Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop();
              _dialogIsOpen = false;
            }

            await _speak(
              _language == 'en'
                  ? 'Okay, moving on to the next step.'
                  : 'Sige, susunod na hakbang na tayo.',
            );
            if (!_stepCompleted) {
              _stepCompleted = true;
              onDone();
            }
          }
        },
      );
    }

    // Renamed (no leading “_”)
    Future<void> speakAndRestartMic(String message) async {
      await _speech.stop();
      await _speak(message);
      startListening();
    }

    /* ---------- Build and show dialog ---------- */

    _dialogIsOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogCtx) {
        dialogContext = dialogCtx;

        countdown = Timer.periodic(const Duration(seconds: 1), (timer) async {
          if (hasCancelled) {
            timer.cancel();
            return;
          }

          if (remainingSeconds <= 0) {
            timer.cancel();
            if (!stoppedByVoice &&
                mounted &&
                dialogContext.mounted &&
                _dialogIsOpen &&
                Navigator.of(dialogContext).canPop()) {
              await _speech.stop();
              if (!mounted || !dialogContext.mounted) return; // 🆕 guard

              if (_dialogIsOpen && Navigator.of(dialogContext).canPop()) {
                Navigator.of(dialogContext).pop();
                _dialogIsOpen = false;
              }

              await _speak(
                _language == 'en' ? 'Time is up!' : 'Tapos na ang oras!',
              );
              if (!_stepCompleted) {
                _stepCompleted = true;
                onDone();
              }
            }
          } else {
            remainingSeconds--;
            dialogSetState(() {}); // update timer display

            if ((lastAnnouncedSeconds == 0 || remainingSeconds % 10 == 0) &&
                remainingSeconds != duration.inSeconds &&
                lastAnnouncedSeconds != remainingSeconds) {
              lastAnnouncedSeconds = remainingSeconds;

              final minutes = remainingSeconds ~/ 60;
              final seconds = remainingSeconds % 60;

              final msg =
                  _language == 'en'
                      ? 'Remaining time: $minutes minutes and $seconds seconds.'
                      : 'Natitirang oras: $minutes minuto at $seconds segundo.';

              await speakAndRestartMic(msg);
            }
          }
        });

        startListening();

        return StatefulBuilder(
          builder: (context, setState) {
            dialogSetState = setState;
            final minutes = remainingSeconds ~/ 60;
            final seconds = remainingSeconds % 60;

            return AlertDialog(
              title: Text(
                _language == 'en' ? 'Timer Running' : 'Tumatakbo ang Oras',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _language == 'en' ? 'Remaining time:' : 'Natitirang oras:',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${minutes.toString().padLeft(2, '0')}:'
                    '${seconds.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    if (hasCancelled) return;
                    hasCancelled = true;

                    stoppedByVoice = true;
                    countdown?.cancel();
                    await _speech.stop();

                    if (_dialogIsOpen &&
                        dialogContext.mounted &&
                        Navigator.of(dialogContext).canPop()) {
                      Navigator.of(dialogContext).pop();
                      _dialogIsOpen = false;
                    }

                    await _speak(
                      _language == 'en'
                          ? 'Timer cancelled.'
                          : 'Kinansela ang oras.',
                    );
                    if (!_stepCompleted) {
                      _stepCompleted = true;
                      onDone();
                    }
                  },
                  child: Text(_language == 'en' ? 'Cancel' : 'Kanselahin'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<String> _getIngredients() =>
      _language == 'en' ? widget.ingredients : translatedIngredients;

  List<String> _getProcedures() =>
      _language == 'en' ? widget.procedures : translatedProcedures;

  void _resetConversation() {
    _stateStep = 0;
    _procedureIndex = 0;
    _ingredientIndex = 0;
    _waitingForResponse = false;
    _speak(
      _language == 'en'
          ? "Voice assistance ended."
          : "Tapos na ang tulong ng boses.",
    );
  }

  void _changeLanguage(String lang) {
    setState(() {
      _language = lang;
      _flutterTts.setLanguage(_language == 'en' ? 'en-US' : 'fil-PH');
    });

    if (_language == 'fil') {
      _translateList(widget.ingredients).then((translated) {
        if (mounted) setState(() => translatedIngredients = translated);
      });
      _translateList(widget.procedures).then((translated) {
        if (mounted) setState(() => translatedProcedures = translated);
      });
    }
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
    _dialogIsOpen = false;
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
                // image and title
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
                  child: Row(
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
                      const SizedBox(width: 10),
                      DropdownButton<String>(
                        value: _language,
                        icon: const Icon(Icons.language),
                        items: const [
                          DropdownMenuItem(value: 'en', child: Text('English')),
                          DropdownMenuItem(
                            value: 'fil',
                            child: Text('Tagalog'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) _changeLanguage(value);
                        },
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
