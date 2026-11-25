import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/core/config/app_config.dart';
import 'package:lms/features/exams/data/models/exams_models.dart';
import 'package:lms/features/exams/data/repositories/exams_repository.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/core/widgets/math_html_renderer.dart';
import 'package:lms/core/utils/html_cleaner.dart';
import 'package:lms/core/utils/numeric_answer_formatter.dart';
import 'package:lms/core/constants/exam_strings.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class DppPracticePlayerScreen extends StatefulWidget {
  const DppPracticePlayerScreen({super.key, required this.exam});
  final ExamModel exam;

  @override
  State<DppPracticePlayerScreen> createState() =>
      _DppPracticePlayerScreenState();
}

class _DppPracticePlayerScreenState extends State<DppPracticePlayerScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentQuestionIndex = 0;
  final Map<int, String> _answers = {};
  final Set<int> _lockedPracticeAnswers = {};
  // One controller per question so a typed value survives navigation.
  final Map<int, TextEditingController> _typedControllers = {};
  // Typed answers edited but not yet sent; flushed on a debounce and on submit.
  final Set<int> _dirtyTyped = {};
  Timer? _typedDebounce;
  final Map<int, Map<String, dynamic>> _practiceFeedback = {};
  bool _isSubmitting = false;
  bool _isCheckingAnswer = false;
  List<dynamic> _questions = [];
  List<dynamic> _backendAnswers = [];
  bool _isLoading = true;
  bool _isSubmitted = false;

  int _score = 0;
  int _totalMarks = 0;

  // Stopwatch & Per-Question Time Tracking
  Timer? _stopwatchTimer;
  int _totalTimeSpentSeconds = 0;
  final Map<String, int> _timeSpentPerQuestion = {};

  bool get _isDpp {
    final title = widget.exam.title.trimLeft().toUpperCase();
    return title.startsWith('DPP');
  }

  bool get _isInteractivePractice => !_isDpp;

  String? _extractId(dynamic idObj) {
    if (idObj == null) return null;
    if (idObj is Map) {
      if (idObj.containsKey('\$oid')) return idObj['\$oid'].toString();
      if (idObj.containsKey('_id')) return _extractId(idObj['_id']);
      if (idObj.containsKey('id')) return _extractId(idObj['id']);
    }
    final s = idObj.toString().trim();
    if (s.isEmpty || s == 'Instance of Map') return null;
    return s;
  }

  String _getQuestionId(Map question) {
    return _extractId(question['questionId']) ??
        _extractId(question['_id']) ??
        _extractId(question['id']) ??
        '';
  }

  String _getOptionId(Map opt, int index) {
    final id = _extractId(opt['_id']) ??
        _extractId(opt['id']) ??
        _extractId(opt['optionId']);
    if (id != null && id.isNotEmpty) return id;
    final text = (opt['text'] ?? opt['optionText'] ?? '').toString().trim();
    if (text.isNotEmpty) return text;
    return 'opt_$index';
  }

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  @override
  void dispose() {
    _stopwatchTimer?.cancel();
    _typedDebounce?.cancel();
    for (final c in _typedControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _startStopwatch() {
    _stopwatchTimer?.cancel();
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isSubmitted || _isLoading) return;
      setState(() {
        _totalTimeSpentSeconds++;
        if (_questions.isNotEmpty &&
            _currentQuestionIndex < _questions.length) {
          final question = _questions[_currentQuestionIndex];
          final qId = _getQuestionId(question);
          if (qId.isNotEmpty) {
            _timeSpentPerQuestion[qId] =
                (_timeSpentPerQuestion[qId] ?? 0) + 1;
          }
        }
      });
    });
  }

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  Future<void> _loadSession() async {
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    final examsRepo = context.read<ExamsRepository>();

    try {
      if (!widget.exam.id.startsWith('custom-')) {
        final sessionData = await examsRepo.getPracticeSession(
          token,
          widget.exam.id,
        );
        final List<dynamic> rawQuestions =
            sessionData['questions'] is List &&
                (sessionData['questions'] as List).isNotEmpty
            ? sessionData['questions']
            : widget.exam.questions;

        final questions = rawQuestions.map((q) {
          if (q is Map) {
            final Map<String, dynamic> qMap = Map<String, dynamic>.from(q);
            final nested = qMap['questionId'] is Map
                ? Map<String, dynamic>.from(qMap['questionId'])
                : qMap;
            return {
              ...qMap,
              'questionText':
                  nested['questionText'] ?? qMap['questionText'] ?? 'Question',
              'options': nested['options'] ?? qMap['options'] ?? [],
              'explanation':
                  nested['explanation'] ??
                  qMap['explanation'] ??
                  qMap['solution'],
              'type': nested['type'] ?? qMap['type'] ?? 'MCQ',
              'image':
                  nested['image'] ??
                  nested['imageUrl'] ??
                  qMap['image'] ??
                  qMap['imageUrl'],
            };
          }
          return q;
        }).toList();

        final List<dynamic> answers = sessionData['answers'] is List
            ? sessionData['answers']
            : [];
        final status = sessionData['status']?.toString() ?? 'IN_PROGRESS';
        final isCompleted = status == 'COMPLETED';

        int totalTime = int.tryParse(
          (sessionData['totalTimeSpentSeconds'] ?? 0).toString(),
        ) ?? 0;
        int timeSum = 0;

        for (var a in answers) {
          if (a is Map) {
            final qId = _getQuestionId(a);
            final t = int.tryParse((a['timeSpentSeconds'] ?? 0).toString()) ?? 0;
            if (qId.isNotEmpty && t > 0) {
              _timeSpentPerQuestion[qId] = t;
              timeSum += t;
            }
          }
        }

        setState(() {
          _questions = questions;
          _backendAnswers = answers;
          _isSubmitted = isCompleted;
          _score = int.tryParse((sessionData['score'] ?? 0).toString()) ?? 0;
          _totalMarks = int.tryParse((sessionData['totalMarks'] ?? 0).toString()) ?? 0;
          _totalTimeSpentSeconds = totalTime > 0 ? totalTime : timeSum;
          _isLoading = false;
        });

        for (var i = 0; i < _questions.length; i++) {
          final qId = _getQuestionId(_questions[i]);
          final savedAns = answers.firstWhere(
            (a) => _getQuestionId(a) == qId,
            orElse: () => null,
          );
          if (savedAns != null && savedAns['selectedOptionId'] != null) {
            final ansOptId = _extractId(savedAns['selectedOptionId']);
            if (ansOptId != null) {
              _answers[i] = ansOptId;
            }
          } else if (savedAns is Map) {
            // No option picked: restore a typed (integer) answer on resume.
            final typed = (savedAns['subjectiveAnswerText'] ?? '')
                .toString()
                .trim();
            if (typed.isNotEmpty) _answers[i] = typed;
          }
        }

        if (!_isSubmitted) {
          _startStopwatch();
        }
      } else {
        setState(() {
          _questions = widget.exam.questions;
          _isLoading = false;
        });
        _startStopwatch();
      }
    } catch (e) {
      setState(() {
        _questions = widget.exam.questions;
        _isLoading = false;
      });
      _startStopwatch();
    }
  }

  Future<void> _saveAnswer(
    int questionIndex,
    String answer, {
    bool typed = false,
  }) async {
    if (_isSubmitted) return;
    if (_isInteractivePractice &&
        _lockedPracticeAnswers.contains(questionIndex)) {
      return;
    }
    final String? previousAnswer = _answers[questionIndex];
    setState(() {
      _answers[questionIndex] = answer;
    });

    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    final question = _questions[questionIndex];
    final qId = _getQuestionId(question);

    if (qId.isNotEmpty &&
        !token.startsWith('mock-') &&
        !widget.exam.id.startsWith('custom-')) {
      try {
        final payload = {
          'questionId': qId,
          // Option-less (integer) questions go as free text, never as an option id.
          'selectedOptionId': typed ? null : answer,
          if (typed) 'subjectiveAnswerText': answer,
          'status': 'ANSWERED',
          'timeSpentSeconds': _timeSpentPerQuestion[qId] ?? 0,
        };
        final result = await context
            .read<ExamsRepository>()
            .savePracticeProgress(token, widget.exam.id, payload);

        if (_isInteractivePractice && mounted) {
          final data = result['data'] is Map
              ? Map<String, dynamic>.from(result['data'])
              : <String, dynamic>{};
          setState(() {
            _lockedPracticeAnswers.add(questionIndex);
            _practiceFeedback[questionIndex] = {
              'isCorrect': data['isCorrect'] == true,
              'explanation': data['explanation']?.toString() ?? '',
            };
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            if (previousAnswer != null) {
              _answers[questionIndex] = previousAnswer;
            } else {
              _answers.remove(questionIndex);
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not save your answer. Please try again.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  /// A question with no options is answered by typing a number.
  bool _isTypedQuestion(dynamic question) {
    if (question is! Map) return false;
    final opts = question['options'];
    final type = question['type']?.toString() ?? 'MCQ';
    // Mirrors the build() branch that decides between option cards and the box.
    final hasOptions = opts is List &&
        opts.isNotEmpty &&
        (type == 'MCQ' || type == 'TRUE_FALSE');
    return !hasOptions;
  }

  /// Sends typed answers that are still pending. Interactive practice sends
  /// on "Check Answer" instead (sending locks the question), so it is skipped.
  Future<void> _flushTypedAnswers() async {
    _typedDebounce?.cancel();
    if (_isInteractivePractice || _isSubmitted) return;
    final pending = _dirtyTyped.toList();
    _dirtyTyped.clear();
    for (final i in pending) {
      final v = _answers[i];
      if (v != null && v.isNotEmpty) {
        await _saveAnswer(i, v, typed: true);
      }
    }
  }

  void _onTypedChanged(int index, String raw) {
    final v = raw.trim();
    // An empty box means "not answered", so drop the key.
    setState(() {
      if (v.isEmpty) {
        _answers.remove(index);
      } else {
        _answers[index] = v;
      }
    });
    if (!_isInteractivePractice) {
      if (v.isEmpty) {
        _dirtyTyped.remove(index);
      } else {
        _dirtyTyped.add(index);
        _typedDebounce?.cancel();
        _typedDebounce = Timer(
          const Duration(milliseconds: 700),
          _flushTypedAnswers,
        );
      }
    }
  }

  Future<void> _handleCheckAnswer() async {
    final optionId = _answers[_currentQuestionIndex];
    if (optionId == null || _isCheckingAnswer) return;

    setState(() => _isCheckingAnswer = true);
    try {
      await _saveAnswer(
        _currentQuestionIndex,
        optionId,
        typed: _isTypedQuestion(_questions[_currentQuestionIndex]),
      );
    } finally {
      if (mounted) setState(() => _isCheckingAnswer = false);
    }
  }

  Future<void> _clearResponse() async {
    if (_isSubmitted) return;
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    final question = _questions[_currentQuestionIndex];
    final qId = _getQuestionId(question);

    setState(() {
      _answers.remove(_currentQuestionIndex);
      _dirtyTyped.remove(_currentQuestionIndex);
      _typedControllers[_currentQuestionIndex]?.clear();
    });

    if (qId.isNotEmpty &&
        !token.startsWith('mock-') &&
        !widget.exam.id.startsWith('custom-')) {
      try {
        final payload = {
          'questionId': qId,
          'selectedOptionId': null,
          'subjectiveAnswerText': null,
          'status': 'NOT_ANSWERED',
        };
        await context.read<ExamsRepository>().savePracticeProgress(
          token,
          widget.exam.id,
          payload,
        );
      } catch (e) {
        debugPrint('Clear response error: $e');
      }
    }
  }

  Future<void> _submitSession() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';

    try {
      await _flushTypedAnswers();
      if (!widget.exam.id.startsWith('custom-')) {
        final res = await context.read<ExamsRepository>().submitPracticeSession(
          token,
          widget.exam.id,
          {
            'totalTimeSpentSeconds': _totalTimeSpentSeconds,
            'timeSpentPerQuestion': _timeSpentPerQuestion,
          },
        );
        final data = res['data'] is Map ? res['data'] as Map : res;
        _stopwatchTimer?.cancel();
        setState(() {
          _isSubmitted = true;
          _score = int.tryParse((data['score'] ?? 0).toString()) ?? 0;
          _totalMarks = int.tryParse((data['totalMarks'] ?? 0).toString()) ?? 0;
          _backendAnswers = data['answers'] is List ? data['answers'] : [];
        });
      } else {
        _stopwatchTimer?.cancel();
        setState(() {
          _isSubmitted = true;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_isDpp ? "DPP" : "Practice session"} submitted successfully!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error submitting session: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handlePauseAndExit(bool isSubmitted) async {
    if (isSubmitted) {
      Navigator.of(context).pop();
      return;
    }
    final String label = _isDpp ? 'DPP' : 'Practice';
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pause & Exit $label?'),
        content: const Text(
          'Your progress has been saved automatically. You can resume anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Resume'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Pause & Exit'),
          ),
        ],
      ),
    );
    if ((shouldExit ?? false) && mounted) {
      Navigator.of(context).pop();
    }
  }

  String _formatHtml(String? htmlString) {
    return HtmlCleaner.clean(htmlString);
  }

  bool _isDummyOptionText(String txt) {
    final clean = txt
        .replaceAll(RegExp(r'&nbsp;|\u00A0'), ' ')
        .replaceAll(RegExp(r'</?(?:p|div|br)\s*/?>', caseSensitive: false), '')
        .trim();
    final dummyRegex = RegExp(
      r'^(?:\([A-D1-4]\)|[A-D1-4][\.\)]?|option\s*[A-D1-4]|)$',
      caseSensitive: false,
    );
    return clean.isEmpty || dummyRegex.hasMatch(clean);
  }

  String _getOptionHtml(Map<String, dynamic> opt) {
    final rawText = opt['text'] ??
        opt['optionText'] ??
        opt['value'] ??
        opt['title'] ??
        opt['content'] ??
        opt['statement'] ??
        '';
    final imageUrl =
        opt['imageUrl'] ?? opt['image'] ?? opt['img'] ?? opt['url'];

    String textStr = rawText.toString().trim();

    if (imageUrl != null && imageUrl.toString().trim().isNotEmpty) {
      final imgStr = imageUrl.toString().trim();
      if (!textStr.toLowerCase().contains('<img') &&
          !textStr.contains(imgStr)) {
        textStr = textStr.isEmpty
            ? '<img src="$imgStr" />'
            : '$textStr<br/><img src="$imgStr" />';
      }
    }

    String stripped = textStr
        .replaceAll(
          RegExp(
            r'^(?:<p>|<div|<br\s*/?>|\s)*(?:\([A-D1-4]\)|[A-D1-4][\.\:\)])\s*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    final finalText = stripped.isNotEmpty ? stripped : textStr;
    return _formatHtml(finalText);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.exam.title),
          leading: const BackButton(),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.exam.title),
          leading: const BackButton(),
        ),
        body: const Center(child: Text('No questions available.')),
      );
    }

    final question = _questions[_currentQuestionIndex];
    final String questionText = question['questionText']?.toString() ?? 'Question';
    final questionType = question['type']?.toString() ?? 'MCQ';
    final List<Map<String, dynamic>> options =
        List<Map<String, dynamic>>.from(question['options'] ?? []);

    final imageValue = question['imageUrl'] ?? question['image'];
    final String? imageUrl = imageValue is String ? imageValue : null;

    final String currentQId = _getQuestionId(question);
    final int questionTimeSeconds =
        currentQId.isNotEmpty ? (_timeSpentPerQuestion[currentQId] ?? 0) : 0;

    dynamic currentAnswerObj;
    if (_backendAnswers.isNotEmpty && currentQId.isNotEmpty) {
      currentAnswerObj = _backendAnswers.firstWhere(
        (a) => _getQuestionId(a) == currentQId,
        orElse: () => null,
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        _handlePauseAndExit(_isSubmitted);
      },
      child: Scaffold(
        key: _scaffoldKey,
        endDrawer: _buildQuestionPalette(),
        appBar: AppBar(
          title: Text(
            widget.exam.title,
            style: TextStyle(fontSize: 14),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => _handlePauseAndExit(_isSubmitted),
          ),
          actions: [
            if (!_isSubmitted) ...[
              OutlinedButton.icon(
                onPressed: () => _handlePauseAndExit(_isSubmitted),
                icon: const Icon(Icons.pause_circle_outline_rounded, size: 16),
                label: const Text('Pause'),
                style: OutlinedButton.styleFrom(
                  foregroundColor:                                       Color(0xFF1E40AF),

                  side: const BorderSide(color: Colors.black38),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              FilledButton(
                onPressed: _isSubmitting ? null : _submitSession,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _isDpp ? 'Submit' : 'Submit',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Score: $_score / $_totalMarks',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '|  ${_formatTime(_totalTimeSpentSeconds)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            IconButton(
              icon: const Icon(Icons.grid_view_rounded),
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
          ],
        ),
        body: Column(
          children: [
            LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / _questions.length,
              color: AppTheme.primary,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
              minHeight: 5,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (!_isSubmitted)
                          Text(
                            'Time: ${_formatTime(questionTimeSeconds)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    MathHtmlRenderer(
                      htmlContent: _formatHtml(questionText),
                      baseFontSize: 18.0,
                    ),
                    if (imageUrl != null && imageUrl.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: Image.network(
                            imageUrl.startsWith('http')
                                ? imageUrl
                                : '${AppConfig.baseUrl.replaceAll('/api/v1', '')}$imageUrl',
                            width: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (options.isNotEmpty &&
                        (questionType == 'MCQ' || questionType == 'TRUE_FALSE'))
                      ...options.asMap().entries.map((entry) {
                        final optIndex = entry.key;
                        final opt = entry.value;
                        final optId = _getOptionHtmlId(opt, optIndex);
                        final optHtml = _getOptionHtml(opt);
                        
                        final selectedAnsId = _answers[_currentQuestionIndex] ??
                            (currentAnswerObj is Map
                                ? _extractId(currentAnswerObj['selectedOptionId'])
                                : null);
                        final isSelected = selectedAnsId == optId;

                        bool isCorrectOpt = opt['isCorrect'] == true ||
                            opt['isCorrect'] == 'true' ||
                            opt['isCorrect'] == 1;

                        final practiceFeedback =
                            _practiceFeedback[_currentQuestionIndex];
                        final isPracticeChecked =
                            _isInteractivePractice && practiceFeedback != null;
                        final letter = String.fromCharCode(65 + optIndex);

                        Color cardBg = isSelected
                            ? AppTheme.primary.withValues(alpha: 0.06)
                            : Colors.white;
                        Color cardBorder = isSelected
                            ? AppTheme.primary
                            : Colors.grey.shade200;
                        Color circleBg = isSelected
                            ? AppTheme.primary
                            : Colors.grey.shade100;
                        Color letterColor = isSelected
                            ? Colors.white
                            : Colors.grey.shade800;

                        if (_isSubmitted || isPracticeChecked) {
                          if (isCorrectOpt) {
                            cardBg = const Color(0xFFF0FDF4);
                            cardBorder = const Color(0xFF22C55E);
                            circleBg = const Color(0xFF22C55E);
                            letterColor = Colors.white;
                          } else if (isSelected && !isCorrectOpt) {
                            cardBg = const Color(0xFFFEF2F2);
                            cardBorder = const Color(0xFFEF4444);
                            circleBg = const Color(0xFFEF4444);
                            letterColor = Colors.white;
                          } else {
                            cardBg = Colors.grey.shade50;
                            cardBorder = Colors.grey.shade200;
                          }
                        }

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (!_isSubmitted &&
                                optId.isNotEmpty &&
                                (!_isInteractivePractice ||
                                    !_lockedPracticeAnswers.contains(
                                      _currentQuestionIndex,
                                    ))) {
                              if (_isDpp) {
                                _saveAnswer(_currentQuestionIndex, optId);
                              } else {
                                setState(() {
                                  _answers[_currentQuestionIndex] = optId;
                                });
                              }
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              border: Border.all(
                                color: cardBorder,
                                width: (isSelected ||
                                        ((_isSubmitted || isPracticeChecked) &&
                                            isCorrectOpt))
                                    ? 2
                                    : 1,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: circleBg,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      letter,
                                      style: TextStyle(
                                        color: letterColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: MathHtmlRenderer(
                                      htmlContent: optHtml,
                                      baseFontSize: 15.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      })
                    else
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 180),
                          child: TextField(
                            key: ValueKey('typed-$_currentQuestionIndex'),
                            controller: _typedControllers.putIfAbsent(
                              _currentQuestionIndex,
                              () => TextEditingController(
                                text: _answers[_currentQuestionIndex] ??
                                    (currentAnswerObj is Map
                                        ? (currentAnswerObj[
                                                      'subjectiveAnswerText'] ??
                                                  '')
                                              .toString()
                                        : ''),
                              ),
                            ),
                            maxLines: 1,
                            readOnly: _isSubmitted ||
                                (_isInteractivePractice &&
                                    _lockedPracticeAnswers.contains(
                                      _currentQuestionIndex,
                                    )),
                            keyboardType: const TextInputType.numberWithOptions(
                              signed: true,
                              decimal: true,
                            ),
                            inputFormatters: [NumericAnswerFormatter()],
                            decoration: InputDecoration(
                              hintText: ExamStrings.integerHint,
                              isDense: true,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppTheme.primary,
                                  width: 2,
                                ),
                              ),
                            ),
                            onChanged: (val) =>
                                _onTypedChanged(_currentQuestionIndex, val),
                          ),
                        ),
                      ),
                    if (_isInteractivePractice &&
                        _practiceFeedback.containsKey(
                          _currentQuestionIndex,
                        )) ...[
                      const SizedBox(height: 8),
                      _buildInlinePracticeFeedback(
                        _practiceFeedback[_currentQuestionIndex]!,
                      ),
                    ],
                    if (_isSubmitted) ...[
                      // Solution & Explanation Box (Always rendered when submitted, matching web portal)
                      (() {
                        final String rawExplanation =
                            (currentAnswerObj is Map
                                    ? currentAnswerObj['explanation']
                                    : null)
                                ?.toString() ??
                            question['explanation']?.toString() ??
                            question['solution']?.toString() ??
                            '';
                        final String explanationText =
                            rawExplanation.trim().isNotEmpty
                                ? rawExplanation
                                : 'No explanation provided.';

                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFBFDBFE),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF2563EB),
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Solution & Explanation',
                                    style: TextStyle(
                                      color: Color(0xFF1E40AF),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              MathHtmlRenderer(
                                htmlContent: _formatHtml(explanationText),
                                baseFontSize: 14.5,
                                fontColor: const Color(0xFF1E40AF),
                              ),
                            ],
                          ),
                        );
                      })(),
                      // Per-Question Time Spent Box
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                PhosphorIcon(
                                  PhosphorIcons.clock,
                                  size: 18,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Time Spent on this Question:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              _formatTime(questionTimeSeconds),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            // Bottom Action Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (!_isSubmitted && _answers[_currentQuestionIndex] != null)
                      OutlinedButton.icon(
                        onPressed: _clearResponse,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text(
                          'Clear Response',
                          style: TextStyle(fontSize: 11),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade400),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _currentQuestionIndex > 0
                              ? () => setState(() => _currentQuestionIndex--)
                              : null,
                          icon: const Icon(Icons.arrow_back_rounded, size: 16),
                          label: const Text('Previous'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade100,
                            foregroundColor: Colors.grey.shade800,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_isInteractivePractice &&
                            !_isSubmitted &&
                            _answers[_currentQuestionIndex] != null &&
                            !_practiceFeedback.containsKey(_currentQuestionIndex))
                          ElevatedButton(
                            onPressed: _isCheckingAnswer ? null : _handleCheckAnswer,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isCheckingAnswer
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Check Answer',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                          )
                        else if (_currentQuestionIndex < _questions.length - 1)
                          ElevatedButton(
                            onPressed: () =>
                                setState(() => _currentQuestionIndex++),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Text(
                                  'Next',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_rounded, size: 16),
                              ],
                            ),
                          )
                        else
                          ElevatedButton(
                            onPressed: _isSubmitted
                                ? () => Navigator.pop(context)
                                : (_isSubmitting ? null : _submitSession),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _isSubmitted
                                        ? 'Close'
                                        : (_isDpp
                                              ? 'Submit'
                                              : 'Submit'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getOptionHtmlId(Map<String, dynamic> opt, int index) {
    final id = _extractId(opt['_id']) ??
        _extractId(opt['id']) ??
        _extractId(opt['optionId']);
    if (id != null && id.isNotEmpty) return id;
    final text = (opt['text'] ?? opt['optionText'] ?? '').toString().trim();
    if (text.isNotEmpty) return text;
    return 'opt_$index';
  }

  Widget _buildInlinePracticeFeedback(Map<String, dynamic> feedback) {
    final isCorrect = feedback['isCorrect'] == true;
    final explanationText = feedback['explanation']?.toString().trim() ?? '';
    final color = isCorrect ? AppTheme.success : AppTheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect ? 'Correct Answer!' : 'Incorrect!',
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Explanation:',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          MathHtmlRenderer(
            htmlContent: _formatHtml(
              explanationText.isNotEmpty
                  ? explanationText
                  : 'No explanation provided.',
            ),
            baseFontSize: 14,
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionPalette() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Text(
                    'Question Palette',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _questions.length,
                itemBuilder: (context, index) {
                  final isAnswered = _answers.containsKey(index);
                  final isCurrent = index == _currentQuestionIndex;

                  final q = _questions[index];
                  final qId = _getQuestionId(q);
                  dynamic ansObj;
                  if (_backendAnswers.isNotEmpty && qId.isNotEmpty) {
                    ansObj = _backendAnswers.firstWhere(
                      (a) => _getQuestionId(a) == qId,
                      orElse: () => null,
                    );
                  }

                  Color btnBg = isAnswered
                      ? AppTheme.success
                      : Colors.grey.shade200;
                  Color textColor = isAnswered ? Colors.white : Colors.black87;

                  if (_isSubmitted) {
                    if (ansObj is Map &&
                        (ansObj['selectedOptionId'] != null ||
                            (ansObj['subjectiveAnswerText'] ?? '')
                                .toString()
                                .trim()
                                .isNotEmpty)) {
                      if (ansObj['isCorrect'] == true) {
                        btnBg = const Color(0xFF22C55E); // Green
                        textColor = Colors.white;
                      } else {
                        btnBg = const Color(0xFFEF4444); // Red
                        textColor = Colors.white;
                      }
                    } else {
                      btnBg = Colors.grey.shade200;
                      textColor = Colors.black87;
                    }
                  }

                  return GestureDetector(
                    onTap: () {
                      setState(() => _currentQuestionIndex = index);
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: btnBg,
                        shape: BoxShape.circle,
                        border: isCurrent
                            ? Border.all(color: Colors.black, width: 2.5)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
