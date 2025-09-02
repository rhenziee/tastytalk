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
  final List<Map<String, dynamic>> ingredients;
  final List<String> procedures;
  final String duration;
  final String language;
  final String source; // ✅ New: Add source parameter

  const MenuContentPage({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.ingredients,
    required this.procedures,
    required this.duration,
    required this.language,
    required this.source, // ✅ New: Add source parameter
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

  String _getTranslatedIngredientName(String originalOrSubstitute) {
    final originalNames =
        widget.ingredients.map((e) => e['name'].toString()).toList();
    final index = originalNames.indexOf(originalOrSubstitute);
    if (index != -1 && index < translatedIngredients.length) {
      return translatedIngredients[index];
    }

    // If not found in original, check if substitute matches original ingredient
    final originalIndex = originalNames.indexWhere(
      (name) => _ingredientSubstitutions[name] == originalOrSubstitute,
    );
    if (originalIndex != -1 && originalIndex < translatedIngredients.length) {
      return translatedIngredients[originalIndex];
    }

    return originalOrSubstitute;
  }

  final Map<String, String> _ingredientSubstitutions = {};
  late final List<Map<String, dynamic>> _ingredientData;

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

  // ✅ New: Checkbox state management for ingredients
  final Set<int> _checkedIngredients = {};

  // ✅ New: Toggle ingredient checkbox
  void _toggleIngredientCheck(int index) {
    setState(() {
      if (_checkedIngredients.contains(index)) {
        _checkedIngredients.remove(index);
      } else {
        _checkedIngredients.add(index);
      }
    });
  }

  // Add timer cleanup mechanism
  void _cleanupCurrentTimer() {
    if (_dialogIsOpen) {
      _dialogIsOpen = false;
      // Force close any open dialogs
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _language = widget.language.toLowerCase().contains('fil') ? 'fil' : 'en';

    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();

    _flutterTts.setLanguage(_language == 'en' ? 'en-US' : 'fil-PH');
    _flutterTts.awaitSpeakCompletion(true);

    // Initialize ingredient data immediately
    _ingredientData = widget.ingredients;

    // Initialize speech recognition with proper error handling and retry
    _initializeSpeech();
  }

  void _initializeSpeech() {
    _speech
        .initialize(
          onStatus: (status) {
            debugPrint('Speech status: $status');
          },
          onError: (error) {
            debugPrint('Speech error: $error');
            // ✅ Better error handling with longer delay and retry limit
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) _initializeSpeech();
            });
          },
        )
        .then((_) {
          // Only proceed with initialization after speech is ready
          if (mounted) {
            if (_language == 'fil') {
              final ingredientNames =
                  widget.ingredients
                      .map((e) => e['name'].toString())
                      .toList(); // ✅ extract names only
              _translateList(ingredientNames).then((translated) {
                if (mounted) setState(() => translatedIngredients = translated);
              });

              _translateList(widget.procedures).then((translated) {
                if (mounted) setState(() => translatedProcedures = translated);
              });
            }

            // ✅ Add delay before starting to ensure everything is ready
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Future.delayed(const Duration(milliseconds: 1000), () {
                if (mounted) _askStartCooking();
              });
            });
          }
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
      listenFor: const Duration(seconds: 30), // ✅ Add timeout
      pauseFor: const Duration(seconds: 3), // ✅ Add pause
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
            if (mounted) Navigator.pop(context, true);
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

          // ✅ Add delay before retrying to prevent rapid restarts
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (mounted && !_waitingForResponse) {
              _askUntilAnswered(
                question: question,
                validCommands: validCommands,
                onRecognized: onRecognized,
              );
            }
          });
        }
      },
    );

    // ✅ Better timeout handling with longer duration
    await Future.delayed(const Duration(seconds: 10));
    if (_waitingForResponse && questionId == _currentQuestionId) {
      _speech.stop();
      _isListening = false;
      _waitingForResponse = false;
      if (mounted) setState(() {});

      // ✅ Add delay before retrying to prevent rapid restarts
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted && !_waitingForResponse) {
          _askUntilAnswered(
            question: question,
            validCommands: validCommands,
            onRecognized: onRecognized,
          );
        }
      });
    }
  }

  // ✅ Called once when page opens
  void _askStartCooking() {
    _stateStep = 0;
    // No speaking yet — just wait for wake word
    _waitForHeyTata();
  }

  void _waitForHeyTata() async {
    _isListening = true;
    if (mounted) setState(() {});

    // ✅ Better retry logic with longer delay
    if (!_speech.isAvailable) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _isListening) _waitForHeyTata();
      });
      return;
    }

    await _speech.listen(
      localeId: 'en-US', // Wake word always in English
      onResult: (res) async {
        final result = res.recognizedWords.toLowerCase();
        debugPrint("Wake word check: $result");

        if (result.contains("hey tata") ||
            result.contains("hi tata") ||
            result.contains("hello tata")) {
          // ✅ Wake word detected → stop listening
          _isListening = false;
          await _speech.stop();
          if (mounted) setState(() {});

          // Now ask if they want to start cooking
          _askIfWantToStartCooking();
        }
      },
    );

    // ✅ Improved: Better restart logic with longer delays
    _speech.statusListener = (status) {
      debugPrint("Speech status: $status");
      if (status == "notListening" && _isListening) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted && _isListening) _waitForHeyTata();
        });
      }
    };

    _speech.errorListener = (error) {
      debugPrint("Speech error: $error");
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _isListening) _waitForHeyTata();
      });
    };
  }

  void _askIfWantToStartCooking() {
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

  void _readNextIngredient() async {
    if (_ingredientIndex >= _ingredientData.length) {
      _stateStep = 3;
      _askProcedureStart();
      return;
    }

    final data = _ingredientData[_ingredientIndex];
    final originalName = data['name'];
    final substitute = _ingredientSubstitutions[originalName] ?? originalName;
    final quantity = data['quantity']?.toString() ?? '';
    final unit = data['unit']?.toString() ?? '';
    final isTagalog = _language == 'fil';
    final displayName =
        isTagalog ? _getTranslatedIngredientName(substitute) : substitute;

    final text =
        (quantity.isEmpty && unit.isEmpty)
            ? displayName
            : "${quantity.isNotEmpty ? quantity : ''} ${unit.isNotEmpty ? unit : ''} $displayName"
                .trim();

    final validOk =
        _language == 'en'
            ? ['okay', 'ok', 'alright', 'yes', 'sure']
            : ['sige', 'oo', 'ayos', 'pwede'];
    final repeat = _language == 'en' ? 'again' : 'ulit';
    final noHave = _language == 'en' ? "i don't have that" : "wala ako niyan";

    _askUntilAnswered(
      question: text,
      validCommands: [...validOk, repeat, noHave],
      onRecognized: (cmd) async {
        if (cmd.contains(repeat)) {
          _readNextIngredient();
          return;
        }

        if (cmd.contains(noHave)) {
          final subs =
              (data['substitutes'] as List<dynamic>?)
                  ?.whereType<String>()
                  .toList() ??
              [];

          if (subs.isEmpty) {
            await _speak(
              _language == 'en'
                  ? "Sorry, no alternatives available."
                  : "Pasensya, walang alternatibo.",
            );
            _readNextIngredient();
            return;
          }

          await _speak(
            _language == 'en'
                ? "Here are the alternatives: ${subs.join(', ')}. Which one will you use?"
                : "Narito ang mga alternatibo: ${subs.join(', ')}. Alin ang gagamitin mo?",
          );

          _askUntilAnswered(
            question:
                _language == 'en'
                    ? "Please say your chosen alternative."
                    : "Sabihin ang napiling alternatibo.",
            validCommands: subs.map((e) => e.toLowerCase()).toList(),
            onRecognized: (selected) {
              final selectedWords = selected.toLowerCase().split(
                RegExp(r'\s+'),
              );

              final chosen = subs.firstWhere(
                (s) => selectedWords.contains(s.toLowerCase()),
                orElse: () {
                  return subs.firstWhere(
                    (s) => selected.toLowerCase().contains(s.toLowerCase()),
                    orElse: () => subs.first,
                  );
                },
              );

              _ingredientSubstitutions[originalName] = chosen;

              // ✅ Mark current ingredient as checked when a substitute is chosen
              setState(() {
                _checkedIngredients.add(_ingredientIndex);
              });

              _ingredientIndex++;
              _readNextIngredient();
            },
          );
        } else {
          // ✅ User said OK → mark current ingredient as checked
          setState(() {
            _checkedIngredients.add(_ingredientIndex);
          });

          _ingredientIndex++;
          _readNextIngredient();
        }
      },
    );
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
        // First read the step, then start timer
        _speak(prompt).then((_) {
          // Clean up any existing timer before starting a new one
          _cleanupCurrentTimer();
          _startTimerWithVoiceInterrupt(duration, () {
            // Remove the redundant check since _stepCompleted is already managed properly
            _stepCompleted = true;
            _procedureIndex++;
            _readNextProcedure();
          });
        });
      } else {
        final back1 = _language == 'en' ? 'go back' : 'bumalik';
        final back2 = _language == 'en' ? 'back to step' : 'ibalik sa hakbang';

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
                      recipeImageUrl: widget.imageUrl,
                      originalIngredients: widget.ingredients,
                      originalProcedures: widget.procedures,
                      ingredientSubstitutions: _ingredientSubstitutions,
                      modifiedProcedures: _getProcedures(),
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

  void _startTimerWithVoiceInterrupt(Duration duration, VoidCallback onDone) {
    int remainingSeconds = duration.inSeconds;
    int lastAnnouncedSeconds = 0;
    Timer? countdown;

    bool stoppedByVoice = false;
    bool hasCancelled = false;
    bool isCompleted = false; // Add flag to prevent multiple completions

    late StateSetter dialogSetState;
    late BuildContext dialogContext;

    /* ---------- Helper functions ---------- */

    // ✅ Improved: Better speech handling with debouncing
    void startListening() {
      if (!_speech.isAvailable ||
          _speech.isListening ||
          stoppedByVoice ||
          hasCancelled ||
          isCompleted) {
        return;
      }

      // Additional check to ensure speech is fully initialized
      if (!_speech.isAvailable) {
        debugPrint('Speech recognition not available yet');
        return;
      }

      // ✅ Add delay to prevent rapid restarts
      Future.delayed(const Duration(milliseconds: 500), () {
        if (stoppedByVoice || hasCancelled || isCompleted || !mounted) return;

        _speech.listen(
          localeId: _language == 'fil' ? 'fil-PH' : 'en-US',
          onResult: (res) async {
            if (stoppedByVoice || hasCancelled || isCompleted) return;

            final spoken = res.recognizedWords.toLowerCase();
            if (spoken.contains('pwede na') || spoken.contains("it's ready")) {
              if (isCompleted) return; // Prevent multiple completions

              stoppedByVoice = true;
              isCompleted = true;
              countdown?.cancel();

              await _speech.stop();

              // don't use dialogContext across async gap without a mounted check
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

              // Ensure we move to the next step immediately
              if (!_stepCompleted) {
                _stepCompleted = true;
                // Call onDone to trigger the next step
                onDone();
              }
            }
          },
          listenFor: const Duration(seconds: 30), // ✅ Shorter listen time
          pauseFor: const Duration(seconds: 3), // ✅ Longer pause
        );
      });
    }

    // ✅ Improved: Better speech restart with proper delays
    Future<void> speakAndRestartMic(String message) async {
      if (stoppedByVoice || hasCancelled || isCompleted) return;

      await _speech.stop();
      await _speak(message);

      // ✅ Add delay before restarting mic to prevent conflicts
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!stoppedByVoice && !hasCancelled && !isCompleted && mounted) {
          startListening();
        }
      });
    }

    /* ---------- Build and show dialog ---------- */

    _dialogIsOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogCtx) {
        dialogContext = dialogCtx;

        countdown = Timer.periodic(const Duration(seconds: 1), (timer) async {
          if (hasCancelled || isCompleted) {
            timer.cancel();
            return;
          }

          if (remainingSeconds <= 0) {
            timer.cancel();
            if (!stoppedByVoice &&
                !isCompleted &&
                mounted &&
                dialogContext.mounted &&
                _dialogIsOpen &&
                Navigator.of(dialogContext).canPop()) {
              isCompleted = true;
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
                lastAnnouncedSeconds != remainingSeconds &&
                !stoppedByVoice &&
                !isCompleted) {
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
                    if (hasCancelled || isCompleted) return;
                    hasCancelled = true;
                    isCompleted = true;

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

  List<String> _getIngredients() {
    return _ingredientData.map((data) {
      final name = _ingredientSubstitutions[data['name']] ?? data['name'];
      final quantity = data['quantity']?.toString() ?? '';
      final unit = data['unit']?.toString() ?? '';

      String result = '';
      if (quantity.isNotEmpty || unit.isNotEmpty) {
        result +=
            '${quantity.isNotEmpty ? quantity : ''} ${unit.isNotEmpty ? unit : ''} ';
      }
      result += name;
      return result.trim();
    }).toList();
  }

  List<String> _getProcedures() {
    final list = _language == 'en' ? widget.procedures : translatedProcedures;
    return list.map((step) {
      String updatedStep = step;
      _ingredientSubstitutions.forEach((original, substitute) {
        updatedStep = updatedStep.replaceAll(original, substitute);
      });
      return updatedStep;
    }).toList();
  }

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
      final ingredientNames =
          widget.ingredients.map((e) => e['name'].toString()).toList();
      _translateList(ingredientNames).then((translated) {
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
        'ingredients': widget.ingredients,
        'procedures': widget.procedures,
        'ingredientSubstitutions': _ingredientSubstitutions,
        'modifiedProcedures': _getProcedures(),
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
                        child: Stack(
                          children: [
                            Image.network(
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
                            // ✅ Subtle gradient overlay for better text readability
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.3),
                                    ],
                                    stops: const [0.7, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Dish name
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                widget.title,
                                style: const TextStyle(
                                  fontSize: 22,
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
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Source
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.source,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      widget.source,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
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
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    alignment: WrapAlignment.start,
                    spacing: 16,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.schedule, color: Colors.orange),
                          const SizedBox(width: 5),
                          Text(widget.duration),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.star, color: Colors.amber),
                          SizedBox(width: 5),
                          Text("4.5"),
                        ],
                      ),
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _language == 'en' ? "Ingredients:" : "Mga Sangkap:",
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // ✅ Progress indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_checkedIngredients.length}/${ingredientsList.length}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[700],
                              ),
                            ),
                            if (_checkedIngredients.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _checkedIngredients.clear();
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.refresh,
                                    size: 16,
                                    color: Colors.red[600],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ...ingredientsList.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 6,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color:
                            _checkedIngredients.contains(entry.key)
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              _checkedIngredients.contains(entry.key)
                                  ? Colors.green
                                  : Colors.grey.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // ✅ Interactive checkbox
                            GestureDetector(
                              onTap: () => _toggleIngredientCheck(entry.key),
                              child: Icon(
                                _checkedIngredients.contains(entry.key)
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                size: 24,
                                color:
                                    _checkedIngredients.contains(entry.key)
                                        ? Colors.green
                                        : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      _checkedIngredients.contains(entry.key)
                                          ? Colors.green[700]
                                          : Colors.black87,
                                  decoration:
                                      _checkedIngredients.contains(entry.key)
                                          ? TextDecoration.none
                                          : TextDecoration.none,
                                ),
                              ),
                            ),
                            // ✅ Check indicator
                            if (_checkedIngredients.contains(entry.key))
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  '✓',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
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
                      vertical: 8,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: Text(
                                  '${entry.key + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.4,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
