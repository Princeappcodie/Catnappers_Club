import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({Key? key}) : super(key: key);

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 1;

  static const String _alarmPrefKey = 'selected_alarm';

  String? _selectedAudio;
  String? _playingAudio;

  late final AnimationController _bottomNavController;

  final AudioPlayer _audioPlayer = AudioPlayer();

  final List<Map<String, String>> audioOptions = [
    {'name': 'Alarm 1', 'assets': 'Alarm1.mp3'},
    {'name': 'Alarm 2', 'assets': 'Alarm2.mp3'},
    {'name': 'Alarm 3', 'assets': 'Alarm3.mp3'},
    {'name': 'Alarm 4', 'assets': 'Alarm4.mp3'},
    {'name': 'Alarm 5', 'assets': 'Alarm5.mp3'},
    {'name': 'Alarm 6', 'assets': 'Alarm6.mp3'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedAlarm();

    _bottomNavController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  Future<void> _loadSavedAlarm() async {
    final prefs = await SharedPreferences.getInstance();
    final savedAlarm = prefs.getString(_alarmPrefKey);

    if (!mounted) return;
    setState(() {
      _selectedAudio = savedAlarm ?? audioOptions.first['assets'];
    });
  }

  Future<void> _saveAlarm(String audio) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_alarmPrefKey, audio);
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _bottomNavController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    _audioPlayer.stop();

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const Homescreen()),
        );
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/settings');
        break;
    }
  }

  Future<void> _playAudio(String audioFile) async {
    try {
      if (_playingAudio == audioFile) {
        await _audioPlayer.stop();
        setState(() => _playingAudio = null);
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.play(AssetSource(audioFile));
        setState(() => _playingAudio = audioFile);
      }
    } catch (_) {
      setState(() => _playingAudio = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to play audio')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;

    final bool isSmallScreen = screenWidth < 360;
    final bool isTablet = screenWidth >= 600;

    final double horizontalPadding =
    isTablet ? 24 : (isSmallScreen ? 12 : 16);

    final double gridWidth =
    (screenWidth * 0.92).clamp(300.0, 520.0);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      body: Stack(
        children: [
          // ===================== BACKGROUND ===================== //
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: const AssetImage('assets/[2rotate.jpeg'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.35),
                  BlendMode.darken,
                ),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  SizedBox(height: screenHeight * 0.05),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                            child: Text(
                              'Tap to play, tap again to change.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 14 : 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),

                          SizedBox(height: screenHeight * 0.035),

                          Container(
                            width: gridWidth,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.40),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.15),
                                width: 1.2,
                              ),
                            ),
                            padding: EdgeInsets.all(isSmallScreen ? 12 : 18),
                            child: GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 1.6,
                              children:
                              audioOptions.map(_buildAudioButton).toList(),
                            ),
                          ),

                          const SizedBox(height: 24),

                          SizedBox(
                            width: (screenWidth * 0.6).clamp(200, 280),
                            height: 48,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFE84141), // Orange //
                                    Color(0xFFFFC107), // Yellow //

                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(26),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(0.45),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _selectedAudio == null
                                    ? null
                                    : () async {
                                  await _saveAlarm(_selectedAudio!);
                                  await _audioPlayer.stop();
                                  Navigator.pop(context, _selectedAudio);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent, // 🔑 important 🔑 //
                                  shadowColor: Colors.transparent,     // 🔑 important 🔑 //
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(26),
                                  ),
                                ),
                                child: const Text(
                                  'Done',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.12),
                ],
              ),
            ),
          ),
          // ===================== DARKER GLASS BOTTOM BAR ===================== //
          Positioned(
            bottom: 14,
            left: horizontalPadding,
            right: horizontalPadding,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: _bottomNavController,
                  curve: Curves.easeOut,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.65),
                          Colors.black.withOpacity(0.45),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.18),
                        width: 1.6,
                      ),
                    ),
                    child: BottomNavigationBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      type: BottomNavigationBarType.fixed,
                      currentIndex: _selectedIndex,
                      selectedItemColor: Colors.white,
                      unselectedItemColor: Colors.white70,
                      onTap: (index) {
                        _bottomNavController.reverse().then((_) {
                          _bottomNavController.forward();
                          _onItemTapped(index);
                        });
                      },
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

  Widget _buildAudioButton(Map<String, String> audio) {
    final fileName = audio['assets'];
    final isSelected = _selectedAudio == fileName;
    final isPlaying = _playingAudio == fileName;

    return GestureDetector(
      onTap: () {
        if (fileName == null) return;
        setState(() => _selectedAudio = fileName);
        _playAudio(fileName);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: isSelected
              ? const LinearGradient(
            colors: [Colors.redAccent, Colors.orangeAccent],
          )
              : null,
          color: isSelected ? null : Colors.white.withOpacity(0.08),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                audio['name'] ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                isPlaying ? Icons.pause : Icons.check,
                color: Colors.white,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}