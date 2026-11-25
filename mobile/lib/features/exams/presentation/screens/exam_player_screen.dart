import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/core/config/app_config.dart';
import 'package:lms/core/services/call_state_service.dart';
import 'package:lms/features/exams/data/answer_payload.dart';
import 'package:lms/features/exams/data/models/exams_models.dart';
import 'package:lms/features/exams/data/repositories/exams_repository.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:camera/camera.dart';
import 'package:lms/core/widgets/math_html_renderer.dart';
import 'package:lms/core/utils/question_html.dart';
import 'package:lms/features/exams/presentation/screens/dpp_practice_player_screen.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:lms/routes/app_router.dart';

class ExamPlayerScreen extends StatefulWidget {
  const ExamPlayerScreen({super.key, required this.exam});
  final ExamModel exam;

  @override
  State<ExamPlayerScreen> createState() => _ExamPlayerScreenState();
}

/// Dark status-bar icons on the light exam screens (white icons vanished on
/// the cream background).
const SystemUiOverlayStyle _examSystemUi = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: Colors.white,
  systemNavigationBarIconBrightness: Brightness.dark,
);

class _ExamPlayerScreenState extends State<ExamPlayerScreen>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentQuestionIndex = 0;
  final Set<int> _visitedQuestions = {0};
  final Map<int, String> _answers = {};
  final Set<int> _markedForReview = {};
  final Set<int> _lockedPracticeAnswers = {};
  final Map<int, Map<String, dynamic>> _practiceFeedback = {};
  bool _isSubmitting = false;
  // One controller per question so typed text never carries over (E4).
  final Map<int, TextEditingController> _textControllers = {};
  // One pending debounced save per question; flushed on dispose.
  final PendingAnswerSaves _pendingTextSaves = PendingAnswerSaves();
  Timer? _timer;
  Timer? _questionTimer;
  int _remainingSeconds = 0;
  // Wall-clock end of the test. The countdown is worked out from this so it
  // stays right after the app was in the background (Dart timers pause there).
  DateTime? _endsAt;
  final Map<String, int> _timeSpentPerQuestion = {};

  List<dynamic> _questions = [];
  bool _isLoading = true;
  String? _errorMessage;

  CameraController? _cameraController;
  Timer? _snapshotTimer;
  int _violationsCount = 0;
  bool _enableProctoring = false;
  int? _maxTabSwitchesAllowed;
  // True while the camera permission pop-up / camera start is up: the app
  // going inactive/paused for its own pop-up is never a warning.
  bool _permissionRequestInFlight = false;
  // The warning dialog currently shown, updated in place for a new warning.
  final ValueNotifier<String?> _warningText = ValueNotifier<String?>(null);
  bool _warningDialogOpen = false;
  bool _limitDialogOpen = false;
  // Draggable camera preview position (offset from the bottom-right corner).
  Offset _cameraOffset = const Offset(12, 12);

  // When the student left the app (null while in the app).
  DateTime? _leftAt;
  // Set if a phone/VoIP call was seen while the student was away.
  bool _leftForCall = false;
  // Coming back this fast is treated as an accidental swipe, not a warning.
  static const Duration _leaveGrace = Duration(seconds: 2);

  // Why: every launch site (student_exams_screen, dashboard) passes exams from
  // /exams/student/my-exams, never a DPP/practice session; those open
  // DppPracticePlayerScreen directly. A title like "DPP - x" is just a name.
  bool get _isPractice => widget.exam.id.startsWith('custom-');

  bool get _isPracticeOrDpp => _isPractice;

  bool get _isRemotePracticeSession =>
      _isPracticeOrDpp && !widget.exam.id.startsWith('custom-');

  bool get _isInteractivePractice => _isPractice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) => _showInstructions());
  }

  /// Loads the test rules without starting the clock, explains them, asks
  /// for the camera, and only then starts the test on the server, so the
  /// permission pop-up never eats exam time or counts as a warning.
  Future<void> _showInstructions() async {
    if (!mounted) return;
    await _loadRules();
    if (!mounted) return;
    final max = _maxTabSwitchesAllowed;
    final resuming =
        _alreadyStarted || widget.exam.submissionStatus == 'IN_PROGRESS';
    final rules = <String>[
      if (resuming)
        'You started this test earlier. Your timer has kept running since then; your saved answers are kept.'
      else
        'Your timer starts only after you tap Start test.',
      if (max != null && max > 0)
        'Leaving the test (pressing Home, opening another app or locking the phone) counts as a warning. You will see a message each time. If you leave the test $max ${max == 1 ? 'time' : 'times'}, it is submitted automatically.'
      else
        'Leaving the test (pressing Home or opening another app) is recorded as a warning. You will see a message each time.',
      'Pulling down the notification bar, a phone call and this app\'s own pop-ups (like the camera permission) do not count. The timer keeps running during a call.',
      if (_enableProctoring)
        'This test uses your front camera. Please allow camera access when asked.',
    ];
    final start = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Theme(
        data: AppTheme.lightTheme,
        child: AlertDialog(
          title: Text(widget.exam.title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resuming ? 'Before you continue' : 'Before you start',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                for (final rule in rules)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  '),
                        Expanded(child: Text(rule)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Go back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(resuming ? 'Resume test' : 'Start test'),
            ),
          ],
        ),
      ),
    );
    if (start != true) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    if (_enableProctoring && _cameraController == null) {
      await _initializeCameraGuarded();
    }
    if (mounted) _startExam();
  }

  /// Reads proctoring and the warning limit before the test starts, without
  /// starting the clock. On a server without the rules endpoint the generic
  /// rules are shown and the camera is started after the start call (still
  /// before the timer).
  // The student opened this test before; its clock is already running.
  bool _alreadyStarted = false;

  Future<void> _loadRules() async {
    if (_isPracticeOrDpp) return;
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    final repo = context.read<ExamsRepository>();
    try {
      final data = await repo.getExamRules(token, widget.exam.id);
      final security = data['security'] is Map
          ? Map<String, dynamic>.from(data['security'])
          : <String, dynamic>{};
      _enableProctoring = security['enableProctoring'] == true;
      _maxTabSwitchesAllowed = int.tryParse(
        security['maxTabSwitchesAllowed']?.toString() ?? '',
      );
      _alreadyStarted =
          data['started'] == true ||
          data['submissionStatus']?.toString() == 'IN_PROGRESS';
    } catch (e) {
      // Errors (access, already submitted) are shown by _startExam.
      debugPrint('Could not load test rules: $e');
    }
  }

  /// Starts the camera with lifecycle changes ignored, so the permission
  /// pop-up is never counted as leaving the test.
  Future<void> _initializeCameraGuarded() async {
    _permissionRequestInFlight = true;
    try {
      await _initializeCamera();
    } finally {
      // The pop-up's "resumed" can arrive a moment after the call returns.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      _permissionRequestInFlight = false;
      _leftAt = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _questionTimer?.cancel();
    _snapshotTimer?.cancel();
    _pendingTextSaves.flushAll();
    for (final c in _textControllers.values) {
      c.dispose();
    }
    _cameraController?.dispose();
    _warningText.dispose();
    super.dispose();
  }

  /// A proctored test is on screen: started, not loading, not submitting.
  bool get _isTestInProgress =>
      mounted &&
      !_isPracticeOrDpp &&
      !_isLoading &&
      !_isSubmitting &&
      _questions.isNotEmpty &&
      _endsAt != null;

  // Why: `inactive` alone fires for an incoming-call banner, the notification
  // shade, Control Center and system dialogs, so it never counts. Only really
  // leaving (hidden/paused) starts a "left the test" period, and it is judged
  // on return: a call during it is not a warning, and the test is never
  // auto-submitted while the student is still on the call.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The app's own camera permission pop-up is not leaving the test.
    if (_permissionRequestInFlight) return;
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (_leftAt == null && _isTestInProgress) {
          final leftAt = DateTime.now();
          _leftAt = leftAt;
          _leftForCall = false;
          _checkForCall(leftAt);
        }
        break;
      case AppLifecycleState.resumed:
        _onReturnedToTest();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  // Ask right away (the call screen is up while it rings) and once more a
  // moment later, in case the call UI took a second to come up.
  Future<void> _checkForCall(DateTime leftAt) async {
    if (await CallStateService.wasInCallSince(leftAt)) {
      if (_leftAt == leftAt) _leftForCall = true;
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (_leftAt != leftAt) return;
    if (await CallStateService.wasInCallSince(leftAt) && _leftAt == leftAt) {
      _leftForCall = true;
    }
  }

  Future<void> _onReturnedToTest() async {
    final leftAt = _leftAt;
    _leftAt = null;
    _syncRemainingTime();
    if (leftAt == null || !_isTestInProgress) return;

    final wasCall =
        _leftForCall || await CallStateService.wasInCallSince(leftAt);
    _leftForCall = false;
    if (!mounted || !_isTestInProgress) return;

    if (wasCall) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Welcome back. The call was not counted as leaving the test. The timer kept running.',
          ),
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (DateTime.now().difference(leftAt) < _leaveGrace) return;
    _logViolation('TAB_SWITCH');
  }

  /// Records the warning count on the server straight away, so closing and
  /// reopening the app can't wipe it (the server keeps the higher count).
  Future<void> _reportViolations() async {
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    final repo = context.read<ExamsRepository>();
    try {
      await repo.saveAnswer(token, widget.exam.id, {
        'violations': {'tabSwitches': _violationsCount},
      });
    } catch (e) {
      debugPrint('Could not record warning: $e'); // sent again at submit
    }
  }

  void _logViolation(String type) {
    if (!mounted) return;
    setState(() {
      _violationsCount++;
    });
    _reportViolations();
    if (_enableProctoring) {
      _captureAndUploadSnapshot(type: type);
    }
    final max = _maxTabSwitchesAllowed;
    if (max != null && max > 0 && _violationsCount >= max) {
      _submitAfterLimit(max);
    } else {
      _showLeaveWarning();
    }
  }

  /// Message for a counted leave that did not reach the limit.
  String _warningMessage() {
    final max = _maxTabSwitchesAllowed;
    final n = _violationsCount;
    if (max == null || max <= 0) {
      return 'Warning $n: you left the test. Please stay in the test until you submit.';
    }
    final left = max - n;
    return left <= 1
        ? 'Warning $n of $max. You left the test. If you leave the test again it will be submitted.'
        : 'Warning $n of $max. You left the test. If you leave the test $left more times it will be submitted.';
  }

  /// One dialog on return; a further warning updates the open dialog.
  Future<void> _showLeaveWarning() async {
    _warningText.value = _warningMessage();
    if (_warningDialogOpen || !mounted) return;
    _warningDialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Theme(
        data: AppTheme.lightTheme,
        child: AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: AppTheme.error,
            size: 36,
          ),
          title: const Text('You left the test'),
          content: ValueListenableBuilder<String?>(
            valueListenable: _warningText,
            builder: (_, text, __) => Text(text ?? ''),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Continue test'),
            ),
          ],
        ),
      ),
    );
    _warningDialogOpen = false;
  }

  /// The limit is reached: say so clearly, then submit.
  Future<void> _submitAfterLimit(int max) async {
    if (!mounted) return;
    _closeWarningDialog();
    _limitDialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Theme(
        data: AppTheme.lightTheme,
        child: PopScope(
          canPop: false,
          child: AlertDialog(
            icon: const Icon(
              Icons.assignment_turned_in_rounded,
              color: AppTheme.error,
              size: 36,
            ),
            title: Text('Warning $max of $max'),
            content: Text(
              'You left the test $max ${max == 1 ? 'time' : 'times'}, which is the limit for this test. Your test is being submitted now with the answers you saved.',
            ),
            actions: const [
              Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() => _limitDialogOpen = false);
    await _submitExam();
  }

  void _closeWarningDialog() {
    if (_warningDialogOpen && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      _warningDialogOpen = false;
    }
  }

  /// Closes our own dialogs before leaving the screen, so a pop never
  /// closes a dialog instead of the test.
  void _closeOwnDialogs() {
    _closeWarningDialog();
    if (_limitDialogOpen && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      _limitDialogOpen = false;
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
    _endsAt = DateTime.now().add(Duration(seconds: _remainingSeconds));
    if (_remainingSeconds == 0) {
      _submitExam();
      return;
    }
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _syncRemainingTime(),
    );
  }

  /// Recomputes the countdown from [_endsAt]; submits once time is up.
  void _syncRemainingTime() {
    final endsAt = _endsAt;
    if (endsAt == null || !mounted) return;
    final left = endsAt.difference(DateTime.now()).inSeconds.clamp(0, 1 << 31);
    if (left != _remainingSeconds) setState(() => _remainingSeconds = left);
    if (left == 0) {
      _timer?.cancel();
      _submitExam();
    }
  }

  String _questionIdFor(Map question) {
    final raw = question['questionId'] ?? question['_id'] ?? question['id'];
    if (raw is Map) {
      return (raw['_id'] ?? raw['id'] ?? raw[r'\$oid'] ?? '').toString();
    }
    return raw?.toString() ?? '';
  }

  void _startQuestionTimer() {
    _questionTimer?.cancel();
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isLoading || _questions.isEmpty || _isSubmitting) return;
      final id = _questionIdFor(_questions[_currentQuestionIndex]);
      if (id.isNotEmpty) {
        setState(
          () =>
              _timeSpentPerQuestion[id] = (_timeSpentPerQuestion[id] ?? 0) + 1,
        );
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
            _startQuestionTimer();

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
        _startQuestionTimer();
        return;
      }

      final responseData = await examsRepo.startExam(token, widget.exam.id);
      if (responseData['questions'] != null) {
        final questions = responseData['questions'] as List<dynamic>;
        final submission = responseData['submission'];
        // Reopened test: carry on from the warnings already recorded.
        if (submission is Map && submission['violations'] is Map) {
          final saved = int.tryParse(
            '${(submission['violations'] as Map)['tabSwitches'] ?? 0}',
          );
          if (saved != null && saved > _violationsCount) {
            _violationsCount = saved;
          }
        }
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
        if (_enableProctoring && _cameraController == null) {
          // Normally done before the start call (see _showInstructions); this
          // covers a server that did not report the rules up front. Still
          // before the timer, and the pop-up is never counted as a warning.
          await _initializeCameraGuarded();
        }
        _startTimer(
          durationMinutes: durationMinutes,
          startTime: startTime ?? DateTime.now(),
        );

        setState(() {
          _questions = questions;
          _isLoading = false;
          _errorMessage = null;
        });
        _startQuestionTimer();

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
              final restored = restoreAnswerString(savedAns as Map);
              if (restored != null) _answers[i] = restored;
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
          _errorMessage = 'No questions are available in this exam paper yet.';
        });
      }
    } catch (e) {
      final msg = e
          .toString()
          .replaceAll('Exception:', '')
          .replaceAll('ApiException:', '')
          .trim();
      setState(() {
        _errorMessage = msg.isNotEmpty ? msg : 'Unable to load exam questions.';
        _questions = widget.exam.questions;
        _isLoading = false;
      });
      if (msg.toLowerCase().contains('session expired') ||
          msg.toLowerCase().contains('logged in on another device')) {
        if (mounted) {
          context.read<AuthBloc>().add(const AuthLogoutRequested());
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
        }
      }
    }
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
        final payload = _answerPayload(
          question,
          qId,
          answer,
          isMarked ? 'ANSWERED_AND_MARKED_FOR_REVIEW' : 'ANSWERED',
        );
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

  /// Returns the text controller for [index], seeded with any saved answer.
  TextEditingController _controllerFor(int index) =>
      _textControllers.putIfAbsent(
        index,
        () => TextEditingController(text: _answers[index] ?? ''),
      );

  /// Stores typed text locally and saves it ~800ms after the last keystroke,
  /// so an answer is not lost if the student leaves without Save & Next.
  void _onTextAnswerChanged(int index, String value) {
    setState(() {
      if (value.trim().isEmpty) {
        _answers.remove(index);
      } else {
        _answers[index] = value;
      }
    });
    final question = _questions[index];
    final qId = question['_id'] ?? question['id'];
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    if (qId == null ||
        token.startsWith('mock-') ||
        widget.exam.id.startsWith('custom-')) {
      return;
    }
    final answer = _answers[index];
    final marked = _markedForReview.contains(index);
    final payload = _answerPayload(
      question,
      qId,
      answer,
      answer == null
          ? (marked ? 'MARKED_FOR_REVIEW' : 'NOT_ANSWERED')
          : (marked ? 'ANSWERED_AND_MARKED_FOR_REVIEW' : 'ANSWERED'),
    );
    final repo = context.read<ExamsRepository>();
    final examId = widget.exam.id;
    final remote = _isRemotePracticeSession;
    // The closure captures repo/token/payload so it still works when it fires
    // from dispose. Silent on failure: the local answer is resent later.
    _pendingTextSaves.schedule(
      index,
      () => remote
          ? repo.savePracticeProgress(token, examId, payload)
          : repo.saveAnswer(token, examId, payload),
    );
  }

  Map<String, dynamic> _answerPayload(
    Map<String, dynamic> question,
    dynamic questionId,
    String? answer,
    String status,
  ) {
    final type = (question['type'] ?? 'MCQ').toString().toUpperCase();
    // Use the same parsed options the UI renders: when options are split out of
    // the question text their ids are synthetic (opt_A_0), which the server
    // can't grade; raw options alone would misclassify the question.
    final parsed = _parseQuestionTextAndOptions(
      question['questionText']?.toString() ?? '',
      List<Map<String, dynamic>>.from(question['options'] ?? []),
      type: type,
    );
    final fields = buildAnswerFields(
      type: type,
      hasOptions: (parsed['options'] as List).isNotEmpty,
      answer: answer,
    );
    return {
      'questionId': questionId,
      // Keys depend on the question type; see answer_payload.dart.
      ...fields,
      // Never claim ANSWERED when no answer key could be sent.
      'status': resolveAnswerStatus(
        status: status,
        answer: answer,
        fields: fields,
      ),
      'timeSpentSeconds': _timeSpentPerQuestion[_questionIdFor(question)] ?? 0,
    };
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
      builder: (sheetContext) => Theme(
        data: AppTheme.lightTheme,
        child: SafeArea(
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
                          fontWeight: FontWeight.w700,
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
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
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
        final payload = _answerPayload(
          question,
          qId,
          answer,
          answer != null
              ? (isMarked ? 'ANSWERED_AND_MARKED_FOR_REVIEW' : 'ANSWERED')
              : (isMarked ? 'MARKED_FOR_REVIEW' : 'NOT_ANSWERED'),
        );
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
    });
    // Empty the typed box too, or the cleared answer would still show.
    _textControllers[_currentQuestionIndex]?.clear();

    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    final question = _questions[_currentQuestionIndex];
    final qId = question['_id'] ?? question['id'];
    final isMarked = _markedForReview.contains(_currentQuestionIndex);

    if (qId != null &&
        !token.startsWith('mock-') &&
        !widget.exam.id.startsWith('custom-')) {
      try {
        final payload = _answerPayload(
          question,
          qId,
          null,
          isMarked ? 'MARKED_FOR_REVIEW' : 'NOT_ANSWERED',
        );
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
      setState(() {
        _currentQuestionIndex++;
        _visitedQuestions.add(_currentQuestionIndex);
      });
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
      setState(() {
        _currentQuestionIndex++;
        _visitedQuestions.add(_currentQuestionIndex);
      });
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
      setState(() {
        _currentQuestionIndex++;
        _visitedQuestions.add(_currentQuestionIndex);
      });
    }
  }

  Future<void> _saveAnswerWithStatus(
    int questionIndex,
    String? answer,
    String status,
  ) async {
    // An explicit save supersedes the pending debounced one for this question.
    _pendingTextSaves.cancel(questionIndex);
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    final question = _questions[questionIndex];
    final qId = question['_id'] ?? question['id'];

    if (qId != null &&
        !token.startsWith('mock-') &&
        !widget.exam.id.startsWith('custom-')) {
      try {
        final payload = _answerPayload(question, qId, answer, status);
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

  Future<void> _submitExam() async {
    if (widget.exam.submissionStatus == 'SUBMITTED') return;
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';

    try {
      final violationsObj = {'tabSwitches': _violationsCount};
      _questionTimer?.cancel();

      if (_isRemotePracticeSession) {
        await context.read<ExamsRepository>().submitPracticeSession(
          token,
          widget.exam.id,
          {'timeSpentPerQuestion': _timeSpentPerQuestion},
        );
      } else {
        await context
            .read<ExamsRepository>()
            .submitExam(token, widget.exam.id, {
              'violations': violationsObj,
              'isAutoSubmit': _remainingSeconds <= 0,
              'timeSpentPerQuestion': _timeSpentPerQuestion,
            });
      }

      if (mounted) {
        _closeOwnDialogs();
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          const SnackBar(content: Text('Test submitted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        _closeOwnDialogs();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error submitting test: $e')));
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _confirmSubmit() async {
    if (_isSubmitting || !mounted) return;
    final answeredCount = _answers.length.clamp(0, _questions.length);
    final unansweredCount = (_questions.length - answeredCount).clamp(
      0,
      _questions.length,
    );
    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (ctx) => Theme(
        data: AppTheme.lightTheme,
        child: AlertDialog(
          title: const Text('Submit test?'),
          content: Text(
            'Answered: $answeredCount\n'
            'Unanswered: $unansweredCount\n\n'
            'You cannot change answers after submission.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Review'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    if (shouldSubmit == true) await _submitExam();
  }

  String _formatHtml(String? htmlString) {
    if (htmlString == null || htmlString.isEmpty) return '';
    final String domain = AppConfig.webUrl;
    return htmlString.replaceAll('src="/', 'src="$domain/');
  }

  String _getOptionHtml(Map<String, dynamic> opt) =>
      _formatHtml(optionHtml(opt));

  // Shared with the DPP player (question_html.dart): never strips "1."-"4.",
  // "(A)" or "A." from real content, and never splits options out of a
  // typed-answer question.
  Map<String, dynamic> _parseQuestionTextAndOptions(
    String rawQuestionText,
    List<Map<String, dynamic>> existingOptions, {
    String type = 'MCQ',
  }) =>
      parseQuestionTextAndOptions(rawQuestionText, existingOptions, type: type);

  Future<void> _handleExitOrPause(bool isSubmitted) async {
    if (isSubmitted) {
      Navigator.of(context).pop();
      return;
    }
    final String typeTitle = _isPractice ? 'Practice' : 'Test';
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => Theme(
        data: AppTheme.lightTheme,
        child: AlertDialog(
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
      ),
    );
    if ((shouldExit ?? false) && mounted) {
      Navigator.of(context).pop();
    }
  }

  // The test screen always looks like the real (white) NTA exam screen,
  // even when the rest of the app is in dark mode.
  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.lightTheme,
    child: Builder(builder: _buildPlayer),
  );

  Widget _buildPlayer(BuildContext context) {
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
          systemOverlayStyle: _examSystemUi,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final isAccessIssue =
          _errorMessage != null &&
          (_errorMessage!.toLowerCase().contains('access') ||
              _errorMessage!.toLowerCase().contains('plan') ||
              _errorMessage!.toLowerCase().contains('course') ||
              _errorMessage!.toLowerCase().contains('enroll') ||
              _errorMessage!.toLowerCase().contains('forbidden'));

      return Scaffold(
        appBar: AppBar(
          title: Text(widget.exam.title),
          leading: const BackButton(),
          systemOverlayStyle: _examSystemUi,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color:
                        (isAccessIssue
                                ? const Color(0xFFF59E0B)
                                : AppTheme.primary)
                            .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: PhosphorIcon(
                    isAccessIssue
                        ? PhosphorIcons.lockKey
                        : PhosphorIcons.newspaperClipping,
                    size: 48,
                    color: isAccessIssue
                        ? const Color(0xFFD97706)
                        : AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isAccessIssue ? 'Test Access Required' : 'No Questions Found',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  _errorMessage ??
                      'This exam paper does not have any questions configured yet. Please check back later or contact your instructor.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const PhosphorIcon(
                        PhosphorIcons.arrowLeft,
                        size: 16,
                      ),
                      label: const Text('Go Back'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _errorMessage = null;
                        });
                        _startExam();
                      },
                      icon: const PhosphorIcon(
                        PhosphorIcons.arrowsClockwise,
                        size: 16,
                      ),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final question = _questions[_currentQuestionIndex];
    final String rawQuestionText =
        question['questionText']?.toString() ?? 'Question';
    final questionType = question['type']?.toString() ?? 'MCQ';
    final List<Map<String, dynamic>> rawOptions =
        List<Map<String, dynamic>>.from(question['options'] ?? []);

    final parsedQuestion = _parseQuestionTextAndOptions(
      rawQuestionText,
      rawOptions,
      type: questionType,
    );
    final questionText = parsedQuestion['questionText'] as String;
    final options = List<Map<String, dynamic>>.from(
      parsedQuestion['options'] as List,
    );
    final imageValue =
        question['questionImageUrl'] ??
        question['imageUrl'] ??
        question['image'];
    // The server now also puts this picture into the question HTML; show the
    // separate field only when it is not there already.
    final String? imageUrl =
        imageValue is String &&
            imageValue.trim().isNotEmpty &&
            !questionText.contains(imageValue.trim())
        ? imageValue.trim()
        : null;

    final bool isSubmitted = widget.exam.submissionStatus == 'SUBMITTED';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _examSystemUi,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          if (_scaffoldKey.currentState?.isEndDrawerOpen == true) {
            Navigator.of(context).pop();
            return;
          }
          _handleExitOrPause(isSubmitted);
        },
        child: Scaffold(
          key: _scaffoldKey,
          endDrawer: _buildQuestionPalette(),
          appBar: AppBar(
            systemOverlayStyle: _examSystemUi,
            // "JEE Main Chapter Test: Limits" -> "Limits" on top, the series
            // name small underneath, so the bar never shows two bold lines.
            title: _ExamTitle(title: widget.exam.title),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => _handleExitOrPause(isSubmitted),
            ),
            actions: [
              if (_isPracticeOrDpp && !isSubmitted) ...[
                OutlinedButton.icon(
                  onPressed: () => _handleExitOrPause(isSubmitted),
                  icon: const Icon(
                    Icons.pause_circle_outline_rounded,
                    size: 16,
                  ),
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
                  onPressed: _isSubmitting ? null : _confirmSubmit,
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
                    'Submit Practice',
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
                // The camera preview floats over the question (draggable) and
                // takes no layout space, so questions are never pushed down.
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: SingleChildScrollView(
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
                                    color: AppTheme.primary.withValues(
                                      alpha: 0.1,
                                    ),
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
                                  Container(
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
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Normal text wraps to the screen width; only a display
                            // equation wider than the screen scrolls sideways.
                            MathHtmlRenderer(
                              key: ValueKey('q_text_$_currentQuestionIndex'),
                              htmlContent: _formatHtml(questionText),
                              baseFontSize: 16.0,
                            ),
                            if (imageUrl != null) ...[
                              const SizedBox(height: 12),
                              QuestionImage(url: imageUrl),
                            ],
                            const SizedBox(height: 24),
                            // Show option cards whenever the question has options,
                            // whatever its type; a typed box only when it has none.
                            if (options.isNotEmpty)
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

                                final String currentSaved =
                                    (_answers[_currentQuestionIndex] ?? '')
                                        .toString();
                                final bool isMulti =
                                    questionType.toUpperCase() ==
                                    'MULTIPLE_CORRECT';
                                final bool isSelected = isMulti
                                    ? splitMultiAnswer(
                                        currentSaved,
                                      ).contains(optId)
                                    : currentSaved.isNotEmpty &&
                                          (currentSaved == optId ||
                                              currentSaved ==
                                                  optIndex.toString() ||
                                              currentSaved.toUpperCase() ==
                                                  letter ||
                                              (opt['_id'] != null &&
                                                  currentSaved ==
                                                      opt['_id'].toString()) ||
                                              (opt['id'] != null &&
                                                  currentSaved ==
                                                      opt['id'].toString()));

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
                                      if (isMulti) {
                                        final picked = splitMultiAnswer(
                                          _answers[_currentQuestionIndex],
                                        );
                                        picked.contains(optId)
                                            ? picked.remove(optId)
                                            : picked.add(optId);
                                        if (picked.isEmpty) {
                                          _clearResponse();
                                        } else {
                                          _saveAnswer(
                                            _currentQuestionIndex,
                                            picked.join(kMultiAnswerSeparator),
                                          );
                                        }
                                      } else {
                                        _saveAnswer(
                                          _currentQuestionIndex,
                                          optId,
                                        );
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
                                                color: AppTheme.primary
                                                    .withValues(alpha: 0.08),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                                // Square badge hints "pick many".
                                                shape: isMulti
                                                    ? BoxShape.rectangle
                                                    : BoxShape.circle,
                                                borderRadius: isMulti
                                                    ? BorderRadius.circular(8)
                                                    : null,
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
                                                // Not interactive: a tap on the
                                                // formula selects the whole card.
                                                child: MathHtmlRenderer(
                                                  key: ValueKey(
                                                    'opt_${_currentQuestionIndex}_$optIndex',
                                                  ),
                                                  htmlContent: optHtml,
                                                  baseFontSize: 15.0,
                                                  interactive: false,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              })
                            else
                              TextField(
                                // Per-question key + controller: no carry-over (E4).
                                key: ValueKey(
                                  'answer_text_$_currentQuestionIndex',
                                ),
                                controller: _controllerFor(
                                  _currentQuestionIndex,
                                ),
                                maxLines: isNumericQuestionType(questionType)
                                    ? 1
                                    : 4,
                                minLines: 1,
                                keyboardType:
                                    isNumericQuestionType(questionType)
                                    ? const TextInputType.numberWithOptions(
                                        decimal: true,
                                        signed: true,
                                      )
                                    : TextInputType.multiline,
                                inputFormatters:
                                    isNumericQuestionType(questionType)
                                    ? [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'^-?\d*\.?\d*'),
                                        ),
                                      ]
                                    : null,
                                readOnly: isSubmitted,
                                decoration: InputDecoration(
                                  hintText: 'Type your answer here...',
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: AppTheme.primary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                onChanged: (val) => _onTextAnswerChanged(
                                  _currentQuestionIndex,
                                  val,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        htmlContent: _formatHtml(
                                          explanationText,
                                        ),
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
                    ),
                    if (_cameraController != null &&
                        _cameraController!.value.isInitialized)
                      _buildFloatingCamera(),
                  ],
                ),
              ),
              // Bottom Action Footer
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
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
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 16,
                                ),
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
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
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
                                if (_currentQuestionIndex <
                                    _questions.length - 1)
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
                                        : (_isSubmitting
                                              ? null
                                              : _confirmSubmit),
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
                                                : 'Submit Practice',
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
                                  ? () =>
                                        _goToQuestion(_currentQuestionIndex - 1)
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
                                if (_currentQuestionIndex <
                                    _questions.length - 1)
                                  OutlinedButton(
                                    onPressed: () => _goToQuestion(
                                      _currentQuestionIndex + 1,
                                    ),
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
                                      : (_isSubmitting ? null : _confirmSubmit),
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
      ),
    );
  }

  void _goToQuestion(int index) {
    if (index < 0 || index >= _questions.length) return;
    setState(() {
      _currentQuestionIndex = index;
      _visitedQuestions.add(index);
    });
  }

  /// Small camera preview floating above the content; drag to move it.
  Widget _buildFloatingCamera() {
    return Positioned(
      right: _cameraOffset.dx,
      bottom: _cameraOffset.dy,
      child: GestureDetector(
        onPanUpdate: (d) => setState(() {
          final size = MediaQuery.sizeOf(context);
          _cameraOffset = Offset(
            (_cameraOffset.dx - d.delta.dx).clamp(0, size.width - 60),
            (_cameraOffset.dy - d.delta.dy).clamp(0, size.height * 0.6),
          );
        }),
        child: Container(
          width: 52,
          height: 68,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CameraPreview(_cameraController!),
          ),
        ),
      ),
    );
  }

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
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
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
                    Colors.white,
                    'Not Visited',
                    textColor: Colors.black87,
                    outlined: true,
                  ),
                  _buildLegendItem(
                    Colors.grey.shade200,
                    'Not Answered',
                    textColor: Colors.black87,
                  ),
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

                          Color bgColor = _visitedQuestions.contains(qIndex)
                              ? Colors.grey.shade200
                              : Colors.white;
                          Color textColor = Colors.black87;

                          if (isMarked) {
                            bgColor = Colors.purple;
                            textColor = Colors.white;
                          } else if (isAnswered) {
                            bgColor = AppTheme.success;
                            textColor = Colors.white;
                          }

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _currentQuestionIndex = qIndex;
                                _visitedQuestions.add(qIndex);
                              });
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
                                    : bgColor == Colors.white
                                    ? Border.all(
                                        color: Colors.grey.shade400,
                                        width: 1.5,
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
    bool outlined = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            // White on a white drawer needs an outline to be seen.
            border: outlined
                ? Border.all(color: Colors.grey.shade500, width: 1.5)
                : null,
          ),
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

class _ExamTitle extends StatelessWidget {
  const _ExamTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final i = title.indexOf(':');
    final hasParts = i > 0 && i < title.length - 1;
    final main = hasParts ? title.substring(i + 1).trim() : title;
    final series = hasParts ? title.substring(0, i).trim() : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          main,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        if (series != null)
          Text(
            series,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
      ],
    );
  }
}
