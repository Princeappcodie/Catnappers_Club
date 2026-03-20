import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:alarm/alarm.dart';
import 'package:Catnappers_club/services/temp_cache_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'main.dart';
import 'models/authmanager.dart';
import 'session_state.dart'; // Import session state
import 'Subscription.dart'; // Import Subscription screen

class Playscreen extends StatefulWidget {
  final String trackTitle;
  final String trackPath;
  final String videoUrl;
  final int currentIndex;
  final int timerDuration;
  final String trackId;
  final String description;
  final String bestEnvironment;
  final bool isSubscribed;
  final bool isAlarmEnabled;
  final String? alarmSound;
  final String backgroundImage;

  const Playscreen({
    Key? key,
    required this.trackTitle,
    required this.trackPath,
    required this.videoUrl,
    required this.currentIndex,
    required this.timerDuration,
    required this.trackId,
    required this.description,
    required this.bestEnvironment,
    required this.isSubscribed,
    required this.backgroundImage,
    required this.isAlarmEnabled,
    required this.alarmSound,
  }) : super(key: key);

  @override
  State<Playscreen> createState() => _PlayscreenState();
}

class _PlayscreenState extends State<Playscreen> with TickerProviderStateMixin {
  bool isLiked = false;
  bool isPlaying = false;
  bool isLooping = false;
  int _selectedIndex = 0;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  late AnimationController _headerController;
  late Animation<double> _headerOpacity;
  late Animation<double> _headerScale;
  late AnimationController _playButtonController;
  late Animation<double> _playButtonScale;
  late AnimationController _contentController;
  late Animation<double> _contentOpacity;
  late Animation<Offset> _contentOffset;
  late AnimationController _bottomNavController;
  late Animation<Offset> _bottomNavOffset;
  late AnimationController _discController;
  final List<String> _downloadMessages = [
    "Preparing your soundscape...",
    "Warming up cozy vibes...",
    "Almost ready for relaxation...",
    "Downloading audio...",
  ];

  int _currentMessageIndex = 0;
  Timer? _messageTimer;

  final AudioPlayer audioPlayer = AudioPlayer();
  // final AudioPlayer _alarmPlayer = AudioPlayer(); //
  // final String _selectedAlarmSound = 'Alarm1.mp3'; //
  Timer? _timer;
  Timer? _previewTimer;
  int _remainingTime = 0;
  // StreamSubscription? _alarmSubscription; //

  late AnimationController _introFadeController;
  late Animation<double> _introFadeAnimation;

