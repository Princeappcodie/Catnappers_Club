import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:Catnappers/services/temp_cache_service.dart';
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
  final bool isSubscribed; // Added parameter
// 🔔 Alarm config passed from Home
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


    // 🔔 Alarm
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
  late AnimationController _videoControllerAnimation;
  late Animation<Offset> _videoOffset;
  late AnimationController _playButtonController;
  late Animation<double> _playButtonScale;
  late AnimationController _contentController;
  late Animation<double> _contentOpacity;
  late Animation<Offset> _contentOffset;
  late AnimationController _bottomNavController;
  late Animation<Offset> _bottomNavOffset;
  final AudioPlayer audioPlayer = AudioPlayer();
  final AudioPlayer _alarmPlayer = AudioPlayer(); // Added for alarm sound
  final String _selectedAlarmSound = 'alarming1.mp3'; // Default alarm sound
  bool _alarmTriggered = false; // Added for alarm state
  Timer? _timer;
  Timer? _previewTimer; // Timer for 30-second preview
  int _remainingTime = 0;
  late VideoPlayerController _videoController;
  bool _videoInitialized = false;
  bool _isFullScreen = false;

  late AnimationController _introFadeController;
  late Animation<double> _introFadeAnimation;





  // Intro Video State
  VideoPlayerController? _introVideoController;
  bool _showIntroVideo = false;
  bool _introVideoInitialized = false;
  bool _timerStarted = false;


  @override
  void initState() {
    super.initState();
    _remainingTime = widget.timerDuration * 60;  // Converting minutes to seconds //

    // Determine if we should show intro video
    _showIntroVideo = !hasVideoPlayedThisSession;

    // Check for intro video before starting playback
    _checkIntroVideo();

    // Initialize animation controllers //
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

    _videoControllerAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _videoOffset = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _videoControllerAnimation, curve: Curves.easeOut),
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

    // Start animations
    _headerController.forward();
    _videoControllerAnimation.forward();
    _contentController.forward();
    _bottomNavController.forward();
    if (isPlaying) {
      _playButtonController.repeat(reverse: true);
    }
  }
  void _onTimerFinished() {
    debugPrint('🔔 Alarm trigger check — enabled=${widget.isAlarmEnabled}, sound=${widget.alarmSound}');

    if (widget.isAlarmEnabled) {
      // Use passed sound or fallback to default
      final soundToPlay = widget.alarmSound ?? _selectedAlarmSound;
      _playAlarm(soundToPlay);
    }
  }
///////////////////////////////////////////////////////////////////////////////////////
  void _startTimerIfNeeded() {
    if (_timerStarted) return;

    _timerStarted = true;
    _remainingTime = widget.timerDuration * 60;

    debugPrint('⏱ Timer auto-started with audio');
    _startTimer();
  }
////////////////////////////////////////////////////////////////////////////////////////
  void _onAudioAutoStarted() {
    if (!mounted) return;

    setState(() {
      isPlaying = true;
    });

    _playButtonController.repeat(reverse: true);
  }
