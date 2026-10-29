import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../core/constants.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'Adom Mmoroso ENT. POS',
      subtitle: 'BUILDING MATERIALS & HARDWARE POS',
      description: 'Streamline building materials & hardware sales, track stock, and manage your store effortlessly.',
      icon: Icons.storefront_rounded,
      color: const Color(0xFFCC7722), // Hardware DeWalt Amber Yellow (#CC7722)
      imagePath: 'assets/images/bgi/cc.jpg',
      videoPath: 'assets/lottie/device-sync-animation-gif-download-4831393.mp4',
    ),
    OnboardingData(
      title: 'Barcoded Precision',
      subtitle: 'ZERO LEAKAGE, FULL CONTROL',
      description: 'Scan product barcodes for instant register checkout and 100% inventory precision.',
      icon: Icons.qr_code_scanner_rounded,
      color: const Color(0xFFEAB308), // Construction Gold Yellow
      imagePath: 'assets/images/bgi/ca.jpg',
      videoPath: 'assets/lottie/barcode.mp4',
    ),
    OnboardingData(
      title: 'Growth Analytics',
      subtitle: 'DATA-DRIVEN DOMINANCE',
      description: 'Real-time profit tracking and business insights. Manage multiple branches from your smartphone.',
      icon: Icons.insights_rounded,
      color: const Color(0xFFF97316), // Safety Tool Orange
      imagePath: 'assets/images/bgi/aa.jpg',
      videoPath: 'assets/lottie/analytics.mp4',
    ),
    OnboardingData(
      title: 'Offline Syncing',
      subtitle: 'UNSTOPPABLE RELIABILITY',
      description: 'No internet? No problem. Complete sales offline and sync automatically when network returns.',
      icon: Icons.cloud_done_rounded,
      color: const Color(0xFF10B981), // Safety Green
      imagePath: 'assets/images/bgi/ww.jpg',
      videoPath: 'assets/lottie/offlineOnline.mp4',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isSmall = size.height < 700;
    const blueBlack = AppColors.primaryBlueBlack; // Hardware Black
    const darkNavy = Color(0xFF09090B);

    return Scaffold(
      backgroundColor: darkNavy,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Background Image with AnimatedSwitcher
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 700),
              child: Image.asset(
                _pages[_currentPage].imagePath,
                key: ValueKey<String>(_pages[_currentPage].imagePath),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return Container(color: darkNavy);
                },
              ),
            ),
          ),

          // Dark Overlay Gradient for text legibility
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    blueBlack.withValues(alpha: 0.85),
                    darkNavy.withValues(alpha: 0.92),
                  ],
                ),
              ),
            ),
          ),

          // Soft geometric glowing circles
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _pages[_currentPage].color.withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _pages[_currentPage].color.withValues(alpha: 0.12),
              ),
            ),
          ),

          // 1. Content PageView
          PageView.builder(
            controller: _pageController,
            onPageChanged: (int page) => setState(() => _currentPage = page),
            itemCount: _pages.length,
            itemBuilder: (context, index) => _buildPage(_pages[index], index == _currentPage, isSmall),
          ),

          // 2. Top Branding Header featuring the New Logo
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: _pages[_currentPage].color, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/logo/logo.jpg',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text(
                          'ADOM MMOROSO ENT.',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'SKIP',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Bottom Controls
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 40,
            left: 30,
            right: 30,
            child: Column(
              children: [
                // Progress Indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (index) => _buildDot(index)),
                ),
                SizedBox(height: isSmall ? 30 : 40),
                
                // Action Button
                Center(
                  child: SizedBox(
                    width: size.width > 460 ? 400 : double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage == _pages.length - 1) {
                          Navigator.pushReplacementNamed(context, '/login');
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 500), 
                            curve: Curves.easeInOut
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _pages[_currentPage].color,
                        foregroundColor: _pages[_currentPage].color.computeLuminance() > 0.35 
                            ? const Color(0xFF18181B) 
                            : Colors.white,
                        elevation: 8,
                        shadowColor: _pages[_currentPage].color.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Row(
                          key: ValueKey(_currentPage),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentPage == _pages.length - 1 ? 'GET STARTED' : 'CONTINUE',
                              style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 15),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              _currentPage == _pages.length - 1 ? Icons.check_circle_outline : Icons.arrow_forward_ios_rounded,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingData data, bool isActive, bool isSmall) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),

          // Video Animation Badge inside Circle Avatar
          AnimatedScale(
            duration: const Duration(milliseconds: 600),
            scale: isActive ? 1.0 : 0.6,
            curve: Curves.elasticOut,
            child: Container(
              width: isSmall ? 180 : 220,
              height: isSmall ? 180 : 220,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: data.color.withValues(alpha: 0.3), width: 2),
                boxShadow: [
                  if (isActive)
                    BoxShadow(
                      color: data.color.withValues(alpha: 0.35),
                      blurRadius: 40,
                      spreadRadius: 4,
                    ),
                ],
              ),
              child: ClipOval(
                child: OnboardingVideoWidget(
                  videoPath: data.videoPath,
                  fallbackIcon: data.icon,
                  fallbackColor: data.color,
                ),
              ),
            ),
          ),
          SizedBox(height: isSmall ? 32 : 48),
          
          // Text Content
          AnimatedOpacity(
            duration: const Duration(milliseconds: 500),
            opacity: isActive ? 1.0 : 0.0,
            child: Column(
              children: [
                Text(
                  data.subtitle,
                  style: TextStyle(
                    color: data.color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  data.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isSmall ? 28 : 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  data.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isSmall ? 14 : 16,
                    color: Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isSmall ? 100 : 120),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    bool isSelected = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 8,
      width: isSelected ? 32 : 8,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isSelected ? _pages[_currentPage].color : Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: _pages[_currentPage].color.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
        ],
      ),
    );
  }
}

class OnboardingVideoWidget extends StatefulWidget {
  final String videoPath;
  final IconData fallbackIcon;
  final Color fallbackColor;

  const OnboardingVideoWidget({
    super.key,
    required this.videoPath,
    required this.fallbackIcon,
    required this.fallbackColor,
  });

  @override
  State<OnboardingVideoWidget> createState() => _OnboardingVideoWidgetState();
}

class _OnboardingVideoWidgetState extends State<OnboardingVideoWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      _controller = VideoPlayerController.asset(widget.videoPath);
      await _controller.initialize();
      _controller.setLooping(true);
      _controller.setVolume(0.0);
      _controller.play();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('Onboarding video player error: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: widget.fallbackColor),
        ),
      );
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller.value.size.width,
          height: _controller.value.size.height,
          child: VideoPlayer(_controller),
        ),
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final String imagePath;
  final String videoPath;

  OnboardingData({
    required this.title, 
    required this.subtitle,
    required this.description, 
    required this.icon,
    required this.color,
    required this.imagePath,
    required this.videoPath,
  });
}
