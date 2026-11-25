import 'package:flutter/material.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:lms/features/voice_assistant/voice_destinations.dart';

/// A command assistant, deliberately separate from any future AI tutor.
/// It only acts on explicit, local navigation requests and never sends audio
/// or student content to the server. An AI doubt-solving provider can be
/// introduced later behind this presentation boundary.
class VoiceAssistantSheet extends StatefulWidget {
  const VoiceAssistantSheet({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  State<VoiceAssistantSheet> createState() => _VoiceAssistantSheetState();
}

class _VoiceAssistantSheetState extends State<VoiceAssistantSheet> {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool _listening = false;
  String _heard = '';
  String _message = 'Tap the microphone and say a command.';

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  Future<void> _startListening() async {
    final ready =
        _ready ||
        await _speech.initialize(
          onStatus: (status) {
            if (mounted && status == 'done') {
              setState(() => _listening = false);
            }
          },
          onError: (_) {
            if (mounted) {
              setState(() {
                _listening = false;
                _message = 'I could not hear that. Please try again.';
              });
            }
          },
        );
    if (!ready) {
      if (mounted) {
        setState(
          () => _message = 'Microphone or speech recognition is not available.',
        );
      }
      return;
    }
    setState(() {
      _ready = true;
      _listening = true;
      _heard = '';
      _message = 'Listening… say “open practice” or “show attendance”.';
    });
    await _speech.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 8),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
      ),
    );
  }

  Future<void> _onResult(SpeechRecognitionResult result) async {
    final words = result.recognizedWords;
    if (mounted) {
      setState(() => _heard = words);
    }
    if (result.finalResult && words.trim().isNotEmpty) {
      await _speech.stop();
      if (mounted) {
        setState(() => _listening = false);
      }
      await _runCommand(words);
    }
  }

  Future<void> _runCommand(String words) async {
    final match = matchVoiceDestination(words);
    if (match == null) {
      if (mounted) {
        setState(
          () => _message =
              'I can open Home, Practice, Study, Progress, Profile, Schedule, Attendance, or Fees.',
        );
      }
      await _tts.speak(
        'I can open Home, Practice, Study, Progress, Profile, Schedule, Attendance, or Fees.',
      );
      return;
    }
    final dest = match.value;
    // Capture before the sheet is popped; routes are pushed after the pop.
    final navigator = Navigator.of(context);
    if (dest.tabIndex != null) widget.onNavigate(dest.tabIndex!);
    final response = 'Opening ${match.key}.';
    if (mounted) {
      setState(() => _message = response);
    }
    await _tts.speak(response);
    if (mounted) {
      navigator.pop();
      final route = dest.routeName;
      if (route != null) navigator.pushNamed(route);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 18),
          Icon(
            Icons.record_voice_over_rounded,
            color: AppTheme.ink(context),
            size: 34,
          ),
          const SizedBox(height: 10),
          const Text(
            'Prepzo Voice Assistant',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            _message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          if (_heard.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                '“$_heard”',
                textAlign: TextAlign.center,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _listening ? () => _speech.stop() : _startListening,
            icon: Icon(_listening ? Icons.stop_rounded : Icons.mic_rounded),
            label: Text(_listening ? 'Stop listening' : 'Speak a command'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              minimumSize: const Size.fromHeight(50),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Try: “Open practice”, “Show timetable”, or “Open attendance”.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.inkSoft(context)),
          ),
        ],
      ),
    ),
  );
}
