import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:Catnappers_club/playscreen.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:audio_session/audio_session.dart';
import 'Alarm.dart';
import 'Subscription.dart';
import 'models/audio_track.dart' show AudioTrack;
import 'models/authmanager.dart';
import 'services/dynamic_dialogue_service.dart';
import 'widgets/dynamic_dialogue_widget.dart';


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
class Homescreen extends StatefulWidget {
  final bool isAuthenticatedUser;

  const Homescreen({
    Key? key,
    this.isAuthenticatedUser = false,
  }) : super(key: key);

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  Future<void> _checkAndShowDynamicDialogue() async {
    // Add a slight delay to ensure everything is ready
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      print('DynamicDialogue: Running check on Home Screen...');
      final config = await _dynamicDialogueService.getDialogueConfig();
      if (config != null && await _dynamicDialogueService.shouldShowDialogue(config)) {
        if (!mounted) return;
        print('DynamicDialogue: Showing dialogue to user...');
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return DynamicDialogue(config: config);
          },
        );
        // Mark as shown once it's displayed
        await _dynamicDialogueService.markAsShown();
      } else {
        print('DynamicDialogue: Not showing dialogue today');
      }
    });
  }

  int _trialDaysLeft = 0;
  bool _hideTrialBanner = false;
  bool _isGuestUser = false;
////////////////////////////////////////////////////////////////////////////////////////////////////////////
  Future<void> _loadGuestStatus() async {
    _isGuestUser = await AuthManager.isGuest();
  }

///////////////////////////////////////////////////////////////////////////////////////////////////////////
  Future<void> _verifyAuthUser() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (_isGuestUser) return; // allow guest
      _forceLogout();
      return;
    }


    try {
      await user.reload();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') {
        return;
      }
      await FirebaseAuth.instance.signOut();
      _forceLogout();
    } on SocketException catch (_) {
      return;
    } catch (e) {
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        return;
      }

      await FirebaseAuth.instance.signOut();
      _forceLogout();
    }
  }

/////////////////////////////////////////////////////////////////////////////////////////////////////
  Future<void> _loadTrialBannerDismissState() async {
    final prefs = await SharedPreferences.getInstance();
    _hideTrialBanner = prefs.getBool('hide_trial_banner') ?? false;
  }

/////////////////////////////////////////////////////////////////////////////////////////////////////
  void _forceLogout() {
    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
          (route) => false,
    );
  }
//////////////////////////////////////////////////////////////////////////////////////////////////////

  bool _isAlarmEnabled = true; // 🔔 ON by default 🔔 //
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<AudioTrack> tracks = [];
  List<Map<String, String>> videos = [];
  bool _isScrolled = false;
  final AudioPlayer audioPlayer = AudioPlayer();
  bool isPlaying = false;
  int? currentPlayingIndex;
  int? selectedTimer;
  Timer? _timer;
  bool _isSubscribed = false;
  bool _isPaidSubscriber = false;
  Timer? _previewTimer;
  String? _selectedAlarmSound;
  bool _alarmTriggered = false;
  final AudioPlayer _alarmPlayer = AudioPlayer();
  Map<int, Duration> remainingTimes = {};
  Map<int, Duration> trackTimers = {};
  Map<int, Timer?> countdownTimers = {};
  final List<bool> _isSelected = [true, false, false];
  int _currentThemeIndex = 0;
  final List<String> _backgroundImages = [
    'assets/2rotate.jpeg',
    'assets/shared image.png',
    'assets/melodic.jpeg',
  ];


  final Map<int, ValueNotifier<double?>> _downloadProgressNotifier = {};
  final Map<int, CancelToken> _downloadCancelTokens = {};

  bool _dataFetched = false;
  int _selectedIndex = 0;
  Map<int, bool> _likedTracks = {};
  Map<int, bool> _isLiking = {};
  Map<int, bool> _isDownloading = {};
  Map<int, double?> _downloadProgress = {};
  Map<int, bool> _isDownloaded = {};
  bool _isOffline = false;
  late bool _isTrialActive;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _showAlarmStatus = true;
  Timer? _alarmStatusTimer;

  final Map<String, String> _temporaryCachePaths = {};
  final Map<String, bool> _isTempCaching = {};

  final Map<String, List<Color>> _segmentGradientColors = {
    'Sonic': [
      Colors.blue.shade300.withOpacity(0.5),
      Colors.teal.shade200.withOpacity(0.5),
      Colors.cyan.shade100.withOpacity(0.4),
    ],
    'Tonic': [
      Colors.green.shade200.withOpacity(0.3),
      Colors.greenAccent.shade100.withOpacity(0.3),
      Colors.green.shade100.withOpacity(0.4),
    ],
    'Melodic': [
      Colors.blue.shade500.withOpacity(0.3),
      Colors.purple.shade200.withOpacity(0.6),
      Colors.amber.shade300.withOpacity(0.2),
    ],
  };

  late AnimationController _welcomeTextController;
  late Animation<double> _welcomeTextOpacity;
  late Animation<double> _welcomeTextScale;
  late AnimationController _toggleButtonsController;
  late Animation<Offset> _toggleButtonsOffset;
  late AnimationController _bottomNavController;
  late Animation<Offset> _bottomNavOffset;
  List<AnimationController> _trackCardControllers = [];


  final DynamicDialogueService _dynamicDialogueService = DynamicDialogueService();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    // 🔐 Validate auth (detect deleted / disabled user)
    _loadGuestStatus().then((_) {
      if (!_isGuestUser) {
        _verifyAuthUser(); // only for signed-in users
      }
      // Check for dynamic dialogue after status loaded
      _checkAndShowDynamicDialogue();
    });


    // 🧪 Safety default 🧪 //
    _isTrialActive = false;

    selectedTimer = 20;
