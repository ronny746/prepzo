import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lms/core/constants/exam_strings.dart';
import 'package:lms/core/utils/numeric_answer_formatter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/core/config/app_config.dart';
import 'package:lms/features/exams/data/models/exams_models.dart';
import 'package:lms/features/exams/data/repositories/exams_repository.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:camera/camera.dart';
import 'package:lms/core/widgets/math_html_renderer.dart';
import 'package:lms/features/exams/presentation/screens/dpp_practice_player_screen.dart';

class ExamPlayerScreen extends StatefulWidget {
  const ExamPlayerScreen({super.key, required this.exam});
  final ExamModel exam;

  @override
  State<ExamPlayerScreen> createState() => _ExamPlayerScreenState();
}

class _ExamPlayerScreenState extends State<ExamPlayerScreen>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentQuestionIndex = 0;
  final Map<int, String> _answers = {};
  final Set<int> _markedForReview = {};
  final Set<int> _lockedPracticeAnswers = {};
  final Map<int, Map<String, dynamic>> _practiceFeedback = {};
  bool _isSubmitting = false;
  Timer? _timer;
  int _remainingSeconds = 0;

  List<dynamic> _questions = [];
  bool _isLoading = true;

  CameraController? _cameraController;
  Timer? _snapshotTimer;
  int _violationsCount = 0;
  bool _enableProctoring = false;
  int? _maxTabSwitchesAllowed;

  // True only while the clock is running on a live attempt; leaves before the
  // student pressed Start (or after submit) must never count as violations.
  bool _examLive = false;
  bool _autoSubmittedForLeaves = false;
  // True while the app itself asks for a permission: the OS permission dialog
  // pauses the activity, which must not be mistaken for the student leaving.
  bool _requestingPermission = false;
  // Set when a leave was counted; the warning dialog is shown on return.
  bool _pendingLeaveWarning = false;
  // Questions the student has opened, to tell "Not visited" from "Not answered".
  final Set<int> _visited = {};
  // One controller per typed-answer question so the text survives navigation.
  final Map<int, TextEditingController> _typedControllers = {};

  bool get _isDpp {
    final title = widget.exam.title.trimLeft().toUpperCase();
    return title.startsWith('DPP');
  }

  bool get _isPractice {
    final title = widget.exam.title.trimLeft().toUpperCase();
    return title.startsWith('PRACTICE') || widget.exam.id.startsWith('custom-');
  }

  bool get _isPracticeOrDpp => _isDpp || _isPractice;

  bool get _isRemotePracticeSession =>
      _isPracticeOrDpp && !widget.exam.id.startsWith('custom-');

  bool get _isInteractivePractice => _isPractice && !_isDpp;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Real timed tests show the rules and ask for the camera BEFORE the attempt
    // is created server-side and the clock starts. Practice/DPP and
    // already-submitted (review) attempts keep the old direct path.
    if (_isPracticeOrDpp || widget.exam.submissionStatus == 'SUBMITTED') {
      _startExam();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showStartGate());
    }
  }

  /// Shows the instructions dialog, then requests camera permission, then
  /// starts the exam. Cancel leaves the screen without creating an attempt.
  Future<void> _showStartGate() async {
    if (!mounted) return;
    final total = widget.exam.totalQuestions ?? widget.exam.questions.length;
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text(ExamStrings.startTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ExamStrings.fill(ExamStrings.startDuration, {
                  'minutes': widget.exam.durationMinutes,
                }),
              ),
              if (total > 0)
                Text(
                  ExamStrings.fill(ExamStrings.startQuestions, {
                    'count': total,
                  }),
                ),
              const SizedBox(height: 12),
              Text(
                ExamStrings.fill(ExamStrings.startRuleLeave, {
                  'max':
                      widget.exam.maxTabSwitchesAllowed ??
                      ExamStrings.defaultMaxLeaves,
                }),
              ),
              const SizedBox(height: 12),
              const Text(ExamStrings.startCameraReason),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(ExamStrings.cancelButton),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(ExamStrings.startButton),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (proceed != true) {
      Navigator.of(context).pop();
      return;
    }
    await _runWithoutLeaveTracking(() => Permission.camera.request());
    if (!mounted) return;
    await _startExam();
  }

  /// Runs [action] (a permission request) while lifecycle events are ignored.
  /// The short tail delay covers the paused/resumed events that the OS
  /// delivers just after the permission dialog closes.
  Future<void> _runWithoutLeaveTracking(Future<void> Function() action) async {
    _requestingPermission = true;
    try {
      await action();
    } catch (e) {
      debugPrint('Permission request error: $e');
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      _requestingPermission = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _snapshotTimer?.cancel();
    _cameraController?.dispose();
    for (final c in _typedControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_examLive || _requestingPermission || _isSubmitting) return;
    // Only `paused` means the app really went to the background. `inactive`
    // also fires for the notification shade, system dialogs and incoming-call
    // banners, which are not the student leaving the test.
    if (state == AppLifecycleState.paused) {
      _logViolation('TAB_SWITCH');
    } else if (state == AppLifecycleState.resumed && _pendingLeaveWarning) {
      _pendingLeaveWarning = false;
      _showLeaveWarning();
    }
  }

  /// Tells the student, on return, how many leaves are counted so far.
  Future<void> _showLeaveWarning() async {
    if (!mounted || _isSubmitting) return;
    final max = _maxTabSwitchesAllowed ?? 0;
    final hasLimit = max > 0;
    final isFinal = hasLimit && _violationsCount >= max - 1;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: AppTheme.error),
        title: Text(
          hasLimit
              ? ExamStrings.fill(ExamStrings.warningTitle, {
                  'n': _violationsCount,
                  'max': max,
                })
              : ExamStrings.fill(ExamStrings.warningTitleUnlimited, {
                  'n': _violationsCount,
                }),
        ),
        content: Text(
          !hasLimit
              ? ExamStrings.warningUnlimitedBody
              : (isFinal
                    ? ExamStrings.warningFinalBody
                    : ExamStrings.warningBody),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(ExamStrings.warningOk),
          ),
        ],
      ),
    );
  }

  void _logViolation(String type) {
    setState(() {
      _violationsCount++;
    });
    _pendingLeaveWarning = true;
    if (_enableProctoring) {
      _captureAndUploadSnapshot(type: type);
    }
    if (_maxTabSwitchesAllowed != null &&
        _maxTabSwitchesAllowed! > 0 &&
        _violationsCount >= _maxTabSwitchesAllowed!) {
      // The student is being submitted, so there is no one to warn on return.
      _pendingLeaveWarning = false;
      _autoSubmittedForLeaves = true;
      _submitExam();
    }
  }

  void _startTimer({
    required int durationMinutes,
    required DateTime startTime,
  }) {
    _timer?.cancel();
    final elapsedSeconds = DateTime.now().difference(startTime).inSeconds;
    _remainingSeconds = (durationMinutes * 60 - elapsedSeconds)
        .clamp(0, durationMinutes * 60)
        .toInt();
    if (_remainingSeconds == 0) {
      _submitExam();
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        _submitExam();
      }
    });
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint('Camera unavailable on this device.');
        return;
      }
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {});

      _snapshotTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        _captureAndUploadSnapshot();
      });
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _captureAndUploadSnapshot({
    String type = 'PERIODIC_SNAPSHOT',
  }) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;
    if (_cameraController!.value.isTakingPicture) return;

    final examsRepo = context.read<ExamsRepository>();
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';

    try {
      final image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();

      await examsRepo.uploadSnapshot(token, widget.exam.id, bytes, image.name);
    } catch (e) {
      debugPrint('Snapshot upload error: $e');
    }
  }

  Future<void> _startExam() async {
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    final examsRepo = context.read<ExamsRepository>();

    try {
      if (_isPracticeOrDpp) {
        if (_isRemotePracticeSession) {
          try {
            final sessionData = await examsRepo.getPracticeSession(
              token,
              widget.exam.id,
            );
            final List<dynamic> rawQuestions =
                sessionData['questions'] is List &&
                    (sessionData['questions'] as List).isNotEmpty
                ? sessionData['questions']
                : widget.exam.questions;

            final List<dynamic> questions = rawQuestions.map((q) {
              if (q is Map) {
                final Map<String, dynamic> qMap = Map<String, dynamic>.from(q);
                final nested = qMap['questionId'] is Map
                    ? Map<String, dynamic>.from(qMap['questionId'])
                    : qMap;
                return {
                  ...qMap,
                  'questionText':
                      nested['questionText'] ??
                      qMap['questionText'] ??
                      'Question',
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

            setState(() {
              _questions = questions;
              _isLoading = false;
            });

            for (var i = 0; i < _questions.length; i++) {
              final qId =
                  (_questions[i]['questionId'] ??
                          _questions[i]['_id'] ??
                          _questions[i]['id'])
                      ?.toString();
              final savedAns = answers.firstWhere(
                (a) => (a['questionId'] ?? a['_id'])?.toString() == qId,
                orElse: () => null,
              );
              if (savedAns != null) {
                if (savedAns['selectedOptionId'] != null) {
                  _answers[i] = savedAns['selectedOptionId'].toString();
                } else if ((savedAns['subjectiveAnswerText'] ?? '')
                    .toString()
                    .isNotEmpty) {
                  _answers[i] = savedAns['subjectiveAnswerText'].toString();
                }
                if (savedAns['selectedOptionId'] != null) {
                  if (_isInteractivePractice) {
                    _lockedPracticeAnswers.add(i);
                    _practiceFeedback[i] = {
                      'isCorrect': savedAns['isCorrect'] == true,
                      'explanation': savedAns['explanation']?.toString() ?? '',
                    };
                  }
                }
                if (savedAns['status'] == 'MARKED_FOR_REVIEW' ||
                    savedAns['status'] == 'ANSWERED_AND_MARKED_FOR_REVIEW') {
                  _markedForReview.add(i);
                }
              }
            }
            setState(() {});
            return;
          } catch (e) {
            debugPrint('Error loading practice session: $e');
          }
        }

        setState(() {
          _questions = widget.exam.questions;
          _isLoading = false;
        });
        return;
      }

      final responseData = await examsRepo.startExam(token, widget.exam.id);
      if (responseData['questions'] != null) {
        final questions = responseData['questions'] as List<dynamic>;
        final submission = responseData['submission'];
        final settings = responseData['settings'] is Map
            ? Map<String, dynamic>.from(responseData['settings'])
            : <String, dynamic>{};
        final security = responseData['security'] is Map
            ? Map<String, dynamic>.from(responseData['security'])
            : <String, dynamic>{};
        final durationMinutes =
            int.tryParse(
              (settings['durationMinutes'] ?? widget.exam.durationMinutes)
                  .toString(),
            ) ??
            widget.exam.durationMinutes;
        final startTime = submission is Map && submission['startTime'] != null
            ? DateTime.tryParse(submission['startTime'].toString())
            : null;

        _enableProctoring = security['enableProctoring'] == true;
        _maxTabSwitchesAllowed = int.tryParse(
          security['maxTabSwitchesAllowed']?.toString() ?? '',
        );
        _examLive = true;
        _startTimer(
          durationMinutes: durationMinutes,
          startTime: startTime ?? DateTime.now(),
        );
        if (_enableProctoring) {
          // Camera init can raise a permission dialog if the start gate did not
          // get a grant; that must not count as the student leaving.
          _runWithoutLeaveTracking(_initializeCamera);
        }

        setState(() {
          _questions = questions;
          _isLoading = false;
        });

        if (submission != null && submission['answers'] != null) {
          final savedAnswers = submission['answers'] as List<dynamic>;
          for (var i = 0; i < _questions.length; i++) {
            final qId = _questions[i]['_id'] ?? _questions[i]['id'];
            final savedAns = savedAnswers
                .where(
                  (a) =>
                      a['questionId'] == qId ||
                      (a['questionId'] is Map && a['questionId']['_id'] == qId),
                )
                .firstOrNull;
            if (savedAns != null) {
              if (savedAns['selectedOptionId'] != null) {
                _answers[i] = savedAns['selectedOptionId'];
              } else if ((savedAns['subjectiveAnswerText'] ?? '')
                  .toString()
                  .isNotEmpty) {
                // Typed (integer) answers are stored here, not as an option id.
                _answers[i] = savedAns['subjectiveAnswerText'].toString();
              } else if (savedAns['answerText'] != null) {
                _answers[i] = savedAns['answerText'];
              }
              if (savedAns['status'] == 'MARKED_FOR_REVIEW' ||
                  savedAns['status'] == 'ANSWERED_AND_MARKED_FOR_REVIEW') {
                _markedForReview.add(i);
              }
            }
          }
          setState(() {});
        }
      } else {
        setState(() {
          _questions = widget.exam.questions;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _questions = widget.exam.questions;
        _isLoading = false;
      });
    }
  }

  /// Questions rendered with a text box (no options). Mirrors the UI branch.
  bool _isTypedQuestion(int index) {
    final type = _questions[index]['type']?.toString() ?? 'MCQ';
    return type != 'MCQ' && type != 'TRUE_FALSE';
  }

  /// Builds the answer fields of a save-answer payload. A typed number must go
  /// in `subjectiveAnswerText`; the server casts `selectedOptionId` to an
  /// ObjectId and rejects anything else (the QA "answer thrown away" bug).
  Map<String, dynamic> _answerFields(int index, String? answer) {
    final value = answer?.trim();
    final hasValue = value != null && value.isNotEmpty;
    if (_isTypedQuestion(index)) {
      return {
        'selectedOptionId': null,
        'subjectiveAnswerText': hasValue ? value : null,
      };
    }
    return {'selectedOptionId': answer, 'subjectiveAnswerText': null};
  }

  Future<void> _saveAnswer(int questionIndex, String answer) async {
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
    final qId = question['_id'] ?? question['id'];
    final isMarked = _markedForReview.contains(questionIndex);

    if (qId != null &&
        !token.startsWith('mock-') &&
        !widget.exam.id.startsWith('custom-')) {
      try {
        final payload = {
          'questionId': qId,
          ..._answerFields(questionIndex, answer),
          'status': isMarked ? 'ANSWERED_AND_MARKED_FOR_REVIEW' : 'ANSWERED',
        };
        if (_isRemotePracticeSession) {
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
            await _showPracticeFeedback(
              isCorrect: data['isCorrect'] == true,
              explanation: data['explanation']?.toString() ?? '',
              question: question,
            );
          }
        } else {
          await context.read<ExamsRepository>().saveAnswer(
            token,
            widget.exam.id,
            payload,
          );
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
            SnackBar(
              content: const Text(
                'Could not save your answer. Please try again.',
              ),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _showPracticeFeedback({
    required bool isCorrect,
    required String explanation,
    required Map question,
  }) {
    final options = question['options'] is List
        ? List<Map<String, dynamic>>.from(question['options'])
        : <Map<String, dynamic>>[];
    final correctOption = options.cast<Map<String, dynamic>?>().firstWhere(
      (option) => option?['isCorrect'] == true,
      orElse: () => null,
    );
    final correctText = correctOption?['text']?.toString() ?? '';

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isCorrect
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: isCorrect ? AppTheme.success : AppTheme.error,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isCorrect ? 'Correct!' : 'Incorrect',
                      style: TextStyle(
                        color: isCorrect ? AppTheme.success : AppTheme.error,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                if (!isCorrect && correctText.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Correct answer',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  MathHtmlRenderer(
                    htmlContent: _formatHtml(correctText),
                    baseFontSize: 15,
                  ),
                ],
                if (explanation.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Explanation',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  MathHtmlRenderer(
                    htmlContent: _formatHtml(explanation),
                    baseFontSize: 15,
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInlinePracticeFeedback(Map<String, dynamic> feedback) {
    final isCorrect = feedback['isCorrect'] == true;
    final explanation = feedback['explanation']?.toString() ?? '';
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
                isCorrect ? 'Correct!' : 'Incorrect',
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Explanation',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          if (explanation.isEmpty)
            const Text('No explanation provided.')
          else
            MathHtmlRenderer(
              htmlContent: _formatHtml(explanation),
              baseFontSize: 14,
            ),
        ],
      ),
    );
  }

  Future<void> _toggleMarkForReview() async {
    final bool wasMarked = _markedForReview.contains(_currentQuestionIndex);
    setState(() {
      if (wasMarked) {
        _markedForReview.remove(_currentQuestionIndex);
      } else {
        _markedForReview.add(_currentQuestionIndex);
      }
    });

    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    final question = _questions[_currentQuestionIndex];
    final qId = question['_id'] ?? question['id'];
    final answer = _answers[_currentQuestionIndex];
    final isMarked = !wasMarked;

    if (qId != null &&
        !token.startsWith('mock-') &&
        !widget.exam.id.startsWith('custom-')) {
      try {
        final payload = {
          'questionId': qId,
          ..._answerFields(_currentQuestionIndex, answer),
          'status': answer != null
              ? (isMarked ? 'ANSWERED_AND_MARKED_FOR_REVIEW' : 'ANSWERED')
              : (isMarked ? 'MARKED_FOR_REVIEW' : 'NOT_ANSWERED'),
        };
        if (_isRemotePracticeSession) {
          await context.read<ExamsRepository>().savePracticeProgress(
            token,
            widget.exam.id,
            payload,
          );
        } else {
          await context.read<ExamsRepository>().saveAnswer(
            token,
            widget.exam.id,
            payload,
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            if (wasMarked) {
              _markedForReview.add(_currentQuestionIndex);
            } else {
              _markedForReview.remove(_currentQuestionIndex);
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Could not update the review mark. Please try again.',
              ),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _clearResponse() async {
    final String? previousAnswer = _answers[_currentQuestionIndex];
    setState(() {
      _answers.remove(_currentQuestionIndex);
      _typedControllers[_currentQuestionIndex]?.clear();
    });

    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    final question = _questions[_currentQuestionIndex];
    final qId = question['_id'] ?? question['id'];
    final isMarked = _markedForReview.contains(_currentQuestionIndex);

    if (qId != null &&
        !token.startsWith('mock-') &&
        !widget.exam.id.startsWith('custom-')) {
      try {
        final payload = {
          'questionId': qId,
          'selectedOptionId': null,
          'subjectiveAnswerText': null,
          'status': isMarked ? 'MARKED_FOR_REVIEW' : 'NOT_ANSWERED',
        };
        if (_isRemotePracticeSession) {
          await context.read<ExamsRepository>().savePracticeProgress(
            token,
            widget.exam.id,
            payload,
          );
        } else {
          await context.read<ExamsRepository>().saveAnswer(
            token,
            widget.exam.id,
            payload,
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            if (previousAnswer != null) {
              _answers[_currentQuestionIndex] = previousAnswer;
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Could not clear your answer. Please try again.',
              ),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleSaveAndNext() async {
    final answer = _answers[_currentQuestionIndex];
    final isMarked = _markedForReview.contains(_currentQuestionIndex);
    final status = answer != null
        ? (isMarked ? 'ANSWERED_AND_MARKED_FOR_REVIEW' : 'ANSWERED')
        : 'NOT_ANSWERED';
    await _saveAnswerWithStatus(_currentQuestionIndex, answer, status);
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() => _currentQuestionIndex++);
    }
  }

  Future<void> _handleSaveAndMarkReview() async {
    final answer = _answers[_currentQuestionIndex];
    if (answer == null || answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select an option first to Save & Mark for Review',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      _markedForReview.add(_currentQuestionIndex);
    });
    await _saveAnswerWithStatus(
      _currentQuestionIndex,
      answer,
      'ANSWERED_AND_MARKED_FOR_REVIEW',
    );
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() => _currentQuestionIndex++);
    }
  }

  Future<void> _handleMarkReviewAndNext() async {
    final answer = _answers[_currentQuestionIndex];
    setState(() {
      _markedForReview.add(_currentQuestionIndex);
    });
    final status = answer != null
        ? 'ANSWERED_AND_MARKED_FOR_REVIEW'
        : 'MARKED_FOR_REVIEW';
    await _saveAnswerWithStatus(_currentQuestionIndex, answer, status);
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() => _currentQuestionIndex++);
    }
  }

  Future<void> _saveAnswerWithStatus(
    int questionIndex,
    String? answer,
    String status,
  ) async {
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    final question = _questions[questionIndex];
    final qId = question['_id'] ?? question['id'];

    if (qId != null &&
        !token.startsWith('mock-') &&
        !widget.exam.id.startsWith('custom-')) {
      try {
        final payload = {
          'questionId': qId,
          ..._answerFields(questionIndex, answer),
          'status': status,
        };
        if (_isRemotePracticeSession) {
          await context.read<ExamsRepository>().savePracticeProgress(
            token,
            widget.exam.id,
            payload,
          );
        } else {
          await context.read<ExamsRepository>().saveAnswer(
            token,
            widget.exam.id,
            payload,
          );
        }
      } catch (e) {
        debugPrint('Error saving answer status: $e');
      }
    }
  }

  /// Asks the student to confirm before a manual submit. Auto-submit paths
  /// (time up, too many leaves) call [_submitExam] directly and skip this.
  Future<void> _confirmAndSubmit() async {
    if (_isSubmitting) return;
    final total = _questions.length;
    final answered = _answers.values.where((a) => a.trim().isNotEmpty).length;
    final marked = _markedForReview.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(ExamStrings.submitTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ExamStrings.fill(ExamStrings.submitAnswered, {'n': answered})),
            Text(
              ExamStrings.fill(ExamStrings.submitNotAnswered, {
                'n': total - answered,
              }),
            ),
            Text(ExamStrings.fill(ExamStrings.submitMarked, {'n': marked})),
            const SizedBox(height: 12),
            const Text(ExamStrings.submitWarning),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(ExamStrings.goBack),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(ExamStrings.submit),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _submitExam();
  }

  Future<void> _submitExam() async {
    if (widget.exam.submissionStatus == 'SUBMITTED') return;
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';

    try {
      final violationsObj = {'tabSwitches': _violationsCount};

      if (_isRemotePracticeSession) {
        await context.read<ExamsRepository>().submitPracticeSession(
          token,
          widget.exam.id,
        );
      } else {
        await context.read<ExamsRepository>().submitExam(
          token,
          widget.exam.id,
          {'violations': violationsObj, 'isAutoSubmit': _remainingSeconds <= 0},
        );
      }

      _examLive = false;
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _autoSubmittedForLeaves
                  ? ExamStrings.autoSubmittedLeaves
                  : 'Test submitted successfully!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error submitting test: $e')));
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _formatHtml(String? htmlString) {
    if (htmlString == null || htmlString.isEmpty) return '';
    final String domain = AppConfig.webUrl;
    return htmlString.replaceAll('src="/', 'src="$domain/');
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
    final rawText =
        opt['text'] ??
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

  Map<String, dynamic> _parseQuestionTextAndOptions(
    String rawQuestionText,
    List<Map<String, dynamic>> existingOptions,
  ) {
    if (rawQuestionText.isEmpty) {
      return {'questionText': rawQuestionText, 'options': existingOptions};
    }

    // SAFEGUARD 1: Do NOT parse/split if question text contains HTML images or image URLs
    if (rawQuestionText.toLowerCase().contains('<img') ||
        rawQuestionText.toLowerCase().contains('amazonaws.com') ||
        rawQuestionText.toLowerCase().contains('.png') ||
        rawQuestionText.toLowerCase().contains('.jpg')) {
      return {'questionText': rawQuestionText, 'options': existingOptions};
    }

    // SAFEGUARD 2: Do NOT parse/split if options already contain real non-dummy text
    final bool hasRealOptionTexts =
        existingOptions.isNotEmpty &&
        existingOptions.any((o) {
          final txt = (o['text'] ?? o['optionText'] ?? o['value'] ?? '')
              .toString();
          return !_isDummyOptionText(txt);
        });

    if (hasRealOptionTexts) {
      return {'questionText': rawQuestionText, 'options': existingOptions};
    }

    // STRICT MATCHING: Case-sensitive uppercase (A), (B), (C), (D) or (1), (2), (3), (4)
    final RegExp firstOptionRegex = RegExp(
      r'(?:\([A-D1-4]\)|[A-D1-4][\.\:\)])\s*',
    );
    final matchA = firstOptionRegex.firstMatch(rawQuestionText);

    if (matchA == null) {
      return {'questionText': rawQuestionText, 'options': existingOptions};
    }

    final promptText = rawQuestionText.substring(0, matchA.start).trim();
    final questionText = promptText.isNotEmpty ? promptText : rawQuestionText;
    final optionsSegment = rawQuestionText.substring(matchA.start);

    final RegExp splitPattern = RegExp(
      r'(?:<p>|<div|<br\s*/?>|\s|^)*(?:\(?([A-D1-4])\)?[\.\:\)\s])\s*',
    );

    final matches = splitPattern.allMatches(optionsSegment).toList();

    if (matches.length < 2) {
      return {'questionText': rawQuestionText, 'options': existingOptions};
    }

    List<Map<String, dynamic>> finalOptions = [];

    for (int i = 0; i < matches.length; i++) {
      final currentMatch = matches[i];
      final letter = currentMatch.group(1)!.toUpperCase();
      final startIdx = currentMatch.end;
      final endIdx = (i + 1 < matches.length)
          ? matches[i + 1].start
          : optionsSegment.length;

      var optText = optionsSegment.substring(startIdx, endIdx).trim();
      optText = optText
          .replaceAll(
            RegExp(r'</?(?:p|div|br)\s*/?>', caseSensitive: false),
            ' ',
          )
          .trim();

      Map<String, dynamic> optObj = (i < existingOptions.length)
          ? Map<String, dynamic>.from(existingOptions[i])
          : {};

      final optId = optObj['_id'] ?? optObj['id'] ?? 'opt_${letter}_$i';
      optObj['_id'] = optId;
      optObj['id'] = optId;
      optObj['text'] = optText.isNotEmpty
          ? optText
          : (optObj['text'] ?? 'Option $letter');

      finalOptions.add(optObj);
    }

    return {
      'questionText': questionText,
      'options': finalOptions.isNotEmpty ? finalOptions : existingOptions,
    };
  }

  Future<void> _handleExitOrPause(bool isSubmitted) async {
    if (isSubmitted) {
      Navigator.of(context).pop();
      return;
    }
    final String typeTitle = _isDpp
        ? 'DPP'
        : (_isPractice ? 'Practice' : 'Test');
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          _isPracticeOrDpp ? 'Pause & Exit $typeTitle?' : 'Exit Test?',
        ),
        content: Text(
          _isPracticeOrDpp
              ? 'Your progress has been saved automatically. You can resume anytime.'
              : 'Your progress will be saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Resume'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_isPracticeOrDpp ? 'Pause & Exit' : 'Exit'),
          ),
        ],
      ),
    );
    if ((shouldExit ?? false) && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isPracticeOrDpp) {
      return DppPracticePlayerScreen(exam: widget.exam);
    }

    final minutesStr = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final secondsStr = (_remainingSeconds % 60).toString().padLeft(2, '0');

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
        body: const Center(child: Text('No questions available in this exam.')),
      );
    }

    final question = _questions[_currentQuestionIndex];
    _visited.add(_currentQuestionIndex);
    final String rawQuestionText =
        question['questionText']?.toString() ?? 'Question';
    final questionType = question['type']?.toString() ?? 'MCQ';
    final List<Map<String, dynamic>> rawOptions =
        List<Map<String, dynamic>>.from(question['options'] ?? []);

    final parsedQuestion = _parseQuestionTextAndOptions(
      rawQuestionText,
      rawOptions,
    );
    final questionText = parsedQuestion['questionText'] as String;
    final options = List<Map<String, dynamic>>.from(
      parsedQuestion['options'] as List,
    );
    final imageValue = question['imageUrl'] ?? question['image'];
    final String? imageUrl = imageValue is String ? imageValue : null;

    final bool isSubmitted = widget.exam.submissionStatus == 'SUBMITTED';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // With the palette open, Back should only close it, not ask to exit.
        final scaffold = _scaffoldKey.currentState;
        if (scaffold != null && scaffold.isEndDrawerOpen) {
          scaffold.closeEndDrawer();
          return;
        }
        _handleExitOrPause(isSubmitted);
      },
      child: Scaffold(
        key: _scaffoldKey,
        endDrawer: _buildQuestionPalette(),
        appBar: AppBar(
          // Long test names were cut to one line; allow two smaller lines.
          title: Text(
            widget.exam.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style:
                (Theme.of(context).appBarTheme.titleTextStyle ??
                        const TextStyle())
                    .copyWith(fontSize: 14, height: 1.2),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => _handleExitOrPause(isSubmitted),
          ),
          actions: [
            if (_isPracticeOrDpp && !isSubmitted) ...[
              OutlinedButton.icon(
                onPressed: () => _handleExitOrPause(isSubmitted),
                icon: const Icon(Icons.pause_circle_outline_rounded, size: 16),
                label: const Text('Pause / Exit'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
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
                onPressed: _isSubmitting ? null : _submitExam,
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
                  _isDpp ? 'Submit DPP' : 'Submit Practice',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ] else if (isSubmitted)
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
                child: Text(
                  'Score: ${widget.exam.score ?? 0} / ${widget.exam.totalMarks}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                    fontSize: 12,
                  ),
                ),
              )
            else if (!_isPracticeOrDpp)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.error.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.alarm_rounded,
                      color: AppTheme.error,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$minutesStr:$secondsStr',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.error,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
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
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
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
                                'QUESTION ${_currentQuestionIndex + 1}',
                                style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                questionType,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (!_isPracticeOrDpp && _violationsCount > 0)
                              Tooltip(
                                triggerMode: TooltipTriggerMode.tap,
                                showDuration: const Duration(seconds: 4),
                                message: (_maxTabSwitchesAllowed ?? 0) > 0
                                    ? ExamStrings.fill(
                                        ExamStrings.violationTooltip,
                                        {
                                          'n': _violationsCount,
                                          'max': _maxTabSwitchesAllowed!,
                                        },
                                      )
                                    : ExamStrings.fill(
                                        ExamStrings.violationTooltipUnlimited,
                                        {'n': _violationsCount},
                                      ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.error.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.warning_amber_rounded,
                                        color: AppTheme.error,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$_violationsCount',
                                        style: const TextStyle(
                                          color: AppTheme.error,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        MathHtmlRenderer(
                          htmlContent: _formatHtml(questionText),
                          baseFontSize: 18.0,
                        ),
                        if (imageUrl != null && imageUrl.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 200),
                              child: Image.network(
                                imageUrl.startsWith('http')
                                    ? imageUrl
                                    : '${AppConfig.baseUrl.replaceAll('/api/v1', '')}$imageUrl',
                                width: double.infinity,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        if (questionType == 'MCQ' ||
                            questionType == 'TRUE_FALSE')
                          ...options.asMap().entries.map((entry) {
                            final optIndex = entry.key;
                            final opt = entry.value;
                            final String optId =
                                (opt['_id'] ??
                                        opt['id'] ??
                                        opt['optionId'] ??
                                        opt['value'] ??
                                        optIndex.toString())
                                    .toString();
                            final String letter = String.fromCharCode(
                              65 + optIndex,
                            );
                            final String optHtml = _getOptionHtml(opt);
                            final String? optImg =
                                (opt['imageUrl'] ?? opt['image'])?.toString();

                            final String currentSaved =
                                (_answers[_currentQuestionIndex] ?? '')
                                    .toString();
                            final bool isSelected =
                                currentSaved.isNotEmpty &&
                                (currentSaved == optId ||
                                    currentSaved == optIndex.toString() ||
                                    currentSaved.toUpperCase() == letter ||
                                    (opt['_id'] != null &&
                                        currentSaved ==
                                            opt['_id'].toString()) ||
                                    (opt['id'] != null &&
                                        currentSaved == opt['id'].toString()));

                            final isCorrectOpt = opt['isCorrect'] == true;
                            final practiceFeedback =
                                _practiceFeedback[_currentQuestionIndex];
                            final isPracticeChecked =
                                _isInteractivePractice &&
                                practiceFeedback != null;

                            Color cardBg = isSelected
                                ? AppTheme.primary.withValues(alpha: 0.08)
                                : Colors.white;
                            Color cardBorder = isSelected
                                ? AppTheme.primary
                                : Colors.grey.shade300;
                            Color circleBg = isSelected
                                ? AppTheme.primary
                                : Colors.grey.shade100;
                            Color letterColor = isSelected
                                ? Colors.white
                                : Colors.grey.shade800;

                            if (isSubmitted || isPracticeChecked) {
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
                              }
                            }

                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                if (!isSubmitted &&
                                    (!_isInteractivePractice ||
                                        !_lockedPracticeAnswers.contains(
                                          _currentQuestionIndex,
                                        ))) {
                                  _saveAnswer(_currentQuestionIndex, optId);
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  border: Border.all(
                                    color: cardBorder,
                                    width:
                                        (isSelected ||
                                            ((isSubmitted ||
                                                    isPracticeChecked) &&
                                                isCorrectOpt))
                                        ? 2
                                        : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: AppTheme.primary.withValues(
                                              alpha: 0.08,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color: circleBg,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child:
                                                isSelected &&
                                                    !isSubmitted &&
                                                    !isPracticeChecked
                                                ? const Icon(
                                                    Icons.check_rounded,
                                                    color: Colors.white,
                                                    size: 18,
                                                  )
                                                : Text(
                                                    letter,
                                                    style: TextStyle(
                                                      color: letterColor,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              top: 3,
                                            ),
                                            child: MathHtmlRenderer(
                                              htmlContent: optHtml,
                                              baseFontSize: 15.0,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (optImg != null &&
                                        optImg.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 44,
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxHeight: 140,
                                            ),
                                            child: Image.network(
                                              optImg.startsWith('http')
                                                  ? optImg
                                                  : '${AppConfig.webUrl}${optImg.startsWith('/') ? '' : '/'}$optImg',
                                              fit: BoxFit.contain,
                                              errorBuilder: (_, __, ___) =>
                                                  const SizedBox.shrink(),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
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
                                // Keyed controller per question keeps the typed
                                // value visible when the student navigates back.
                                key: ValueKey('typed-$_currentQuestionIndex'),
                                controller: _typedControllers.putIfAbsent(
                                  _currentQuestionIndex,
                                  () => TextEditingController(
                                    text: _answers[_currentQuestionIndex] ?? '',
                                  ),
                                ),
                                maxLines: 1,
                                readOnly: isSubmitted,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      signed: true,
                                      decimal: true,
                                    ),
                                inputFormatters: [NumericAnswerFormatter()],
                                decoration: InputDecoration(
                                  hintText: ExamStrings.integerHint,
                                  isDense: true,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppTheme.primary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                // An empty box means "not answered", so drop the key.
                                onChanged: (val) => setState(() {
                                  final v = val.trim();
                                  if (v.isEmpty) {
                                    _answers.remove(_currentQuestionIndex);
                                  } else {
                                    _answers[_currentQuestionIndex] = v;
                                  }
                                }),
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
                        (() {
                          final String explanationText =
                              question['explanation']?.toString() ??
                              question['solution']?.toString() ??
                              '';
                          if (isSubmitted && explanationText.isNotEmpty) {
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
                                  ),
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        })(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                  // Small floating proctoring thumbnail so it never pushes the
                  // question down; IgnorePointer keeps options below tappable.
                  if (!_isPracticeOrDpp &&
                      _cameraController != null &&
                      _cameraController!.value.isInitialized)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: IgnorePointer(
                        child: Container(
                          width: 72,
                          height: 96,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white70, width: 2),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CameraPreview(_cameraController!),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Bottom Action Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isPracticeOrDpp) ...[
                      // Practice Paper & DPP Action Footer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (!isSubmitted &&
                              _answers[_currentQuestionIndex] != null)
                            OutlinedButton.icon(
                              onPressed: _clearResponse,
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Clear Response'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF475569),
                                side: const BorderSide(
                                  color: Color(0xFFCBD5E1),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            )
                          else
                            const SizedBox.shrink(),

                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: _currentQuestionIndex > 0
                                    ? () => setState(
                                        () => _currentQuestionIndex--,
                                      )
                                    : null,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF1E293B),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  '<< Back',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (_currentQuestionIndex < _questions.length - 1)
                                FilledButton(
                                  onPressed: () {
                                    if (!isSubmitted)
                                      _handleSaveAndNext();
                                    else
                                      setState(() => _currentQuestionIndex++);
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Save & Next >>',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                )
                              else
                                FilledButton(
                                  onPressed: isSubmitted
                                      ? () => Navigator.of(context).pop()
                                      : (_isSubmitting ? null : _submitExam),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: isSubmitted
                                        ? AppTheme.primary
                                        : const Color(0xFF10B981),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
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
                                          isSubmitted
                                              ? 'Close'
                                              : (_isDpp
                                                    ? 'Submit DPP'
                                                    : 'Submit Practice'),
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
                    ] else ...[
                      if (!isSubmitted) ...[
                        // Compact 4 Action Buttons Row (Fits entire screen width without scrolling)
                        Row(
                          children: [
                            // Save & Next
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _handleSaveAndNext,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF5CB85C),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 9,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Save & Next',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),

                            // Clear
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _clearResponse,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF475569),
                                  side: const BorderSide(
                                    color: Color(0xFFCBD5E1),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 9,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Clear',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),

                            // Save & Review
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _handleSaveAndMarkReview,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF0AD4E),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 9,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Save & Mark',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),

                            // Mark & Next
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _handleMarkReviewAndNext,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF337AB7),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 9,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Mark & Next',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Row 2: Navigation & Submit
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Back Button
                          OutlinedButton(
                            onPressed: _currentQuestionIndex > 0
                                ? () => setState(() => _currentQuestionIndex--)
                                : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1E293B),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              '<< Back',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),

                          Row(
                            children: [
                              // Next Button
                              if (_currentQuestionIndex < _questions.length - 1)
                                OutlinedButton(
                                  onPressed: () =>
                                      setState(() => _currentQuestionIndex++),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF1E293B),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Next >>',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 6),

                              // Submit Button
                              FilledButton(
                                onPressed: isSubmitted
                                    ? () => Navigator.of(context).pop()
                                    : (_isSubmitting
                                          ? null
                                          : _confirmAndSubmit),
                                style: FilledButton.styleFrom(
                                  backgroundColor: isSubmitted
                                      ? AppTheme.primary
                                      : const Color(0xFF10B981),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
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
                                        isSubmitted ? 'Close' : 'Submit Test',
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
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static final Color _notAnsweredColor = Colors.red.shade300;

  Widget _buildQuestionPalette() {
    final Map<String, List<int>> subjectMap = {};
    for (var i = 0; i < _questions.length; i++) {
      final rawSubject = _questions[i]['subject'];
      final subject = rawSubject is Map
          ? rawSubject['name']?.toString() ?? 'General'
          : rawSubject?.toString() ?? 'General';
      subjectMap.putIfAbsent(subject, () => []).add(i);
    }

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _buildLegendItem(AppTheme.success, 'Answered'),
                  _buildLegendItem(
                    Colors.grey.shade200,
                    ExamStrings.notVisited,
                    textColor: Colors.black87,
                  ),
                  _buildLegendItem(_notAnsweredColor, 'Not Answered'),
                  _buildLegendItem(Colors.purple, 'Review'),
                  _buildLegendItem(Colors.purple, 'Ans & Review', hasDot: true),
                ],
              ),
            ),
            const Divider(height: 32),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: subjectMap.keys.length,
                itemBuilder: (context, index) {
                  final subject = subjectMap.keys.elementAt(index);
                  final questionIndices = subjectMap[subject]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(
                          subject,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: questionIndices.map((qIndex) {
                          final isAnswered = _answers.containsKey(qIndex);
                          final isMarked = _markedForReview.contains(qIndex);
                          final isCurrent = _currentQuestionIndex == qIndex;

                          Color bgColor = Colors.grey.shade200;
                          Color textColor = Colors.black87;

                          // Visited but empty gets its own colour so students
                          // can tell skipped questions from untouched ones.
                          if (_visited.contains(qIndex) && !isAnswered) {
                            bgColor = _notAnsweredColor;
                            textColor = Colors.white;
                          }

                          if (isMarked) {
                            bgColor = Colors.purple;
                            textColor = Colors.white;
                          } else if (isAnswered) {
                            bgColor = AppTheme.success;
                            textColor = Colors.white;
                          }

                          return GestureDetector(
                            onTap: () {
                              setState(() => _currentQuestionIndex = qIndex);
                              Navigator.pop(context);
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: bgColor,
                                shape: BoxShape.circle,
                                border: isCurrent
                                    ? Border.all(
                                        color: Colors.black,
                                        width: 2.5,
                                      )
                                    : null,
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Text(
                                    '${qIndex + 1}',
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (isMarked && isAnswered)
                                    Positioned(
                                      bottom: 3,
                                      right: 3,
                                      child: Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                          color: AppTheme.success,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(
    Color color,
    String label, {
    Color textColor = Colors.white,
    bool hasDot = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: hasDot
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                )
              : null,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
