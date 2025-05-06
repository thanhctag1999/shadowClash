import 'package:flutter/material.dart';
import 'package:runandhit/map.dart';
import 'package:runandhit/store.dart';
import 'package:runandhit/story.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Ảnh nền full màn hình
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // Nội dung chính nằm trong SafeArea
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),

                    // Tiêu đề
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

                    // Nút Start
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => const MapPage()));
                      },
                      child: Image.asset(
                        'assets/images/start.png',
                        width: 200,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Nút Store
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => const StorePage()));
                      },
                      child: Image.asset(
                        'assets/images/store.png',
                        width: 200,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Nút Story
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => const StoryPage()));
                      },
                      child: Image.asset(
                        'assets/images/story.png',
                        width: 200,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