// 🔔 Load saved alarm sound (persistent) 🔔//
    _loadSelectedAlarm();

    _scrollController.addListener(_onScroll);
    _setupConnectivityListener();
    _checkConnectivity();

    // 🔥 LISTEN auth changes (login/logout)  🔥 //
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (_isGuestUser) return;

      if (user != null) {
        _setupSubscriptionListener();
      } else {
        _forceLogout();
      }
    });


    // 🔥🔥 CRITICAL: FORCE subscription + trial check on app start 🔥🔥 //
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (FirebaseAuth.instance.currentUser != null) {
        _setupSubscriptionListener();
      }
      _fetchData(); // now safe //
    });

    // 🎬 Animations 🎬 //
    _welcomeTextController =
        AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);

    _welcomeTextOpacity = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _welcomeTextController, curve: Curves.easeIn));

    _welcomeTextScale = Tween<double>(begin: 0.8, end: 1.0)
        .animate(CurvedAnimation(parent: _welcomeTextController, curve: Curves.easeOut));

    _toggleButtonsController =
        AnimationController(duration: const Duration(milliseconds: 800), vsync: this);

    _toggleButtonsOffset =
        Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
            .animate(CurvedAnimation(parent: _toggleButtonsController, curve: Curves.easeOut));

    _bottomNavController =
        AnimationController(duration: const Duration(milliseconds: 800), vsync: this);

    _bottomNavOffset =
        Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: _bottomNavController, curve: Curves.easeOut));

    _alarmStatusTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) return;

      if (_selectedAlarmSound == null) {
        setState(() => _showAlarmStatus = !_showAlarmStatus);
      } else if (!_showAlarmStatus) {
        setState(() => _showAlarmStatus = true);
      }
    });

    _welcomeTextController.forward();
    _toggleButtonsController.forward();
    _bottomNavController.forward();

    // 🟠 Load banner dismiss preference  🟠 //
    _loadTrialBannerDismissState();
  }

  Future<void> _loadSelectedAlarm() async {
    final prefs = await SharedPreferences.getInstance();
    final savedAlarm = prefs.getString('selected_alarm');

    if (savedAlarm != null && mounted) {
      setState(() {
        _selectedAlarmSound = savedAlarm;
      });
    }
  }

  Future<void> _clearTemporaryCache() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync();
      for (final file in files) {
        if (file is File && file.path.contains('temp_cache_')) {
          await file.delete();
        }
      }
    } catch (e) {
      print('Error clearing temporary cache: $e');
    }
    _temporaryCachePaths.clear();
    _isTempCaching.clear();
  }

  Future<void> _loadDownloadedTracks() async {
    final directory = await getApplicationDocumentsDirectory();
    final files = directory.listSync();

    if (_isOffline) {
      final downloadedTracks = await getDownloadedTracks();

      // 🔥 FILTER BY CURRENT SEGMENT
      final filteredTracks = downloadedTracks
          .where((track) => track.category == currentCategory)
          .toList();

      setState(() {
        tracks = filteredTracks;
        _isDownloaded = {};
        _downloadProgress = {};
        _isDownloading = {};
        _likedTracks = {};
        _isLiking = {};

        for (int i = 0; i < tracks.length; i++) {
          _isDownloaded[i] = true;
        }
      });
      return;
    }

    setState(() {
      for (int i = 0; i < tracks.length; i++) {
        final track = tracks[i];
        final fileName = '${track.trackId}.mp3';
        final filePath = '${directory.path}/$fileName';
        if (files.any((file) => file.path == filePath)) {
          _isDownloaded[i] = true;
        }
      }
    });
  }

  Future<List<AudioTrack>> getDownloadedTracks() async {
    final List<AudioTrack> downloadedTracks = [];
    final prefs = await SharedPreferences.getInstance();
    final directory = await getApplicationDocumentsDirectory();

    final allKeys = prefs.getKeys();
    final downloadedKeys = allKeys.where((key) => key.startsWith('downloaded_')).toList();

    for (final key in downloadedKeys) {
      final isDownloaded = prefs.getBool(key);
      if (isDownloaded == true) {
        final trackId = key.replaceFirst('downloaded_', '');
        final name = prefs.getString('track_name_$trackId') ?? 'Unknown Track';
        final category = prefs.getString('track_category_$trackId') ?? 'Unknown';
        final description = prefs.getString('track_description_$trackId');
        final bestEnvironment = prefs.getString('track_bestEnvironment_$trackId') ?? 'Unknown';
        final filePath = '${directory.path}/$trackId.mp3';

        final file = File(filePath);
        if (await file.exists()) {
          final offlineTrack = AudioTrack(
            trackId: trackId,
            name: name,
            fullAudioUrl: filePath,
            previewAudioUrl: filePath,
            category: category,
            isFree: true,
            description: description ?? 'No description available',
            bestEnvironment: bestEnvironment,
          );
          downloadedTracks.add(offlineTrack);
        }
      }
    }
    return downloadedTracks;
  }



  Future<void> _downloadTrack(int index) async {
    if (_isGuestUser) {
      _showSignupDialog();
      return;
    }

    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    final bool isSubscribed = userData?['isSubscribed'] ?? false;

    if (!isSubscribed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please subscribe to download tracks')),
      );
      return;
    }
    final cancelToken = CancelToken();
    _downloadCancelTokens[index] = cancelToken;

    // ✅ init notifier (once) ✅  //
    _downloadProgressNotifier[index] ??= ValueNotifier<double?>(0.0);

    // ✅ low-frequency UI update (SAFE) ✅ //
    setState(() {
      _isDownloading[index] = true;
    });

    try {
      final track = tracks[index];
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/${track.trackId}.mp3';

      final dio = Dio();
      await dio.download(
        track.fullAudioUrl,
        filePath,
        cancelToken: cancelToken, // ✅ ADD THIS ✅ //
        onReceiveProgress: (received, total) {
          if (total != -1) {
            _downloadProgressNotifier[index]!.value = received / total;
          }
        },
      );


      // ✅ finish download (SAFE) ✅ //
      setState(() {
        _isDownloaded[index] = true;
        _isDownloading[index] = false;
      });

      // ✅ hide progress indicator ✅ //
      _downloadProgressNotifier[index]!.value = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('downloaded_${track.trackId}', true);
      await prefs.setString('track_name_${track.trackId}', track.name);
      await prefs.setString('track_category_${track.trackId}', track.category);
      await prefs.setString('track_description_${track.trackId}', track.description);
      await prefs.setString('track_bestEnvironment_${track.trackId}', track.bestEnvironment);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${track.name} downloaded successfully')),
      );
    } on DioException catch (e) {
      // 🛑 If user cancelled the download
      if (CancelToken.isCancel(e)) {
        debugPrint('Download cancelled for index $index');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading track')),
        );
      }

      // ✅ Reset UI safely ✅ //
      setState(() {
        _isDownloading[index] = false;
      });

      // ✅ Remove progress indicator ✅ //
      _downloadProgressNotifier[index]?.value = null;

      // ✅ Clean cancel token ✅ //
      _downloadCancelTokens.remove(index);
    }

  }

  Future<void> _deleteTrack(int index) async {
    try {
      final track = tracks[index];
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/${track.trackId}.mp3';
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('downloaded_${track.trackId}');
        await prefs.remove('track_name_${track.trackId}');
        await prefs.remove('track_category_${track.trackId}');
        await prefs.remove('track_description_${track.trackId}');
        await prefs.remove('track_bestEnvironment_${track.trackId}');

        setState(() {
          _isDownloaded[index] = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${track.name} deleted successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting track: $e')),
      );
    }
  }

  void _setupSubscriptionListener() {
    final User? user = _auth.currentUser;
    if (_isGuestUser) {
      SharedPreferences.getInstance().then((prefs) {
        final localSub = prefs.getBool('local_isSubscribed') ?? false;
        final localEndStr = prefs.getString('local_subscriptionEndDate');
        bool validLocal = false;
        if (localSub && localEndStr != null) {
          try {
            final end = DateTime.parse(localEndStr);
            validLocal = end.isAfter(DateTime.now());
          } catch (_) {
            validLocal = false;
          }
        }
        setState(() {
          _isSubscribed = validLocal;
          _isPaidSubscriber = validLocal;
          _isTrialActive = false;
          _trialDaysLeft = 0;
        });
      });
      return;
    }

    if (user == null) {
      setState(() {
        _isSubscribed = false;
        _isPaidSubscriber = false;
        _isTrialActive = false;
        _trialDaysLeft = 0;
      });
      return;
    }

    _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists || snapshot.data() == null) {
        if (!mounted) return;
        setState(() {
          _isSubscribed = false;
          _isPaidSubscriber = false;
          _isTrialActive = false;
          _trialDaysLeft = 0;
        });
        return;
      }

      final data = snapshot.data()!;
      bool baseSubscribed = data['isSubscribed'] ?? false;
      bool isLifetime = data['isLifetime'] ?? false;
      String? trialEndsAt = data['trialEndsAt'];

      if (trialEndsAt == null && !baseSubscribed && !isLifetime) {
        final newTrialEnd = DateTime.now().add(const Duration(days: 7));

        await _firestore.collection('users').doc(user.uid).set({
          'trialEndsAt': newTrialEnd.toIso8601String(),
          'trialStartedAt': DateTime.now().toIso8601String(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        trialEndsAt = newTrialEnd.toIso8601String();
      }

      // Check expiry ONLY if not lifetime and end date exists
      if (!isLifetime && data.containsKey('subscriptionEndDate')) {
        DateTime? endDate;
        try {
          // Handle both Timestamp and String formats for backward compatibility
          final dynamic endDateData = data['subscriptionEndDate'];
          if (endDateData is Timestamp) {
            endDate = endDateData.toDate();
          } else if (endDateData is String) {
            endDate = DateTime.parse(endDateData);
          }
        } catch (e) {
          print('Error parsing subscriptionEndDate: $e');
        }

        if (endDate != null && endDate.isBefore(DateTime.now())) {
          baseSubscribed = false;
        }
      }

      bool isTrialActive = false;
      int trialDaysLeft = 0;
      if (trialEndsAt != null && !baseSubscribed) {
        final trialEndDate = DateTime.parse(trialEndsAt);
        if (trialEndDate.isAfter(DateTime.now())) {
          isTrialActive = true;
          trialDaysLeft = trialEndDate.difference(DateTime.now()).inDays.clamp(0, 999);
        }
      }

      final bool allowFullAudio = baseSubscribed || isTrialActive;
      final bool isPaidSubscriber = baseSubscribed && !isTrialActive;

      if (!mounted) return;
      setState(() {
        _isSubscribed = allowFullAudio;
        _isPaidSubscriber = isPaidSubscriber;
        _isTrialActive = isTrialActive;
        _trialDaysLeft = trialDaysLeft;

        if (!_isTrialActive || _isPaidSubscriber) {
          _hideTrialBanner = true;
        }
      });

    }, onError: (error) {
      if (!mounted) return;
      setState(() {
        _isSubscribed = false;
        _isPaidSubscriber = false;
        _isTrialActive = false;
        _trialDaysLeft = 0;
      });
    });
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOffline = connectivityResult.contains(ConnectivityResult.none);
    });

    if (_isOffline) {
      _loadDownloadedTracks();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are offline. Showing downloaded tracks only.'),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final wasOffline = _isOffline;
      final isNowOffline = results.contains(ConnectivityResult.none);

      if (wasOffline != isNowOffline) {
        setState(() {
          _isOffline = isNowOffline;
        });

        if (_isOffline) {
          _loadDownloadedTracks();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You are offline. Showing downloaded tracks only.'),
              duration: Duration(seconds: 3),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          _fetchData();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You are back online.'),
              duration: Duration(seconds: 3),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _clearTemporaryCache();
    _timer?.cancel();
    _previewTimer?.cancel();
    audioPlayer.dispose();
    _alarmPlayer.dispose();
    _scrollController.dispose();
    countdownTimers.forEach((key, timer) => timer?.cancel());
    _welcomeTextController.dispose();
    _toggleButtonsController.dispose();
    _bottomNavController.dispose();
    _alarmStatusTimer?.cancel();
    for (var controller in _trackCardControllers) controller.dispose();
    _trackCardControllers.clear();

    _connectivitySubscription.cancel();
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
    for (final token in _downloadCancelTokens.values) {
      token.cancel();
    }
    _downloadCancelTokens.clear();

  }

  void showSubscriptionSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Subscribe to access full tracks and more features!', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black.withOpacity(0.8),
        action: SnackBarAction(
          label: 'Subscribe',
          textColor: Colors.white,
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (context) => const Subscription()));
          },
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void showSubscriptionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.8),
          title: const Text('Subscribe Now', style: TextStyle(color: Colors.white)),
          content: const Text('Subscribe to access full tracks and more features!', style: TextStyle(color: Colors.white)),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await Navigator.push(context, MaterialPageRoute(builder: (context) => const Subscription()));
              },
              child: const Text('Subscribe', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Maybe Later', style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    if (_dataFetched) return;
    try {
      final audioSnapshot = await _firestore
          .collection('audios')
          .where('category', isEqualTo: currentCategory)
          .get();
      tracks = audioSnapshot.docs.map((doc) => AudioTrack.fromFirestore(doc)).toList();

      for (var controller in _trackCardControllers) {
        controller.dispose();
      }
      _trackCardControllers.clear();

      if (mounted) {
        _trackCardControllers = List.generate(
          tracks.length,
              (index) => AnimationController(
            duration: Duration(milliseconds: 500 + (index * 100)),
            vsync: this,
          )..forward(),
        );
      }

      User? user = _auth.currentUser;
      if (user != null) {
        final likedTracksSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('LikedTracks')
            .get();
        _likedTracks = {};
        for (var doc in likedTracksSnapshot.docs) {
          int trackIndex = tracks.indexWhere((track) => track.trackId == doc.id);
          if (trackIndex != -1) {
            _likedTracks[trackIndex] = true;
          }
        }
      }

      final videoSnapshot = await _firestore.collection('Videos').get();
      videos = videoSnapshot.docs.map((doc) {
        final name = (doc['name'] as String).trim();
        final url = (doc['url'] as String).trim().replaceAll('"', '');
        return {'name': name, 'url': url};
      }).toList();

      _dataFetched = true;
      await _loadDownloadedTracks();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching data: $e')),
      );
    }
  }

  String get currentCategory {
    if (_isSelected[0]) return 'Sonic';
    if (_isSelected[1]) return 'Tonic';
    if (_isSelected[2]) return 'Melodic';
    return 'Sonic';
  }

  // REMOVED: togglePlay() → replaced with toggleExpandOnly only
  // Play button now only expands/collapses card

  void _playAlarm() async {
    if (_selectedAlarmSound != null && !_alarmTriggered) {
      setState(() {
        _alarmTriggered = true;
      });

      try {
        await _alarmPlayer.setReleaseMode(ReleaseMode.loop);
        await _alarmPlayer.play(AssetSource(_selectedAlarmSound!));

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFDFBFB),
                      Color(0xFFEFF1F5),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 25,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.shade400,
                            Colors.redAccent.shade200,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.5),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.alarm,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      'Nap Complete!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade900,
                        letterSpacing: 0.4,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      'You’re refreshed and ready to go 🚀',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _stopAlarm();
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          elevation: 10,
                          shadowColor: Colors.green.withOpacity(0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Stop Alarm',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );

        Future.delayed(Duration(minutes: 1), () {
          if (_alarmTriggered) {
            _stopAlarm();
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

  void startCountdown(int index) {
    countdownTimers[index]?.cancel();
    countdownTimers[index] = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (remainingTimes[index]!.inSeconds > 0) {
          remainingTimes[index] = remainingTimes[index]! - const Duration(seconds: 1);
        } else {
          timer.cancel();
          audioPlayer.stop();
          setState(() {
            isPlaying = false;
            currentPlayingIndex = null;

          });

          if (_isAlarmEnabled && _selectedAlarmSound != null) {
            _playAlarm();
          }

        }
      });
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    switch (index) {
      case 0:
        break;
      case 1:
        _bottomNavController.reverse().then((_) async {
          _bottomNavController.forward();
          final selectedAlarm = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TimerScreen()),
          );

          if (selectedAlarm != null && mounted) {
            setState(() {
              _selectedAlarmSound = selectedAlarm;
            });
          }

        });
        break;
      case 2:
        _bottomNavController.reverse().then((_) {
          _bottomNavController.forward();
          Navigator.pushReplacementNamed(context, '/settings');
        });
        break;
    }
  }
  ////////////////////////////////////////////////////////////////////////////////
  void _showSignupDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Signup',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.shade500.withOpacity(0.95),
                    Colors.purple.shade400.withOpacity(0.95),
                    Colors.indigo.shade900.withOpacity(0.95),
                  ],
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: Colors.white.withOpacity(0.35),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 30,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🔒 Icon
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber.shade400,
                          Colors.orange.shade500,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.6),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 📝 Title
                  const Text(
                    'Unlock Full Access',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 📄 Description
                  Text(
                    'Sign up to access Tonic & Melodic sessions,\nfull audio tracks and downloads.\n\nStart your 7-day free trial now ✨',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14.5,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 26),

                  // 🚀 CTA buttons 🚀 //
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.6),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          child: const Text(
                            'Maybe Later',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 14),


                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pushReplacementNamed(context, '/signup');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade400,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 12,
                            shadowColor: Colors.amber.withOpacity(0.6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
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
      },
    );
  }

