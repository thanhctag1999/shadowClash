import 'package:flutter/material.dart';
import 'package:runandhit/game1.dart';
import 'package:runandhit/home.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  int unlockedMap = 1; // mặc định nếu không có trong prefs

  @override
  void initState() {
    super.initState();
    _loadMapData();
  }

  Future<void> _loadMapData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      unlockedMap = prefs.getInt('map') ?? 1;
    });
  }

  /// Gọi hàm này ở bất kỳ đâu có `context`
  void showToast(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    // Entry hiển thị toast
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 80, // cách đáy 80px (tuỳ chỉnh)
        left: MediaQuery.of(context).size.width * 0.1,
        width: MediaQuery.of(context).size.width * 0.8,
        child: Material(
          color: Colors.transparent,
          child: _ToastBody(message: message),
        ),
      ),
    );

    // Thêm vào overlay
    overlay.insert(overlayEntry);

    // Tự gỡ sau 2 giây
    Future.delayed(const Duration(seconds: 2), () => overlayEntry.remove());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Ảnh nền
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // Nút Back
          Positioned(
            top: 80,
            left: 16,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const HomePage()),
                  (route) => false,
                );
              },
              child: Image.asset(
                'assets/images/back.png',
                width: 100,
              ),
            ),
          ),

          // Danh sách map
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 80),
              child: ListView.builder(
                itemCount: 3,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemBuilder: (context, index) {
                  int mapIndex = index + 1;
                  String imagePath = (mapIndex <= unlockedMap)
                      ? 'assets/images/map$mapIndex.png'
                      : 'assets/images/lock$mapIndex.png';

                  // bên trong itemBuilder – giữ nguyên phần trên nha
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: GestureDetector(
                      onTap: () {
                        if (mapIndex <= unlockedMap) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => Game1Page(level: mapIndex)),
                          );
                        } else {
                          showToast(context, 'Map is locked');
                        }
                      },
                      child: Column(
                        children: [
                          Image.asset(
                            imagePath,
                            width: 250,
                            height: 250,
                          ),
                          Text(
                            'Map $mapIndex',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 34),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget “ruột” của toast
class _ToastBody extends StatelessWidget {
  const _ToastBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }
}
