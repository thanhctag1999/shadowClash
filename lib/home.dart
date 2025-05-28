import 'dart:async';
import 'package:flutter/material.dart';
import 'package:runandhit/map.dart';
import 'package:runandhit/store.dart';
import 'package:runandhit/story.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat(reverse: true);
    _fadeAnimation = Tween<double>(begin: 0.3, end: 1).animate(_fadeController);

    Future.delayed(const Duration(seconds: 4), () {
      _fadeController.stop();
      setState(() {
        _isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.jpg',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Center(
              child: _isLoading
                  ? FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          const Text(
                            'Shadow Slash',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  offset: Offset(2, 2),
                                  blurRadius: 4,
                                  color: Colors.black54,
                                )
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Loading...',
                            style: TextStyle(
                              fontSize: 28,
                              color: Color.fromARGB(255, 187, 17, 17),
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(
                                  offset: Offset(1, 1),
                                  blurRadius: 3,
                                  color: Colors.black45,
                                )
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          const CircularProgressIndicator(
                            color: Color.fromARGB(255, 187, 17, 17),
                          ),
                        ],
                      ),
                    )
                  : _buildMainContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const Text(
            'Shadow Slash',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  offset: Offset(2, 2),
                  blurRadius: 4,
                  color: Colors.black54,
                )
              ],
            ),
          ),
          const SizedBox(height: 60),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MapPage()),
            ),
            child: Image.asset('assets/images/start.png', width: 200),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StorePage()),
            ),
            child: Image.asset('assets/images/store.png', width: 200),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StoryPage()),
            ),
            child: Image.asset('assets/images/story.png', width: 200),
          ),
        ],
      ),
    );
  }
}