////////////////////////////////////////////////////////////////////////////////////
  Future<void> _checkAndShowHeadphoneDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final hasShown = prefs.getBool('has_shown_headphone_dialog') ?? false;

    if (!hasShown && mounted) {
      // 🎧 Check if headphones are currently connected
      try {
        final session = await AudioSession.instance;
        final devices = await session.getDevices();
        
        final hasHeadphones = devices.any((device) =>
            device.type == AudioDeviceType.wiredHeadphones ||
            device.type == AudioDeviceType.wiredHeadset ||
            device.type == AudioDeviceType.bluetoothA2dp ||
            device.type == AudioDeviceType.bluetoothLe);

        if (hasHeadphones) {
          // User is already using headphones, mark it as shown so they aren't bothered later
          await prefs.setBool('has_shown_headphone_dialog', true);
          return;
        }
      } catch (e) {
        debugPrint("Error checking audio session: $e");
        // If detection fails, we proceed with the dialog to ensure the user gets the message once
      }

      await showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Headphones',
        barrierColor: Colors.black.withOpacity(0.35),
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) => const SizedBox.shrink(),
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
          return ScaleTransition(
            scale: curve,
            child: FadeTransition(
              opacity: animation,
              child: Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.blue.shade500.withOpacity(0.95),
                        Colors.purple.shade400.withOpacity(0.95),
                        Colors.indigo.shade900.withOpacity(0.95),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.35),
                      width: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 30,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 🎧 Icon
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade400,
                              Colors.blue.shade600,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.6),
                              blurRadius: 14,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.headphones_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),

                      const SizedBox(height: 18),

                      // 📝 Title
                      const Text(
                        'Better Experience',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // 📄 Description
                      Text(
                        'Use headphones for a better and more immersive experience.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14.5,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 26),

                      // 🚀 CTA buttons 🚀 //
                      Row(
                        children: [

                          const SizedBox(width: 14),

                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber.shade400,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                elevation: 12,
                                shadowColor: Colors.amber.withOpacity(0.6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                              ),
                              child: const Text(
                                'OK',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
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
          );
        },
      );

      // ✅ SET FLAG AFTER DIALOG IS CLOSED (no matter how it's closed)
      final finalPrefs = await SharedPreferences.getInstance();
      await finalPrefs.setBool('has_shown_headphone_dialog', true);
    }
  }

  ////////////////////////////////////////////////////////////////////////////////////
  void _handleSegmentChange(int index) {
    // ✅ 1. BLOCK guest BEFORE state change ✅ //
    if (_isGuestUser && index != 0) {
      _showSignupDialog();
      return;
    }

    // ✅ 2. Stop audio BEFORE state change ✅ //
    if (isPlaying) {
      audioPlayer.stop();
      _timer?.cancel();
      _previewTimer?.cancel();
      setState(() {
        isPlaying = false;
        currentPlayingIndex = null;
      });
    }

    // ✅ 3. Dispose controllers SAFELY ✅ //
    for (var controller in _trackCardControllers) {
      controller.dispose();
    }
    _trackCardControllers.clear();

    // ✅ 4. NOW update UI state (atomic & safe) ✅ //
    setState(() {
      for (int i = 0; i < _isSelected.length; i++) {
        _isSelected[i] = i == index;
      }

      _currentThemeIndex = index;

      tracks.clear();
      _likedTracks.clear();
      _isLiking.clear();
      _isDownloading.clear();
      _downloadProgress.clear();
      _isDownloaded.clear();
      _dataFetched = false;
    });

    // ✅ 5. Fetch after rebuild ✅ //
    _fetchData();
  }

  void _toggleLike(int index) async {
    if (_isGuestUser) {
      _showSignupDialog();
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to like tracks')),
      );
      return;
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    final bool isSubscribed = userData?['isSubscribed'] ?? false;

    if (!isSubscribed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please subscribe to like tracks')),
      );
      return;
    }

    setState(() {
      _isLiking[index] = true;
    });

    try {
      final trackId = tracks[index].trackId;
      final likedTrackRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('LikedTracks')
          .doc(trackId);

      setState(() {
        _likedTracks[index] = !(_likedTracks[index] ?? false);
      });

      if (_likedTracks[index] == true) {
        await likedTrackRef.set({
          'liked': true,
          'likedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await likedTrackRef.delete();
      }
    } catch (e) {
      print('Error updating like status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating like status: $e')),
      );
      setState(() {
        _likedTracks[index] = !(_likedTracks[index] ?? false);
      });
    } finally {
      setState(() {
        _isLiking[index] = false;
      });
    }
  }

  void _showTrackDetailsDialog(BuildContext context, int index, AudioTrack track) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.2),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final durations = [16, 18, 20, 22, 24, 26];
            final width = MediaQuery.of(context).size.width;
            final crossAxisCount = width < 360 ? 2 : width < 520 ? 3 : 4;
            final fontSize = (width / 26).clamp(11.0, 14.0);

            // Use the expanded colors for the dialog background //
            List<Color> dialogGradientColors;

            if (currentCategory == 'Sonic') {
              // 🔥 Sonic – warm energetic  🔥 //
              dialogGradientColors = [
                Colors.red.shade300.withOpacity(0.95),
                Colors.orange.shade300.withOpacity(0.95),
                Colors.orange.shade100.withOpacity(0.95),
              ];
            }
            else if (currentCategory == 'Tonic') {

              dialogGradientColors = [
                const Color(0x3557AEE6).withOpacity(0.95),
                const Color(0x306FADDA).withOpacity(0.95),
                const Color(0x1DC58E2C).withOpacity(0.90),
              ];
            }
            else {
              // 🎵 Melodic – soft dreamy    🎵 //
              dialogGradientColors = _segmentGradientColors[currentCategory]!
                  .map((c) => c.withOpacity(0.95))
                  .toList();
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 500),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: dialogGradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 2,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              track.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white30, thickness: 1),

                    // Scrollable Content //
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Best Environment //
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.volume_up, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Best Environment: ${track.bestEnvironment}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Description //
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.park, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Description: ${track.description}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            Divider(color: Colors.white.withOpacity(0.2), thickness: 0.8),
                            const SizedBox(height: 8),

                            // Wake-up Alarm Toggle //
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.alarm,
                                      color: _isAlarmEnabled ? Colors.white : Colors.white54,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Wake-up alarm',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Transform.scale(
                                      scale: 0.7,
                                      child: Switch(
                                        value: _isAlarmEnabled,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        activeTrackColor: Colors.amber,
                                        activeThumbColor: Colors.white,
                                        inactiveTrackColor: Colors.white38,
                                        inactiveThumbColor: Colors.grey,
                                        onChanged: (value) {
                                          setState(() => _isAlarmEnabled = value);
                                          setDialogState(() {});
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 4),
                            Divider(color: Colors.white.withOpacity(0.25), thickness: 0.9),
                            const SizedBox(height: 4), // 👈 brings timers closer 👈 //


                            // Timer Grid
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: durations.length,
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                mainAxisSpacing: 18, // 👈 vertical spacing between timer rows 👈//
                                crossAxisSpacing: 8,
                                childAspectRatio: 2.6,
                              ),

                              itemBuilder: (context, i) {
                                final minutes = durations[i];
                                final isSelected = selectedTimer == minutes;

                                return ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      selectedTimer = minutes;
                                      remainingTimes[index] = Duration(minutes: minutes);
                                    });
                                    setDialogState(() {});
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black.withOpacity(0.38),
                                    foregroundColor: Colors.white,
                                    elevation: isSelected ? 8 : 4,
                                    shadowColor: isSelected
                                        ? Colors.amber.shade500.withOpacity(0.6)
                                        : Colors.black.withOpacity(0.4),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: BorderSide(
                                        color: isSelected
                                            ? Colors.amber.shade200
                                            : Colors.white.withOpacity(0.4),
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: Text(
                                    '$minutes min',
                                    style: TextStyle(
                                      fontSize: fontSize,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected ? Colors.amber.shade100 : Colors.white,
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 24),

                            // Begin Button
                            Center(
                              child: SizedBox(
                                width: 180,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: selectedTimer == null
                                      ? null
                                      : () async {
                                          final minutes = selectedTimer!;

                                          // 🎧 Check for headphone reminder BEFORE playing audio 🎧
                                          await _checkAndShowHeadphoneDialog();

                                          final directory = await getApplicationDocumentsDirectory();
                                          final localPath = '${directory.path}/${track.trackId}.mp3';

                                          String audioUrl;

                                          if (File(localPath).existsSync()) {
                                            // ✅ PLAY LOCAL FILE FIRST (even if online) ✅ //
                                            audioUrl = localPath;
                                          } else {
                                            // 🌐 fallback to remote 🌐 //
                                            audioUrl = (_isGuestUser || !_isSubscribed)
                                                ? track.previewAudioUrl
                                                : track.fullAudioUrl;
                                          }

                                          videos.shuffle();
                                          final randomVideoUrl = videos.isNotEmpty
                                              ? (videos.first['url'] ?? '').trim().replaceAll('"', '')
                                              : '';

                                          Navigator.pop(context); // Close dialog //
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => Playscreen(
                                                trackTitle: track.name,
                                                trackPath: audioUrl,
                                                currentIndex: index,
                                                timerDuration: minutes,
                                                videoUrl: randomVideoUrl,
                                                trackId: track.trackId,
                                                description: track.description,
                                                bestEnvironment: track.bestEnvironment,
                                                isSubscribed: _isSubscribed,
                                                isAlarmEnabled: _isAlarmEnabled,
                                                alarmSound: _selectedAlarmSound,
                                                backgroundImage: _backgroundImages[_currentThemeIndex],
                                              ),
                                            ),
                                          );
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber.shade400,
                                    foregroundColor: Colors.black,
                                    elevation: 10,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: const Text(
                                    'Begin',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
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
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget buildTrackCard(
      int index,
      AudioTrack track, {
        double trackNameExpanded = 22,
        double trackNameNormal = 19,
        double descriptionFontSize = 16,
        bool isSmallScreen = false,
      }) {
    bool isLiked = _likedTracks[index] ?? false;
    bool isDownloading = _isDownloading[index] ?? false;
    bool isDownloaded = _isDownloaded[index] ?? false;

    return AnimatedOpacity(
      opacity: _dataFetched ? 1.0 : 0.0,
      duration: Duration(milliseconds: 500 + (index * 100)),
      curve: Curves.easeIn,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.95, end: 1.0).animate(
          CurvedAnimation(parent: _trackCardControllers[index], curve: Curves.easeOut),
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _showTrackDetailsDialog(context, index, track);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      track.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: trackNameNormal,
                        fontWeight: FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isPaidSubscriber && !_isGuestUser)

                      SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          icon: _isLiking[index] ?? false
                              ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 0.8,
                          )
                              : Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? Colors.red.shade300 : Colors.white,
                            size: 22,
                          ),
                          onPressed: () => _toggleLike(index),
                          padding: EdgeInsets.zero,
                        ),
                      ),

                    if (_isPaidSubscriber && !_isGuestUser)

                      const SizedBox(width: 10),

                    if (_isPaidSubscriber && !_isGuestUser)

                      SizedBox(
                        width: 40,
                        child: Opacity(
                          opacity: isDownloading ? 0.5 : 1.0,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (child, animation) =>
                                    ScaleTransition(scale: animation, child: child),
                                child: IconButton(
                                  key: ValueKey(isDownloaded),
                                  padding: EdgeInsets.zero,
                                  splashRadius: 20,
                                  onPressed: () {
                                    if (isDownloading) {
                                      _downloadCancelTokens[index]?.cancel();
                                      _downloadProgressNotifier[index]?.value = null;

                                      setState(() {
                                        _isDownloading[index] = false;
                                      });
                                      return;
                                    }

                                    if (isDownloaded) {
                                      _deleteTrack(index);
                                      return;
                                    }

                                    _downloadTrack(index);
                                  },

                                  icon: isDownloaded
                                      ? Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade600,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  )
                                      : const Icon(
                                    Icons.download_rounded,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                ),
                              ),

                              if (isDownloading)
                                const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                    if (_isTempCaching[track.trackId] ?? false)
                      const SizedBox(width: 8),

                    if (_isTempCaching[track.trackId] ?? false)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.6,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                      
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 35,
                      child: IconButton(
                        icon: const Icon(
                          Icons.play_circle_filled,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () => _showTrackDetailsDialog(context, index, track),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null) {
      if (args is int) {
        setState(() {
          selectedTimer = args;
        });
      } else if (args is String) {
        setState(() {
          _selectedAlarmSound = args;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verifyAuthUser();
    }
  }

  void _onScroll() {
    if (_scrollController.offset > 10 && !_isScrolled) {
      setState(() => _isScrolled = true);
    } else if (_scrollController.offset <= 10 && _isScrolled) {
      setState(() => _isScrolled = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double screenWidth = size.width;
    final double screenHeight = size.height;
    final bool isSmallScreen = screenWidth < 360;
    final bool isLargeScreen = screenWidth > 500;

    final double horizontalPadding = screenWidth >= 900
        ? 24        // tablets
        : screenWidth >= 600
        ? 16
        : 12;

    final double mainContainerMaxWidth = screenWidth >= 900
        ? 680        // tablets
        : screenWidth >= 600
        ? 620    // large phones / small tablets
        : (screenWidth * 0.94).clamp(320.0, 520.0);

    final double welcomeFontSize = isSmallScreen ? 20 : (isLargeScreen ? 26 : 23);
    final double trackNameFontSizeExpanded = isSmallScreen ? 18 : 20;
    final double trackNameFontSizeNormal   = isSmallScreen ? 15 : 17;

    final double descriptionFontSize = isSmallScreen ? 13 : 14.5;


    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              image: DecorationImage(
                image : AssetImage(_backgroundImages[_currentThemeIndex]),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.3), BlendMode.darken),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF06158C).withOpacity(0.85),
                  const Color(0xFF6274E6).withOpacity(0.85),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  FadeTransition(
                    opacity: _welcomeTextOpacity,
                    child: ScaleTransition(
                      scale: _welcomeTextScale,
                      child: Padding(
                        padding: EdgeInsets.only(top: isSmallScreen ? 12 : 16),

                        child: Text(
                          'Welcome to Catnappers Club',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: welcomeFontSize,
                            fontWeight: FontWeight.w300,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),

                  AnimatedSize(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding + 5,
                        vertical: 12,
                      ),
                      child: _trialDaysLeft > 0 && !_hideTrialBanner && !_isPaidSubscriber

                          ? Material(
                        elevation: 12,
                        borderRadius: BorderRadius.circular(24),
                        shadowColor: Colors.black.withOpacity(0.6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6B35), Color(0xFFF7931E)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 22),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Free Trial Active! $_trialDaysLeft days left',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isSmallScreen ? 13 : 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () async {
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setBool('hide_trial_banner', true);

                                  setState(() {
                                    _hideTrialBanner = true;
                                  });
                                },

                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                          : const SizedBox.shrink(),
                    ),
                  ),

                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: Container(
                        width: double.infinity,
                        constraints: BoxConstraints(maxWidth: mainContainerMaxWidth),
                        padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF1A237E).withOpacity(0.38),
                              Colors.white.withOpacity(0.28),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.blue.withOpacity(0.22), width: 1.6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.35),
                              blurRadius: 25,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            SlideTransition(
                              position: _toggleButtonsOffset,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final buttonWidth = (constraints.maxWidth - 12) / 3;
                                    return ToggleButtons(
                                      onPressed: _handleSegmentChange,
                                      borderRadius: BorderRadius.circular(18),
                                      selectedBorderColor: Colors.white,
                                      selectedColor: Colors.white,
                                      fillColor: Colors.white.withOpacity(0.22),
                                      color: Colors.white.withOpacity(0.85),
                                      constraints: BoxConstraints(
                                        minHeight: 48,
                                        minWidth: buttonWidth.clamp(80, 200),
                                      ),
                                      isSelected: _isSelected,
                                      children: const [
                                        Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Sonic')),
                                        Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Tonic')),
                                        Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Melodic')),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            Expanded(
                              child: _dataFetched && tracks.isNotEmpty
                                  ? ListView.separated(
                                controller: _scrollController,
                                padding: EdgeInsets.zero,

                                itemCount: tracks.length,
                                itemBuilder: (context, index) {
                                  final track = tracks[index];
                                  return buildTrackCard(
                                    index,
                                    track,
                                    trackNameExpanded: trackNameFontSizeExpanded,
                                    trackNameNormal: trackNameFontSizeNormal,
                                    descriptionFontSize: descriptionFontSize,
                                    isSmallScreen: isSmallScreen,
                                  );
                                },
                                separatorBuilder: (_, __) => Column(
                                  children: [
                                    const SizedBox(height: 8), // 👈 vertical spacing between audios
                                    Divider(
                                      color: Colors.white.withOpacity(0.1),
                                      height: 1,
                                      indent: 16,
                                      endIndent: 16,
                                    ),
                                    const SizedBox(height: 8), // 👈 vertical spacing between audios
                                  ],
                                ),

                              )
                                  : const Center(
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.10),
                ],
              ),
            ),
          ),

          Positioned(
            bottom: 15,
            left: horizontalPadding,
            right: horizontalPadding,
            child: SlideTransition(
              position: _bottomNavOffset,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.6),
                    ),
                    child: BottomNavigationBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      selectedItemColor: Colors.white,
                      unselectedItemColor: Colors.white70,
                      type: BottomNavigationBarType.fixed,
                      currentIndex: _selectedIndex,
                      onTap: _onItemTapped,
                      items: const [
                        BottomNavigationBarItem(
                          icon: Icon(Icons.home, size: 20),
                          label: 'Home',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.timer, size: 20),
                          label: 'Alarm',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.settings, size: 20),
                          label: 'Settings',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}