import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Widget> _slides = [];

  @override
  void initState() {
    super.initState();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            children: [
              _buildSlide1(),
              _buildSlide2(),
              _buildSlide3(),
            ],
          ),
          
          // Custom Smooth Indicator
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) => _buildDot(index)),
            ),
          ),

          // Next / Skip Button for first 2 slides
          if (_currentPage < 2)
            Positioned(
              bottom: 40,
              right: 24,
              child: TextButton(
                onPressed: _nextPage,
                child: const Text(
                  'NEXT',
                  style: TextStyle(
                    color: Color(0xFF135ACF),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: _currentPage == index ? 24 : 8,
      decoration: BoxDecoration(
        color: _currentPage == index ? const Color(0xFF135ACF) : Colors.grey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildSlide1() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/icon/icon.jpg',
              width: 150,
              height: 150,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 48),
          const Text(
            'Welcome to BlueTalk',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF135ACF),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Blue Archive MomoTalk',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey.shade700,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Made by Sensei for you... Sensei',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: Colors.blueGrey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide2() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFF135ACF), size: 28),
              SizedBox(width: 12),
              Text(
                'Disclaimer',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF135ACF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const SingleChildScrollView(
                child: Text(
                  'BlueTalk is not affiliated, associated, authorized, endorsed by, or in any way officially connected with Blue Archive, Nexon Games, or any of their subsidiaries or affiliates.\n\n'
                  'All names, characters, trademarks, and related assets referenced remain the property of their respective copyright and trademark holders.\n\n'
                  'BlueTalk is an independent, non-commercial project created solely for educational and personal development purposes. It is not intended to infringe upon any copyrights or harm any official products.\n\n'
                  'This application is developed by Rafiq8K, Founder of R8KStudio.\n\n'
                  'If Nexon Games or any related party believes that this application violates any rights or causes concern, please feel free to contact me via email at r8kstudio@gmail.com or through Twitter DM at @rafiq8kbest. I am willing to make necessary adjustments or take appropriate action if required.\n\n'
                  'By reading this disclaimer and continuing to use the application, users are deemed to have agreed to and complied with the Terms of Service set forth by BlueTalk.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide3() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.favorite,
            size: 100,
            color: Color(0xFF135ACF),
          ),
          const SizedBox(height: 48),
          const Text(
            'Ready to start?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF135ACF),
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text('LOGIN'),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RegisterScreen()),
              );
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              side: const BorderSide(color: Color(0xFF135ACF)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              foregroundColor: const Color(0xFF135ACF),
            ),
            child: const Text('REGISTER'),
          ),
        ],
      ),
    );
  }
}
