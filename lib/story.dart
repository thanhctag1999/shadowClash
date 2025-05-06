import 'package:flutter/material.dart';

class StoryPage extends StatelessWidget {
  const StoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Ảnh nền
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.jpg', // đổi nếu bạn có ảnh nền riêng cho story
              fit: BoxFit.cover,
            ),
          ),

          // Nút back
          Positioned(
            top: 80,
            left: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Image.asset('assets/images/back.png', width: 100),
            ),
          ),

          // Nội dung cốt truyện
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 150, 20, 20),
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '''
🌑 In a world consumed by darkness, where light has been erased by an ancient evil force, monstrous creatures roam freely and grow stronger each day.

You — a nameless warrior — are the final hope of a land once bathed in light. Armed with a spinning blade of pure energy, you enter a relentless battle for survival deep within the shadows.

⚔️ Each wave of monsters brings greater danger. They grow faster, smarter, and deadlier. But you are not alone — legendary relics like time-freezing crystals, lightning strikes, and mysterious treasure chests grant you power beyond imagination.

🎯 Your mission: eliminate enough monsters to pass each level and uncover the long-forgotten secrets of this world before darkness devours everything.

Will you fall like the warriors before you...
Or will you become the legend that brings light back to the world?

💫 The battle begins now.
  ''',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.justify,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