  bool _isGuestUser = false;
  bool _guestLoaded = false;
  bool _downloadDialogVisible = false;
  String? _currentStreamingUrl;
  VideoPlayerController? _introVideoController;
  bool _showIntroVideo = false;
  bool _introVideoInitialized = false;
  bool _timerStarted = false;
  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _playerStateSub;
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');

    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return "$hours:$minutes:$seconds";
    } else {
      return "$minutes:$seconds";
    }
  }

  @override
  void initState() {
    super.initState();
    _loadGuestStatus();
    _remainingTime = widget.timerDuration * 60;
    _showIntroVideo = !hasVideoPlayedThisSession;
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _headerOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeIn),
    );
    _headerScale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeOut),
    );

    _discController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );

    _playButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _playButtonScale = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _playButtonController, curve: Curves.easeInOut),
    );

    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _contentOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeIn),
    );
    _contentOffset = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );

    _introFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _introFadeAnimation = CurvedAnimation(
      parent: _introFadeController,
      curve: Curves.easeInOut,
    );

    _bottomNavController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _bottomNavOffset = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _bottomNavController, curve: Curves.bounceOut),
    );

    _headerController.forward();
    _contentController.forward();
    _bottomNavController.forward();
    // Alarm ring stream is handled globally in main.dart
    _checkIntroVideo();

  }
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  void _showSignupDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Sign up required'),
        content: const Text(
          'Sign up to unlock full access and start your 7-day free trial.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/signup');
            },
            child: const Text('Sign up'),
          ),
        ],
      ),
    );
  }
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  Future<void> _endSession() async {
    try {
      _timer?.cancel();
      _previewTimer?.cancel();

      await Alarm.stop(42);      // 🔔 Cancel scheduled alarm
      await audioPlayer.stop();  // 🎵 Stop meditation audio
    } catch (_) {}

    if (mounted) {
      setState(() {
        isPlaying = false;
        _timerStarted = false;
      });
    }
  }
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  Future<void> _loadGuestStatus() async {
    _isGuestUser = await AuthManager.isGuest();
    if (!mounted) return;
    setState(() {
      _guestLoaded = true;
    });
  }
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  void _onTimerFinished() {
    debugPrint('🔔 Timer finished - waiting for Alarm package to trigger ring');
    // Alarm package handles the ringing via ringStream
  }
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  Future<void> _pauseTimer() async {
    _timer?.cancel();        // stop UI timer
    await Alarm.stop(42);    // cancel scheduled alarm
  }
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  void _showDownloadDialog() {
    _downloadDialogVisible = true;
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Download",
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {

        int messageIndex = 0;
        Timer? dialogTimer;

        return StatefulBuilder(
          builder: (context, setStateDialog) {

            dialogTimer ??= Timer.periodic(
              const Duration(seconds: 2),
                  (_) {
                setStateDialog(() {
                  messageIndex =
                      (messageIndex + 1) % _downloadMessages.length;
                });
              },
            );

            return Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.8,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      SizedBox(
                        height: 140,
                        child: Image.asset(
                          "assets/take-it-easy-relax.gif",
                          fit: BoxFit.contain,
                        ),
                      ),

                      const SizedBox(height: 20),

                      const CircularProgressIndicator(color: Colors.white),

                      const SizedBox(height: 20),

                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        child: Text(
                          _downloadMessages[messageIndex],
                          key: ValueKey(messageIndex),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },

      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            ),
            child: child,
          ),
        );
      },
    );
  }
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  void _resumeTimer() async {
    if (_remainingTime <= 0) return;

    _timer?.cancel();

    // 🔔 schedule again with remaining time
    await _scheduleAlarm();

    debugPrint("▶ Timer resumed");

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;

      if (_remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
      } else {
        timer.cancel();

        // let the Alarm plugin handle ringing via background notification //

        try {
          await audioPlayer.stop();
        } catch (_) {}

        if (!mounted) return;

        setState(() {
          isPlaying = false;
          _timerStarted = false;
        });

        _discController.stop();
        _playButtonController.stop();
        _playButtonController.reset();

        debugPrint("⏰ Timer finished");
      }
    });
  }
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  void _startTimerIfNeeded() async {
    if (_timerStarted) return;

    _timerStarted = true;
    _remainingTime = widget.timerDuration * 60;

    await _scheduleAlarm(); // schedule once
    _startTimer();
  }


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  void _onAudioAutoStarted() {
    if (!mounted) return;

    setState(() {
      isPlaying = true;
    });

    // ✅ START DISC ROTATION HERE
    if (!_discController.isAnimating) {
      _discController.repeat();
    }

    _playButtonController.repeat(reverse: true);
  }
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  Future<void> _checkIntroVideo() async {
    debugPrint("Checking intro video. hasVideoPlayedThisSession: $hasVideoPlayedThisSession");

    if (hasVideoPlayedThisSession) {
      _startPlayback();
      return;
    }

    _introVideoController = VideoPlayerController.asset(
      'assets/newIntro.mp4',
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );

    try {
      await _introVideoController!.initialize();
      _introVideoController!.setVolume(1.0);

      if (!mounted) return;

      setState(() {
        _introVideoInitialized = true;
        _showIntroVideo = true;
      });

      _introFadeController.forward(from: 0);
      _introVideoController!.addListener(_introVideoListener);
      await _introVideoController!.play();
    } catch (e) {
      debugPrint("Error initializing intro video: $e");
      if (!mounted) return;
      _startPlayback();
    }
  }
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  Future<void> _fadeOutAndCloseIntro() async {
    if (!_showIntroVideo) return;
    await _introFadeController.reverse();
    if (!mounted) return;
    _introVideoController?.removeListener(_introVideoListener);
    _introVideoController?.pause();

    setState(() {
      _showIntroVideo = false;
    });

    _startPlayback();
  }

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  void _introVideoListener() {
    final controller = _introVideoController;
    if (controller == null || !controller.value.isInitialized) return;

    final value = controller.value;

    if (!value.isPlaying &&
        value.position >= value.duration &&
        value.duration > Duration.zero &&
        _showIntroVideo) {
      _fadeOutAndCloseIntro();
    }
  }
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  void _startPlayback() {
    if (!mounted) return;

    setState(() {
      _showIntroVideo = false;
      _introVideoInitialized = false;
    });

    if (_introFadeController.isAnimating || _introFadeController.value != 0) {
      _introFadeController.reset();
    }

    setupAudio();

  }
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  void _finishIntroVideo() {
    if (!mounted || !_showIntroVideo) return;

    _introVideoController?.removeListener(_introVideoListener);
    _introVideoController?.pause();

    setState(() {
      _showIntroVideo = false;
    });

    _startPlayback();
  }
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  void _skipIntro() {
    _fadeOutAndCloseIntro();
  }
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  Future<void> _dontShowAgain() async {
    hasVideoPlayedThisSession = true;   // ✅ Mark intro as watched for this session
    await _fadeOutAndCloseIntro();
  }
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  Future<void> _scheduleAlarm() async {
    if (!widget.isAlarmEnabled) return;
    if (_remainingTime <= 0) return;

    await Alarm.stop(42);

    String soundAsset = widget.alarmSound ?? 'Alarm1.mp3';
    if (!soundAsset.startsWith('assets/')) {
      soundAsset = 'assets/$soundAsset';
    }
    final audioPath = await _materializeAlarmAsset(soundAsset);

    final alarmSettings = AlarmSettings(
      id: 42,
      dateTime: DateTime.now().add(Duration(seconds: _remainingTime + 1)),

      assetAudioPath: soundAsset,
      loopAudio: true,
      vibrate: true,
      volume: 1.0,
      fadeDuration: 3.0,
      warningNotificationOnKill: Platform.isIOS,
      androidFullScreenIntent: true,
      notificationSettings: const NotificationSettings(
        title: 'Nap Complete 🌙',
        body: 'Your nap timer has finished.',
        stopButton: 'Stop',
      ),
    );

    await Alarm.set(alarmSettings: alarmSettings);

    debugPrint("🔔 Alarm scheduled for $_remainingTime seconds");
  }
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  Future<String> _materializeAlarmAsset(String assetPath) async {
    try {
      final bytes = await rootBundle.load(assetPath);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/alarm_ringtone.mp3');
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      return file.path;
    } catch (_) {
      return assetPath;
    }
  }

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  void _startTimer() async {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;

      if (_remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
      } else {
        timer.cancel();
        // let the Alarm plugin handle ringing via background notification

        try {
          await audioPlayer.stop();
        } catch (e) {}


        setState(() {
          isPlaying = false;
          _timerStarted = false;
        });

        _discController.stop();
        _playButtonController.stop();
        _playButtonController.reset();
      }
    });
  }

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  void showSubscriptionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.8),
          title: const Text(
            'Subscribe Now',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Subscribe to access full tracks and more features!',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Subscription()),
                );
              },
              child: const Text(
                'Subscribe',
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Later',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        );
      },
    );
  }

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _bottomNavController.reverse().then((_) {
      _bottomNavController.forward();
      switch (index) {
        case 0:
          Navigator.pushReplacementNamed(context, '/home');
          break;
        case 1:
          Navigator.pushReplacementNamed(context, '/timer');
          break;
        case 2:
          Navigator.pushReplacementNamed(context, '/settings');
          break;
      }
    });
  }
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  @override
  void dispose() {
    // STOP animations FIRST
    _discController.stop();
    _playButtonController.stop();
    _headerController.stop();
    _contentController.stop();
    _bottomNavController.stop();
    _introFadeController.stop();
    _discController.dispose();
    _playButtonController.dispose();
    _headerController.dispose();
    _contentController.dispose();
    _bottomNavController.dispose();
    _introFadeController.dispose();
    _timer?.cancel();
    _previewTimer?.cancel();
    _durationSub?.cancel();
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    audioPlayer.dispose();
    _introVideoController?.dispose();

    super.dispose();
  }

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  Future<bool> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  void _showCustomSnackBar(String message, {bool isError = false}) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  void _startGuestPreview() {
    _previewTimer?.cancel();

    _previewTimer = Timer(const Duration(seconds: 30), () async {
      debugPrint('⛔ Guest preview / trial ended');

      try {
        await audioPlayer.stop();
      } catch (_) {}

      _timer?.cancel();

      if (!mounted) return;

      setState(() {
        isPlaying = false;
        _timerStarted = false;
        _playButtonController.stop();
        _playButtonController.reset();
      });
      _showSignupDialog();
    });
  }
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  Future<void> setupAudio() async {
    try {
      final rawPath = widget.trackPath.trim().replaceAll('"', '');
      debugPrint('Audio setup: path=$rawPath');

      final isLocal =
          rawPath.startsWith('/') || rawPath.startsWith('file://');

      await audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);

      /// =========================
      /// 🔹 ATTACH PLAYER STATE LISTENER FIRST
      /// =========================
      _playerStateSub?.cancel();
      _playerStateSub =
          audioPlayer.onPlayerStateChanged.listen((state) async {
            if (!mounted) return;

            final playing = state == PlayerState.playing;

            setState(() {
              isPlaying = playing;
            });

            if (playing) {

              /// ✅ CLOSE DOWNLOAD DIALOG
              if (_downloadDialogVisible) {
                if (Navigator.of(context, rootNavigator: true).canPop()) {
                  Navigator.of(context, rootNavigator: true).pop();
                }
                _downloadDialogVisible = false;

                /// 🔥 START BACKGROUND CACHING
                if (_currentStreamingUrl != null) {
                  Future(() async {
                    await TempCacheService
                        .downloadAndCache(_currentStreamingUrl!);
                  });
                  _currentStreamingUrl = null;
                }
              }

              _onAudioAutoStarted();

              /// 🔥 FIXED TIMER LOGIC 🔥 ///
              if (!_timerStarted) {
                _startTimerIfNeeded();          // first time //
              } else if (_remainingTime > 0) {
                await _scheduleAlarm();         // reschedule alarm //
                _resumeTimer();                 // resume from remaining time //
              }

              if (_isGuestUser || !widget.isSubscribed) {
                _startGuestPreview();
              }

            } else {
              _discController.stop();
              _playButtonController.stop();
              _playButtonController.reset();
              _previewTimer?.cancel();

              if (state == PlayerState.paused) {
                if (_remainingTime > 0) {
                  await _pauseTimer();   // pause timer properly //
                }
              }

              if (state == PlayerState.stopped ||
                  state == PlayerState.completed) {
                _timer?.cancel();
              }
            }
          });

      /// =========================
      /// 🔹 LOCAL FILE
      /// =========================
      if (isLocal) {
        var localPath = rawPath;
        if (localPath.startsWith('file://')) {
          localPath = localPath.substring(7);
        }

        await audioPlayer.setReleaseMode(
            widget.isSubscribed ? ReleaseMode.loop : ReleaseMode.stop);

        await audioPlayer.play(DeviceFileSource(localPath));
      }

      /// =========================
      /// 🔹 REMOTE FILE
      /// =========================
      else {
        var url = rawPath;

        if (url.startsWith('http://')) {
          url = 'https://${url.substring(7)}';
        }

        if (!await _checkConnectivity()) {
          if (mounted) {
            _showCustomSnackBar('No internet connection', isError: true);
          }
          return;
        }

        final existingPath =
        await TempCacheService.getExistingCachedFile(url);

        await audioPlayer.setReleaseMode(
            widget.isSubscribed ? ReleaseMode.loop : ReleaseMode.stop);

        if (existingPath != null) {
          /// ✅ Play from cache
          debugPrint('📂 Playing from cache');
          await audioPlayer.play(DeviceFileSource(existingPath));
        } else {
          /// 🌐 Stream immediately
          debugPrint('🌐 Streaming immediately');

          _currentStreamingUrl = url;
          _downloadDialogVisible = true;
          _showDownloadDialog();

          await audioPlayer.play(UrlSource(url)).timeout(
            const Duration(seconds: 25),
            onTimeout: () {
              throw TimeoutException('Playback connect timeout (25s)');
            },
          );
        }
      }

      if (!mounted) return;

      /// =========================
      /// 🔹 DURATION & POSITION LISTENERS
      /// =========================

      _durationSub?.cancel();
      _positionSub?.cancel();

      _durationSub =
          audioPlayer.onDurationChanged.listen((newDuration) {
            if (!mounted) return;
            setState(() => _duration = newDuration);
          });

      _positionSub =
          audioPlayer.onPositionChanged.listen((newPosition) {
            if (!mounted) return;
            setState(() => _position = newPosition);
          });

      debugPrint('✅ Audio setup complete');

    } catch (e) {
      debugPrint('❌ Audio error: $e');

      if (mounted) {
        _showCustomSnackBar(
            'Failed to play audio. Please try again.',
            isError: true);

        if (_downloadDialogVisible &&
            Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
          _downloadDialogVisible = false;
        }
      }
    }
  }
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = MediaQuery.of(context).size;
        final screenHeight = constraints.maxHeight;
        final screenWidth = constraints.maxWidth;
        final contentWidget = FadeTransition(
          opacity: _contentOpacity,
          child: SlideTransition(
            position: _contentOffset,
            child: Column(
              children: [
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.only(left: 12, right: 24),
                  child: Text(
                    widget.trackTitle,
                    textAlign: TextAlign.left,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 1.2,
                      height: 1.35,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          offset: Offset(0, 2),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

                const SizedBox(height: 20),
                /// 🔥 Rotating Circular Disc
                RotationTransition(
                  turns: _discController,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.6),
                          blurRadius: 25,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [

                          /// 🎵 Outer Vinyl Disc (Black Background)
                          Container(
                            width: 250,
                            height: 250,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.red.withOpacity(0.3),
                                  Colors.green.withOpacity(0.3),
                                  Colors.blue.withOpacity(0.3),
                                ],
                              ),
                            ),
                          ),

                          /// 🖼 Local Album Image (FROM ASSETS)
                          Container(
                            width: 210,
                            height: 210,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: DecorationImage(
                                image: AssetImage('assets/sleeping-cat-3.jpeg'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ScaleTransition(
                      scale: _playButtonScale,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          shape: BoxShape.circle,
                          boxShadow: isPlaying
                              ? [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                              : [],
                        ),
                        child: IconButton(
                            icon: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size: 35,
                            ),
                            onPressed: () async {
                              if (isPlaying) {
                                await audioPlayer.pause();
                                // _discController.stop();
                              } else {
                                await audioPlayer.resume();
                                // _discController.repeat(); //
                              }
                            }
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.shade900.withOpacity(0.3),
                            Colors.purple.shade900.withOpacity(0.3),
                            Colors.amber.shade300.withOpacity(0.2),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.amber.shade200.withOpacity(0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    ShaderMask(
                                      shaderCallback: (bounds) => LinearGradient(
                                        colors: [Colors.amber.shade200, Colors.white],
                                      ).createShader(bounds),
                                      child: const Icon(
                                        Icons.music_note,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Audio: ${widget.trackTitle}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.9,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ShaderMask(
                                      shaderCallback: (bounds) => LinearGradient(
                                        colors: [Colors.amber.shade200, Colors.white],
                                      ).createShader(bounds),
                                      child: const Icon(
                                        Icons.volume_up,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Best Environment: ${widget.bestEnvironment}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ShaderMask(
                                      shaderCallback: (bounds) => LinearGradient(
                                        colors: [Colors.amber.shade200, Colors.white],
                                      ).createShader(bounds),
                                      child: const Icon(
                                        Icons.park,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Description: ${widget.description}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        return Scaffold(
          extendBody: true,
          body: Stack(
            children: [
              Container(
                width: screenWidth,
                height: screenHeight,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(widget.backgroundImage),
                    fit: BoxFit.cover,
                    colorFilter: const ColorFilter.mode(
                      Color.fromRGBO(0, 0, 0, 0.5),
                      BlendMode.darken,
                    ),
                  ),
                ),
                child: SafeArea(
                  child:SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        FadeTransition(
                          opacity: _headerOpacity,
                          child: ScaleTransition(
                            scale: _headerScale,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                                    onPressed: () async {
                                      await _endSession();
                                      Navigator.pop(context);
                                    },
                                  ),
                                  if (!_isGuestUser &&
                                      (_timerStarted || _remainingTime < widget.timerDuration * 60))
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.timer, color: Colors.white70, size: 16),
                                          const SizedBox(width: 6),
                                          Text(
                                            _formatDuration(Duration(seconds: _remainingTime)),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontFeatures: [FontFeature.tabularFigures()],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        contentWidget,
                      ],
                    ),
                  ),
                ),
              ),
              if (_showIntroVideo)
                Positioned.fill(
                  child: FadeTransition(
                    opacity: _introFadeAnimation,
                    child: Container(
                      color: Colors.black.withOpacity(0.9),
                      child: (_introVideoInitialized && _introVideoController != null)
                          ? Stack(
                        children: [
                          SizedBox(
                            width: MediaQuery.of(context).size.width,
                            height: MediaQuery.of(context).size.height,
                            child: AspectRatio(
                              aspectRatio: MediaQuery.of(context).size.width /
                                  MediaQuery.of(context).size.height,
                              child: VideoPlayer(_introVideoController!),
                            ),
                          ),
                          Positioned(
                            bottom: 80,
                            left: 20,
                            right: 20,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: _skipIntro,
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    backgroundColor: Colors.white.withOpacity(0.15),
                                  ),
                                  child: const Text(
                                    'Skip',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                ElevatedButton(
                                  onPressed: _dontShowAgain,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    elevation: 6,
                                    shadowColor: Colors.black45,
                                    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: const Text(
                                    "Don't show again",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                          : const Center(child: CircularProgressIndicator(color: Colors.white)),
                    ),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: ( _showIntroVideo)
              ? null
              : SlideTransition(
            position: _bottomNavOffset,
            child: Container(
              margin: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05,
                vertical: screenHeight * 0.02,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Theme(
                data: ThemeData(
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                ),
                child: BottomNavigationBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.home),
                      label: 'Home',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.timer),
                      label: 'Timer',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.settings),
                      label: 'Settings',
                    ),
                  ],
                  currentIndex: _selectedIndex,
                  selectedItemColor: Colors.white,
                  unselectedItemColor: Colors.white.withOpacity(0.5),
                  type: BottomNavigationBarType.fixed,
                  showSelectedLabels: true,
                  showUnselectedLabels: true,
                  selectedIconTheme: const IconThemeData(size: 28),
                  unselectedIconTheme: const IconThemeData(size: 24),
                  onTap: _onItemTapped,
                  enableFeedback: false,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}