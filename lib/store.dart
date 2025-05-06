import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorePage extends StatefulWidget {
  const StorePage({super.key});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  int gold = 0;
  int freeze = 0;
  int flash = 0;
  int chest = 0;

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  Future<void> _loadResources() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      gold = prefs.getInt('gold') ?? 0;
      freeze = prefs.getInt('freeze') ?? 0;
      flash = prefs.getInt('flash') ?? 0;
      chest = prefs.getInt('chest') ?? 0;
    });
  }

  Future<void> _saveResources() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('gold', gold);
    await prefs.setInt('freeze', freeze);
    await prefs.setInt('flash', flash);
    await prefs.setInt('chest', chest);
  }

  void _buyItem(String item) {
    const itemCost = 100;
    if (gold >= itemCost) {
      setState(() {
        gold -= itemCost;
        if (item == 'freeze') {
          freeze++;
        } else if (item == 'flash') {
          flash++;
        }
      });
      _saveResources();
    } else {
      _showMessage('Not enough gold!');
    }
  }

  void _openChest() {
    if (chest <= 0) {
      _showMessage('No chest left!');
      return;
    }

    int reward = [5, 10, 15][Random().nextInt(3)];
    setState(() {
      chest--;
      gold += reward;
    });
    _saveResources();
    _showMessage('You received $reward gold!');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Widget _buildResourceRow(String asset, int amount) {
    return Row(
      children: [
        Image.asset('assets/images/$asset', width: 32),
        const SizedBox(width: 8),
        Text('$amount',
            style: const TextStyle(fontSize: 18, color: Colors.white)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // Main UI
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Back button
                  Padding(
                    padding: const EdgeInsets.only(top: 50),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Image.asset(
                          'assets/images/back.png',
                          width: 100,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Resource display
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(top: 20),
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildResourceRow('gold.png', gold),
                            _buildResourceRow('freeze.png', freeze),
                            _buildResourceRow('flash.png', flash),
                          ],
                        ),
                        const SizedBox(height: 30),

                        // freeze Card
                        _buildStoreItem(
                          image: 'freeze.png',
                          title: 'Freeze',
                          description: 'Freeze the enemy. Cost: 100 gold',
                          onPressed: () => _buyItem('freeze'),
                        ),

                        // Flash Card
                        _buildStoreItem(
                          image: 'flash.png',
                          title: 'Flash',
                          description: 'Reveal cards instantly. Cost: 100 gold',
                          onPressed: () => _buyItem('flash'),
                        ),

                        // Chest Card
                        _buildStoreItem(
                          image: 'chest.png',
                          title: 'Mystery Chest (x$chest)',
                          description: 'Open to receive 5, 10 or 15 gold',
                          onPressed: _openChest,
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreItem({
    required String image,
    required String title,
    required String description,
    required VoidCallback onPressed,
  }) {
    return Card(
      color: Colors.black.withOpacity(0.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Image.asset(
              'assets/images/$image',
              width: 50,
              height: 50,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 187, 17, 17),
              ),
              child: const Text(
                'Buy',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