///////////////////////////////////////////////////////////////////////////////////////////

  Future<void> _checkIntroVideo() async {
    debugPrint(
        "Checking intro video. hasVideoPlayedThisSession: $hasVideoPlayedThisSession");

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

      // 🔥 Fade IN intro
      _introFadeController.forward(from: 0);

      _introVideoController!.addListener(_introVideoListener);
      await _introVideoController!.play();
    } catch (e) {
      debugPrint("Error initializing intro video: $e");

      if (!mounted) return;
      _startPlayback();
    }
  }


  Future<void> _fadeOutAndCloseIntro() async {
    if (!_showIntroVideo) return;

    await _introFadeController.reverse(); // 🔥 FADE OUT

    if (!mounted) return;

    _introVideoController?.removeListener(_introVideoListener);
    _introVideoController?.pause();

    setState(() {
      _showIntroVideo = false;
    });

    _startPlayback();
  }

  void _introVideoListener() {
    final controller = _introVideoController;
    if (controller == null || !controller.value.isInitialized) return;

    final value = controller.value;

    // Prevent multiple triggers
    if (!value.isPlaying &&
        value.position >= value.duration &&
        value.duration > Duration.zero &&
        _showIntroVideo) {
      _fadeOutAndCloseIntro();
    }
  }


  void _startPlayback() {
    if (!mounted) return;

    // Ensure intro is fully hidden
    setState(() {
      _showIntroVideo = false;
      _introVideoInitialized = false;
    });

    // Reset fade controller for next time
    if (_introFadeController.isAnimating ||
        _introFadeController.value != 0) {
      _introFadeController.reset();
    }

    setupAudio();
    _initializeVideo();
  }


  void _finishIntroVideo() {
    if (!mounted || !_showIntroVideo) return;

    _introVideoController?.removeListener(_introVideoListener);
    _introVideoController?.pause();

    setState(() {
      _showIntroVideo = false;
    });

    _startPlayback();
  }

  void _skipIntro() {
    _fadeOutAndCloseIntro();
  }

  Future<void> _dontShowAgain() async {
    hasVideoPlayedThisSession = true;
    await _fadeOutAndCloseIntro();
  }


  Future<void> _initializeVideo() async {
    String url = widget.videoUrl.trim().replaceAll('"', '');

    if (url.isEmpty) {
      print("Invalid URL for video");
      await _initAssetFallback();
      return;
    }

    final isLocal = url.startsWith('/') || url.startsWith('file://');
    if (isLocal) {
      try {
        var localPath = url;
        if (localPath.startsWith('file://')) {
          localPath = localPath.substring(7);
        }
        _videoController = VideoPlayerController.file(File(localPath),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
        await _videoController.initialize();
        _videoController.setVolume(0.0);
        _videoController.setLooping(true);
        if (mounted) {
          setState(() {
            _videoInitialized = true;
          });
          _videoController.play();
        }
        return;
      } catch (e) {
        print("Error initializing local video: $e");
        await _initAssetFallback();
        return;
      }
    }

    if (!await _checkConnectivity()) {
      await _initAssetFallback();
      return;
    }

    if (url.startsWith('http://')) {
      url = 'https://' + url.substring(7);
    }

    try {
      // 📥 Cache Video Logic
      debugPrint('Downloading/Caching video for smooth playback: $url');
      String playPath = url;
      bool isCached = false;

      try {
        final cachedPath = await TempCacheService.getCachedFilePath(url);
        if (cachedPath != url) {
          playPath = cachedPath;
          isCached = true;
        }
      } catch (e) {
        debugPrint('Video caching failed: $e');
      }

      if (isCached) {
         debugPrint('🎬 Playing video from cache: $playPath');
         _videoController = VideoPlayerController.file(
           File(playPath),
           videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
         );
      } else {
         // Fallback to network if cache failed
         debugPrint('🎬 Playing video from network: $playPath');
         _videoController = VideoPlayerController.networkUrl(
            Uri.parse(playPath),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
         );
      }

      await _videoController.initialize();
      _videoController.setVolume(0.0);
      _videoController.setLooping(true);
      if (mounted) {
        setState(() {
          _videoInitialized = true;
        });
        _videoController.play();
      }
    } catch (e) {
      print("Error initializing video: $e");
      await _initAssetFallback();
    }
  }

  Future<void> _initAssetFallback() async {
    try {
      _videoController = VideoPlayerController.asset('assets/newIntro.mp4');
      await _videoController.initialize();
      _videoController.setVolume(0.0);
      _videoController.setLooping(true);
      if (mounted) {
        setState(() {
          _videoInitialized = true;
        });
        _videoController.play();
      }
    } catch (e) {
      print('Failed to init asset fallback: $e');
    }
  }
  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;

      if (_remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
      } else {
        timer.cancel();

        debugPrint('⏰ Timer finished');

        // 🔊 STOP AUDIO (outside setState)
        try {
          await audioPlayer.pause();
          await audioPlayer.stop();
        } catch (e) {
          debugPrint('Error stopping audio: $e');
        }

        if (!mounted) return;

        setState(() {
          isPlaying = false;
          _timerStarted = false;
          _playButtonController.stop();
          _playButtonController.reset();
        });

        // 🔔 Trigger alarm
        _onTimerFinished();
      }
    });
  }

  void _playAlarm(String alarmSound) async {
    debugPrint('🔔 Playing Alarm: $alarmSound');

    if (!_alarmTriggered) {
      setState(() {
        _alarmTriggered = true;
      });

      try {
        // 🔊 Force Max Volume
        await _alarmPlayer.setVolume(1.0);

        // Set alarm to loop
        await _alarmPlayer.setReleaseMode(ReleaseMode.loop);

        // Ensure path is clean for AssetSource
        String cleanPath = alarmSound;
        if (cleanPath.startsWith('assets/')) {
          cleanPath = cleanPath.substring(7);
        }
        debugPrint('🔔 Asset Source: $cleanPath');

        await _alarmPlayer.play(AssetSource(cleanPath));


        // Show dialog box with stop button
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              contentPadding: EdgeInsets.zero,
              content: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.55),
                          Colors.grey.shade200.withOpacity(0.45),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.6),
                        width: 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 🔔 Icon
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Colors.orangeAccent.shade200, Colors.amber.shade300],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.35),
                                blurRadius: 14,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.alarm,
                            size: 28,
                            color: Colors.black87,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 💤 Title
                        const Text(
                          'Nap Complete 🌙',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // ✨ Message
                        Text(
                          'You took a mindful break.\nYour body & mind thank you ✨',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.7),
                            fontSize: 15,
                            height: 1.45,
                            fontWeight: FontWeight.w400,
                          ),
                        ),

                        const SizedBox(height: 22),

                        // 🛑 Stop Button
                        SizedBox(
                          width: double.infinity,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFE84141), // Orange
                                  Color(0xFFFFC107), // Yellow
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.45),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _stopAlarm();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'STOP ALARM',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
        // Set 1-minute timer to automatically stop alarm //
        Future.delayed(Duration(minutes: 1), () {
          if (_alarmTriggered) {
            _stopAlarm();
            // Close dialog if it's still open
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        });
      } catch (e) {
        print('Error playing alarm: $e');
        setState(() {
          _alarmTriggered = false;
        });
      }
    }
  }

  void _stopAlarm() {
    _alarmPlayer.stop();
    setState(() {
      _alarmTriggered = false;
    });
  }

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

  @override
  void dispose() {
    _introVideoController?.dispose();
    if (_videoInitialized) {
      _videoController.dispose();
    }
    _timer?.cancel();
    _previewTimer?.cancel();
    audioPlayer.dispose();
    _alarmPlayer.dispose(); // Added to dispose alarm player
    _headerController.dispose();
    _videoControllerAnimation.dispose();
    _playButtonController.dispose();
    _contentController.dispose();
    _bottomNavController.dispose();
    _introFadeController.dispose();

    super.dispose();
  }

  Future<bool> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }

  void _showCustomSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        content: Stack(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isError
                      ? [Colors.red.shade800, Colors.redAccent.shade200]
                      : [Colors.indigo.shade600, Colors.blueAccent.shade200],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: isError
                        ? Colors.red.withOpacity(0.3)
                        : Colors.blue.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isError ? Icons.error_outline_rounded : Icons.music_note_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isError ? 'Oops!' : 'Just a Moment',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ],
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

  Future<void> setupAudio() async {
    try {
      final rawPath = widget.trackPath.trim().replaceAll('"', '');
      debugPrint('Audio setup: path=$rawPath');
      final isLocal = rawPath.startsWith('/') || rawPath.startsWith('file://');
      debugPrint('Audio source: ${isLocal ? 'local' : 'remote'}');
      await audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);

      if (isLocal) {
        var localPath = rawPath;
        if (localPath.startsWith('file://')) {
          localPath = localPath.substring(7);
        }
        debugPrint('Audio play request (local): $localPath');
        await audioPlayer.setReleaseMode(ReleaseMode.loop);
        await audioPlayer.play(DeviceFileSource(localPath));
        _startTimerIfNeeded();
        _onAudioAutoStarted();
      } else {
        var url = rawPath;
        if (url.startsWith('http://')) {
          url = 'https://' + url.substring(7);
          debugPrint('Audio URL upgraded to HTTPS: $url');
        }
        if (!await _checkConnectivity()) {
          debugPrint('Audio not playing: no internet connectivity');
          if (mounted) {
            _showCustomSnackBar('No internet connection', isError: true);
          }
          return;
        }

        // 📥 Cache Audio Logic
        String playPath = url;
        bool isCached = false;
        try {
          if (mounted) {
            _showCustomSnackBar('Buffering audio for smooth playback... ⏳');
          }
          final cachedPath = await TempCacheService.getCachedFilePath(url);
          if (cachedPath != url) {
            playPath = cachedPath;
            isCached = true;
          }
        } catch (e) {
          debugPrint('⚠️ Caching failed, falling back to streaming: $e');
        }

        if (widget.isSubscribed) {
          debugPrint('Audio playing in full mode (loop)');
          await audioPlayer.setReleaseMode(ReleaseMode.loop);

          if (isCached) {
             debugPrint('📂 Playing from cache: $playPath');
             await audioPlayer.play(DeviceFileSource(playPath));
             _onAudioAutoStarted();
             _startTimerIfNeeded();


          } else {
             await audioPlayer.play(UrlSource(playPath)).timeout(const Duration(seconds: 25), onTimeout: () {
              throw TimeoutException('Playback connect timeout (25s)');
             });
          }
        } else {
          debugPrint('Audio playing in preview mode (30s)');
          await audioPlayer.setReleaseMode(ReleaseMode.stop);

          if (isCached) {
             debugPrint('📂 Playing from cache (preview): $playPath');
             await audioPlayer.play(DeviceFileSource(playPath));
             _onAudioAutoStarted();
             _startTimerIfNeeded();

          } else {
             await audioPlayer.play(UrlSource(playPath)).timeout(const Duration(seconds: 25), onTimeout: () {
               throw TimeoutException('Playback connect timeout (25s)');
             });
          }
        }
      }

      if (!mounted) return;
      debugPrint('Audio setup complete');

      audioPlayer.onDurationChanged.listen((newDuration) {
        if (!mounted) return;
        setState(() {
          _duration = newDuration;
        });
      });

      audioPlayer.onPositionChanged.listen((newPosition) {
        if (!mounted) return;
        setState(() {
          _position = newPosition;
        });
      });

      audioPlayer.onPlayerStateChanged.listen((state) {
        if (!mounted) return;

        debugPrint('Audio player state changed: $state');
        final playing = state == PlayerState.playing;

        setState(() {
          isPlaying = playing;

          if (playing) {
            _playButtonController.repeat(reverse: true);

            // if (!_timerStarted) {
            //   _timerStarted = true;
            //
            //   // 🔑 RESET TIMER HERE (CRITICAL)
            //   _remainingTime = widget.timerDuration * 60;
            //
            //   debugPrint('⏱ Timer started: $_remainingTime seconds');
            //
            //   _startTimer();
            // }

            if (!widget.isSubscribed) {
              _previewTimer?.cancel();
              _previewTimer = Timer(const Duration(seconds: 30), () {
                debugPrint('Audio preview ended: stopping after 30 seconds');
                audioPlayer.stop();
                setState(() {
                  isPlaying = false;
                  _playButtonController.stop();
                  _playButtonController.reset();
                });
                showSubscriptionDialog();
              });
            } else {
              _previewTimer?.cancel();
            }
          }

          else {
            _playButtonController.stop();
            _playButtonController.reset();
            debugPrint('Audio state: not playing ($state)');
            _previewTimer?.cancel();
          }
        });
      });

    } catch (e) {
      debugPrint('Audio not playing: error $e');
      if (mounted) {
        _showCustomSnackBar('Failed to play audio: $e', isError: true);
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = MediaQuery.of(context).size;
        final screenHeight = constraints.maxHeight;
        final screenWidth = constraints.maxWidth;

        final videoContainer = AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          width: _isFullScreen ? screenWidth : 370,
          height: _isFullScreen ? screenHeight : 240,
          decoration: BoxDecoration(
            color: _isFullScreen ? Colors.black : Colors.white.withOpacity(0.2),
            borderRadius: _isFullScreen ? BorderRadius.zero : BorderRadius.circular(10),
            border: _isFullScreen
                ? null
                : Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: _isFullScreen
                ? []
                : [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: _isFullScreen ? BorderRadius.zero : BorderRadius.circular(15),
                child: _videoInitialized
                    ? SlideTransition(
                  position: _videoOffset,
                  child: VideoPlayer(_videoController),
                )
                    : const Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
              Positioned(
                bottom: 19,
                right: 8,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isFullScreen = !_isFullScreen;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        final contentWidget = FadeTransition(
          opacity: _contentOpacity,
          child: SlideTransition(
            position: _contentOffset,
            child: Column(
              children: [
                const SizedBox(height: 10),
                // Centered Track Title - Beautiful & Dynamic //
                Padding(
                  padding: const EdgeInsets.only(left: 12, right: 24),
                  child: Text(
                    widget.trackTitle,
                    textAlign: TextAlign.left,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,            // ← Fixed: was black, now visible on dark bg
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
                const SizedBox(height: 10),
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
                              _previewTimer?.cancel();
                              _timer?.cancel(); // ⏸ PAUSE TIMER HERE
                            }
                            else {
                              await audioPlayer.resume();
                              _startTimer(); // ▶️ RESUME TIMER (DO NOT RESET)
                            }

                          },
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
                  image: _isFullScreen
                      ? null
                      : DecorationImage(
                    image: AssetImage(widget.backgroundImage), // ✅ dynamic
                    fit: BoxFit.cover,
                    colorFilter: const ColorFilter.mode(
                      Color.fromRGBO(0, 0, 0, 0.5),
                      BlendMode.darken,
                    ),
                  ),
                ),

                child: SafeArea(
                  child: _isFullScreen
                      ? videoContainer
                      : SingleChildScrollView(
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
                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
                                        ),
                                        // ⏱ Timer Display
                                        if (_timerStarted || _remainingTime < widget.timerDuration * 60)
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
                              videoContainer,
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
                                      MediaQuery.of(context).size.height, // 🔑 SCREEN RATIO
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
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        // ⏭ Skip Button (Secondary)
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

                                        // ⭐ Don't Show Again (Primary)
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
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.6,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )

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
          bottomNavigationBar: (_isFullScreen || _showIntroVideo)
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