import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:runandhit/home.dart';
import 'package:runandhit/map.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

class Game1Page extends StatefulWidget {
  final int level;

  const Game1Page({super.key, required this.level});

  @override
  State<Game1Page> createState() => _Game1PageState();
}

class _Game1PageState extends State<Game1Page> {
  late final AudioPlayer _sfxPlayer;
  int target = 10;
  int nextLevel = 2;
  Offset playerPosition = const Offset(0, 0);
  Offset? targetPosition;
  List<Enemy> enemies = [];
  Timer? spawnTimer;
  int spawnDelay = 800;
  final int minSpawnDelay = 200;
  Timer? enemyMoveTimer;
  Offset? touchPosition;
  Timer? moveTimer;
  bool isDisposed = false;
  List<RotatingSword> swords = [];
  Timer? swordSpawnTimer;
  double swordRotationAngle = 0;

  final double attackRadius = 60.0;
  List<Gold> golds = [];
  List<Heal> heals = [];
  List<Widget> healingEffects = [];
  final newHeals = <Heal>[];
  List<Widget> flyingGolds = [];
  int goldCount = 0;
  int enemiesKilled = 0;
  int health = 5;
  bool isGameOver = false;
  List<Chest> chests = [];
  int chestCount = 0;
  int freezeCount = 0;
  int flashCount = 0;
  int magnetCount = 0;
  int powerCount = 0;
  List<Widget> magnetGlow = []; // quầng sáng
  bool magnetActive = false; // nam châm đang chạy?
  Timer? magnetTimer;
  bool isFrozen = false;
  List<Widget> moveMarkers = [];
  List<Widget> lightningEffects = [];
  List<Widget> hitEffects = [];
  bool powerActive = false;
  Timer? powerTimer;
  List<Widget> powerAuras = [];

  double baseSpeed = 3; // tốc độ gốc
  double playerSpeed = 3; // luôn dùng biến này thay vì hằng
  double baseSwordRot = 0.05; // tốc độ xoay gốc
  double swordRotSpeed = 0.05; // biến dùng trong updateSwordRotation
  Duration swordSpawnInterval = const Duration(seconds: 4); // gốc

  @override
  void initState() {
    super.initState();
    _sfxPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    setVarable();
    loadGoldFromPrefs();
    loadPowerupsFromPrefs();
    startSpawnLoop();

    moveTimer =
        Timer.periodic(const Duration(milliseconds: 16), (_) => movePlayer());
    // Di chuyển mỗi frame 60fps
    moveTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      moveTowardTouch();
      updateSwordRotation();
      attractItems();

      // nếu đang buff thì reposition aura
      if (powerActive && powerAuras.isNotEmpty) {
        powerAuras[0] = PowerAura(center: playerPosition);
      }
    });
    enemyMoveTimer =
        Timer.periodic(const Duration(milliseconds: 30), (_) => moveEnemies());

    swordSpawnTimer = Timer.periodic(swordSpawnInterval, (_) => spawnSwords());
  }

  void setVarable() {
    if (widget.level == 1) {
      target = 100;
      nextLevel = 2;
      spawnDelay = 800;
    } else if (widget.level == 2) {
      target = 150;
      nextLevel = 3;
      spawnDelay = 600;
    } else {
      target = 200;
      nextLevel = 4;
      spawnDelay = 400;
    }
  }

  void showHitEffect(Offset pos) {
    final key = UniqueKey();

    safeSetState(() {
      hitEffects.add(
        Positioned(
          key: key,
          left: pos.dx - 25,
          top: pos.dy - 25,
          child: Image.asset(
            'assets/images/enemy1.png',
            width: 50,
            color: Colors.red, // 🔴 tô đỏ
            colorBlendMode: BlendMode.modulate,
          ),
        ),
      );
    });

    // Tắt sau 100 ms
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && !isDisposed) {
        safeSetState(() => hitEffects.removeWhere((w) => w.key == key));
      }
    });
  }

  Future<void> loadPowerupsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      freezeCount = prefs.getInt('freeze') ?? 0;
      flashCount = prefs.getInt('flash') ?? 0;
      magnetCount = prefs.getInt('magnet') ?? 0;
      powerCount = prefs.getInt('power') ?? 0;
    });
  }

  Future<void> loadChestFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      chestCount = prefs.getInt('chest') ?? 0;
    });
  }

  Future<void> saveChestToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('chest', chestCount);
  }

  void showMoveMarker(Offset pos) {
    final key = UniqueKey();

    safeSetState(() {
      moveMarkers
        ..clear() // ⚡ xoá marker cũ
        ..add(
          Positioned(
            key: key,
            left: pos.dx - 24,
            top: pos.dy - 24,
            child: Image.asset('assets/images/move.png', width: 48),
          ),
        );
    });

    // Tự biến mất sau 3 giây
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !isDisposed) {
        safeSetState(() {
          moveMarkers.removeWhere((w) => w.key == key);
        });
      }
    });
  }

  Future<void> _playHurtSound() async {
    try {
      await _sfxPlayer.play(
        AssetSource('sounds/hurt.mp3'),
        volume: 0.8,
      );
    } catch (_) {/* ignore */}
  }

  void startSpawnLoop() {
    spawnTimer = Timer(Duration(milliseconds: spawnDelay), () {
      spawnEnemy();

      // Giảm độ trễ xuống mỗi lần, tối đa về 200ms
      if (spawnDelay > minSpawnDelay) {
        spawnDelay -= 10;
      }

      startSpawnLoop(); // lặp lại với delay mới
    });
  }

  void updateSwordRotation() {
    safeSetState(() {
      swordRotationAngle += swordRotSpeed; // tốc độ xoay
    });
  }

  Future<void> loadGoldFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    safeSetState(() {
      goldCount = prefs.getInt('gold') ?? 0;
    });
  }

  void addGold(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    safeSetState(() {
      goldCount += amount;
    });
    await prefs.setInt('gold', goldCount);
  }

  void safeSetState(VoidCallback fn) {
    if (mounted && !isDisposed) {
      setState(fn);
    }
  }

  void moveTowardTouch() {
    if (touchPosition == null) return;

    final direction = (touchPosition! - playerPosition);
    final distance = direction.distance;

    if (distance < playerSpeed) {
      playerPosition = touchPosition!;
    } else {
      final movement = direction / distance * playerSpeed;
      safeSetState(() {
        playerPosition += movement;
      });
    }

    collectGolds(); // nếu có gold nhặt
    collectHeals(); // nếu có gold nhặt
    collectChests(); // nếu có gold nhặt
  }

  @override
  void dispose() {
    _sfxPlayer.dispose();
    spawnTimer?.cancel();
    swordSpawnTimer?.cancel();
    isDisposed = true;
    moveTimer?.cancel();
    enemyMoveTimer?.cancel();
    super.dispose();
  }

  void spawnEnemy() {
    final rand = Random();
    final screenSize = MediaQuery.of(context).size;
    double x = rand.nextBool() ? -50.0 : screenSize.width + 50;
    double y = rand.nextDouble() * screenSize.height;

    safeSetState(() {
      enemies.add(Enemy(position: Offset(x, y)));
    });
  }

  void movePlayer() {
    if (targetPosition != null) {
      final direction = (targetPosition! - playerPosition);
      final distance = direction.distance;
      if (distance < playerSpeed) {
        playerPosition = targetPosition!;
        targetPosition = null;
      } else {
        final movement = direction / distance * playerSpeed;
        safeSetState(() {
          playerPosition += movement;
        });
      }
      moveEnemies();
    }
    collectGolds();
    collectHeals();
  }

  Future<void> _playAttackSound() async {
    try {
      await _sfxPlayer.play(AssetSource('sounds/attack.mp3'), volume: 0.7);
    } catch (e) {
      // ignore hoặc debugPrint('Sound error: $e');
    }
  }

  void moveEnemies() {
    if (isFrozen) return;
    final updatedEnemies = <Enemy>[];
    final newGolds = <Gold>[];
    final newHeals = <Heal>[];
    final newChests = <Chest>[];

    for (final enemy in enemies) {
      final dir = (playerPosition - enemy.position).normalize();
      final newPos = enemy.position + dir * 1.2;

      bool isKilled = false;

      // Kiểm tra va chạm với sword nếu có sword đang xoay
      if (swords.isNotEmpty) {
        final hitBySword = swords.any((sword) {
          final angle = swordRotationAngle + sword.angleOffset;
          final swordX = playerPosition.dx + cos(angle) * 60;
          final swordY = playerPosition.dy + sin(angle) * 60;
          final swordPos = Offset(swordX, swordY);
          return (enemy.position - swordPos).distance < 40;
        });

        if (hitBySword) {
          showHitEffect(enemy.position);
          enemiesKilled++;

          if (enemiesKilled >= target && !isGameOver) {
            triggerWin();
            return; // kết thúc sớm
          }

          final roll = Random().nextInt(100); // 0–99

          if (roll < 5) {
            newChests.add(Chest(position: enemy.position)); // 5% rơi rương
          } else if (roll < 15) {
            newGolds.add(Gold(position: enemy.position)); // 10% gold
          } else if (roll < 35) {
            newHeals.add(Heal(position: enemy.position)); // 20% heal
          }

          isKilled = true;
        }
      }

      // Nếu không bị tiêu diệt bởi sword, kiểm tra va chạm với player
      if (!isKilled) {
        final isTouchingPlayer = (newPos - playerPosition).distance < 30;
        if (isTouchingPlayer && !isGameOver) {
          takeDamage();
          continue; // enemy biến mất luôn sau khi gây damage
        }

        // Nếu không chạm sword hoặc player → tiếp tục sống
        updatedEnemies.add(Enemy(position: newPos));
      }
    }

    safeSetState(() {
      enemies = updatedEnemies;
      golds.addAll(newGolds);
      heals.addAll(newHeals);
      chests.addAll(newChests);
    });
  }

  void restartGame() {
    loadGoldFromPrefs();
    // Hủy các timer cũ (nếu chưa chắc)
    spawnTimer?.cancel();
    moveTimer?.cancel();
    enemyMoveTimer?.cancel();
    swordSpawnTimer?.cancel();

    setState(() {
      enemies.clear();
      golds.clear();
      heals.clear();
      swords.clear();
      healingEffects.clear();

      health = 5;
      enemiesKilled = 0;
      isGameOver = false;
      touchPosition = null;
      goldCount = 0;

      spawnDelay = 800; // reset tốc độ spawn ban đầu
    });

    // Khởi động lại game loop
    startSpawnLoop();
    moveTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      moveTowardTouch();
      updateSwordRotation();
    });
    enemyMoveTimer =
        Timer.periodic(const Duration(milliseconds: 30), (_) => moveEnemies());
    swordSpawnTimer =
        Timer.periodic(const Duration(seconds: 4), (_) => spawnSwords());
  }

  void spawnSwords() {
    _playAttackSound();
    safeSetState(() {
      swords = List.generate(5, (i) => RotatingSword(i * 2 * pi / 5));
    });

    // 👉 chỉ clear nếu KHÔNG trong trạng thái power
    if (!powerActive) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && !isGameOver && !powerActive) {
          safeSetState(() => swords.clear());
        }
      });
    }
  }

  void takeDamage() {
    if (health > 0) {
      _playHurtSound();
      safeSetState(() {
        health--;
      });

      if (health == 0 && !isGameOver) {
        triggerGameOver();
      }
    }
  }

  void activatePower() async {
    // 1️⃣ Trừ lượt, bật cờ buff + buff chỉ số
    setState(() {
      powerCount--;
      powerActive = true; // đặt TRUE trước khi spawnSwords xoá
      playerSpeed = baseSpeed * 1.8;
      swordRotSpeed = baseSwordRot * 4;
    });
    (await SharedPreferences.getInstance()).setInt('power', powerCount);

    // 2️⃣ Aura
    powerAuras
      ..clear()
      ..add(PowerAura(center: playerPosition));

    // 3️⃣ Dừng timer cũ & sinh kiếm ngay lập tức
    swordSpawnTimer?.cancel();
    spawnSwords(); // dùng hàm sẵn có – sẽ KHÔNG clear

    // 4️⃣ Giữ buff 10 s rồi reset
    powerTimer?.cancel();
    powerTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;

      setState(() {
        powerActive = false;
        playerSpeed = baseSpeed;
        swordRotSpeed = baseSwordRot;
        swords.clear();
        powerAuras.clear();
      });

      // khởi động lại timer burst 4 s
      swordSpawnInterval = const Duration(seconds: 4);
      swordSpawnTimer =
          Timer.periodic(swordSpawnInterval, (_) => spawnSwords());
    });
  }

  void attractItems() {
    if (!magnetActive) return;

    const pullSpeed = 8.0;

    _playItemSound();

    safeSetState(() {
      // GOLD
      for (var g in golds) {
        if (!g.collected) {
          final dir = (playerPosition - g.position).normalize();
          g.position += dir * pullSpeed;
          if ((g.position - playerPosition).distance < 25) {
            g.collected = true;
            addGold(1);
          }
        }
      }
      golds.removeWhere((g) => g.collected);

      // HEAL
      for (var h in heals) {
        if (!h.collected) {
          final dir = (playerPosition - h.position).normalize();
          h.position += dir * pullSpeed;
          if ((h.position - playerPosition).distance < 25) {
            h.collected = true;
            health = 5;
          }
        }
      }
      heals.removeWhere((h) => h.collected);

      // CHEST
      for (var c in chests) {
        if (!c.collected) {
          final dir = (playerPosition - c.position).normalize();
          c.position += dir * pullSpeed;
          if ((c.position - playerPosition).distance < 25) {
            c.collected = true;
            chestCount++;
            saveChestToPrefs();
          }
        }
      }
      chests.removeWhere((c) => c.collected);
    });
  }

  Future<void> activateMagnet() async {
    // 0) Trừ lượt & lưu
    setState(() {
      magnetCount--;
      magnetActive = true;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('magnet', magnetCount);

    // 1) Hiệu ứng quầng sáng quanh nhân vật
    final glowKey = UniqueKey();
    safeSetState(() {
      magnetGlow
        ..clear() // luôn chỉ 1 glow
        ..add(MagnetPulse(
          key: glowKey,
          position: playerPosition,
        ));
    });

    // 2) Kéo vật phẩm về phía player trong 2 giây
    magnetTimer?.cancel();
    magnetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        safeSetState(() {
          magnetActive = false;
          magnetGlow.removeWhere((w) => w.key == glowKey);
        });
      }
    });
  }

  void activateFreeze() async {
    setState(() {
      freezeCount--;
      isFrozen = true;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('freeze', freezeCount);

    // Freeze trong 2 giây
    await Future.delayed(const Duration(seconds: 2));

    if (mounted && !isGameOver) {
      setState(() {
        isFrozen = false;
      });
    }
  }

  Future<void> _playGameOverSound() async {
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource('sounds/gameover.mp3'), volume: 0.9);
    } catch (_) {/* ignore */}
  }

  void activateFlash() async {
    _playFlashSound();
    safeSetState(() {
      flashCount--;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('flash', flashCount);

    // Hiển thị hiệu ứng lightning tại vị trí enemy
    for (var e in enemies) {
      showHitEffect(e.position);
      final effect = Positioned(
        left: e.position.dx - 32,
        top: e.position.dy - 32,
        child: Image.asset(
          'assets/images/lightning.png',
          width: 64,
        ),
      );

      lightningEffects.add(effect);
    }

    safeSetState(() {});

    // Delay 300ms rồi xóa effect và enemy
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted && !isGameOver) {
      setState(() {
        enemiesKilled += enemies.length;
        enemies.clear();
        lightningEffects.clear();
      });

      if (enemiesKilled >= 100 && !isGameOver) {
        triggerWin();
      }
    }
  }

  Future<void> _playItemSound() async {
    try {
      await _sfxPlayer.play(AssetSource('sounds/get.mp3'), volume: 0.8);
    } catch (_) {/* ignore */}
  }

  Future<void> triggerWin() async {
    isGameOver = true;
    _playGameOverSound();
    // Hủy tất cả timer
    spawnTimer?.cancel();
    moveTimer?.cancel();
    enemyMoveTimer?.cancel();
    swordSpawnTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();

    prefs.setInt('map', nextLevel);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset('assets/images/popup.png'),
            Positioned(
              top: 60,
              child: Column(
                children: [
                  const Text(
                    "You Win!",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.yellow,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Enemies defeated: $enemiesKilled",
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/images/gold.png', width: 24),
                      const SizedBox(width: 6),
                      Text(
                        '$goldCount',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (context) => const MapPage()),
                            (route) => false,
                          );
                        },
                        child:
                            Image.asset('assets/images/back.png', width: 100),
                      ),
                      const SizedBox(width: 40),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop();
                          restartGame(); // chơi lại
                        },
                        child:
                            Image.asset('assets/images/replay.png', width: 100),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void triggerGameOver() {
    isGameOver = true;
    _playGameOverSound();

    // Hủy mọi Timer nếu muốn
    spawnTimer?.cancel();
    moveTimer?.cancel();
    enemyMoveTimer?.cancel();
    swordSpawnTimer?.cancel();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Nền dialog
            Image.asset('assets/images/popup.png'),

            // Nội dung chính
            Positioned(
              top: 60,
              child: Column(
                children: [
                  const Text(
                    "Game Over",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    "Enemies defeated: $enemiesKilled",
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/images/gold.png', width: 24),
                      const SizedBox(width: 6),
                      Text(
                        '$goldCount',
                        style:
                            const TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/images/chest.png', width: 24),
                      const SizedBox(width: 6),
                      Text(
                        '$chestCount',
                        style:
                            const TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Nút back và replay
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop(); // về home
                        },
                        child:
                            Image.asset('assets/images/back.png', width: 100),
                      ),
                      const SizedBox(width: 40),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop(); // đóng dialog
                          restartGame(); // bạn cần định nghĩa hàm này
                        },
                        child:
                            Image.asset('assets/images/replay.png', width: 100),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _playFlashSound() async {
    try {
      await _sfxPlayer.play(
        AssetSource('sounds/flash.mp3'),
        volume: 0.9,
      );
    } catch (_) {/* ignore */}
  }

  void collectGolds() {
    final List<Gold> collected = [];

    for (var g in golds) {
      if (!g.collected && (g.position - playerPosition).distance < 30) {
        g.collected = true;
        collected.add(g);
        _playItemSound();

        // Xác định vị trí bay
        final start = g.position;
        final end = Offset(MediaQuery.of(context).size.width - 60, 40);

        // Thêm hiệu ứng bay
        flyingGolds.add(
          AnimatedFlyingGold(
            key: UniqueKey(),
            start: start,
            end: end,
            onComplete: () {
              safeSetState(() {
                goldCount++;
                flyingGolds.removeWhere(
                    (w) => w.key == UniqueKey()); // Sửa theo key nếu cần
              });
            },
          ),
        );
        addGold(1);
      }
    }

    // Xoá khỏi danh sách golds
    safeSetState(() {
      golds.removeWhere((g) => collected.contains(g));
    });
  }

  void collectChests() {
    final collected = <Chest>[];

    for (var c in chests) {
      if (!c.collected && (c.position - playerPosition).distance < 30) {
        c.collected = true;
        collected.add(c);
        _playItemSound();

        // Hiệu ứng + cộng chest
        safeSetState(() {
          chestCount++;
        });
        saveChestToPrefs();

        // Hiệu ứng flash hoặc pop
        healingEffects.add(
          Positioned(
            left: playerPosition.dx - 32,
            top: playerPosition.dy - 32,
            child: Image.asset('assets/images/chest.png', width: 64),
          ),
        );
        Future.delayed(const Duration(milliseconds: 500), () {
          safeSetState(() {
            healingEffects.clear();
          });
        });
      }
    }

    safeSetState(() {
      chests.removeWhere((c) => collected.contains(c));
    });
  }

  void collectHeals() {
    final collectedHeals = <Heal>[];

    for (var h in heals) {
      if (!h.collected && (h.position - playerPosition).distance < 30) {
        h.collected = true;
        collectedHeals.add(h);

        _playItemSound();

        // Hồi đầy máu
        safeSetState(() {
          health = 5;
        });

        // Tạo hiệu ứng healing
        final effect = Positioned(
          left: playerPosition.dx - 32,
          top: playerPosition.dy - 32,
          child: Image.asset(
            'assets/images/healing.png',
            width: 64,
          ),
        );

        safeSetState(() {
          healingEffects.add(effect);
        });

        // Xoá hiệu ứng sau 500ms
        Future.delayed(const Duration(milliseconds: 500), () {
          safeSetState(() {
            healingEffects.remove(effect);
          });
        });
      }
    }

    // Xoá heal đã nhặt
    safeSetState(() {
      heals.removeWhere((h) => collectedHeals.contains(h));
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final center = Offset(size.width / 2, size.height / 2);
    if (playerPosition == const Offset(0, 0)) playerPosition = center;

    return Scaffold(
      body: GestureDetector(
        onPanStart: (details) {
          final pos = details.localPosition;
          safeSetState(() => touchPosition = pos);
          showMoveMarker(pos); // 👉 luôn add marker mới
        },
        onPanUpdate: (details) {
          // Giữ touchPosition để nhân vật tiếp tục đuổi theo con trỏ
          safeSetState(() => touchPosition = details.localPosition);
        },
        onPanEnd: (_) {
          safeSetState(() => touchPosition = null);
        },
        child: Stack(
          children: [
            // Background
            Positioned.fill(
              child: Image.asset(
                  widget.level == 1
                      ? 'assets/images/background1.jpg'
                      : widget.level == 2
                          ? 'assets/images/background2.jpg'
                          : 'assets/images/background3.jpg',
                  fit: BoxFit.cover),
            ),

            // Back button
            Positioned(
              top: 80,
              left: 20,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const HomePage()),
                  (route) => false,
                ),
                child: Image.asset('assets/images/back.png', width: 100),
              ),
            ),

            // Player
            ...magnetGlow,
            ...powerAuras,
            Positioned(
              left: playerPosition.dx - 25,
              top: playerPosition.dy - 25,
              child: Transform.scale(
                scale: powerActive ? 1.5 : 1.0, // to lên 1.5×
                child: Image.asset('assets/images/player.png', width: 50),
              ),
            ),
            ...healingEffects,
            ...hitEffects,
            // Enemies
            ...enemies.map((e) {
              return Stack(
                children: [
                  // Enemy hình ảnh
                  Positioned(
                    left: e.position.dx - 25,
                    top: e.position.dy - 25,
                    child: Image.asset('assets/images/enemy1.png', width: 50),
                  ),

                  // Hiệu ứng băng khi đóng băng
                  if (isFrozen)
                    Positioned(
                      left: e.position.dx - 25,
                      top: e.position.dy - 25,
                      child: Image.asset('assets/images/ice.png', width: 50),
                    ),
                ],
              );
            }),

            ...golds.map((g) {
              return Positioned(
                left: g.position.dx - 16,
                top: g.position.dy - 16,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: g.opacity,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 300),
                    scale: g.scale,
                    child: Image.asset(
                      'assets/images/gold.png',
                      width: 32,
                    ),
                  ),
                ),
              );
            }),
            ...heals.map((h) => Positioned(
                  left: h.position.dx - 16,
                  top: h.position.dy - 16,
                  child: Image.asset('assets/images/heal.png', width: 24),
                )),
            ...chests.map((c) => Positioned(
                  left: c.position.dx - 16,
                  top: c.position.dy - 16,
                  child: Image.asset('assets/images/chest.png', width: 32),
                )),
            // 👉 Gold bay lên (hiệu ứng)
            ...flyingGolds,
            ...lightningEffects,
            ...swords.map((sword) {
              final angle = swordRotationAngle + sword.angleOffset;
              const radius = 60.0;

              final swordX = playerPosition.dx + cos(angle) * radius;
              final swordY = playerPosition.dy + sin(angle) * radius;

              return Positioned(
                left: swordX - 16,
                top: swordY - 16,
                child: Transform.rotate(
                  angle: angle + pi / 2, // ⬅️ Xoay thêm 90 độ để hướng ra ngoài
                  child: Image.asset('assets/images/sword.png', width: 24),
                ),
              );
            }),

            Positioned(
              top: 110,
              right: 20,
              child: Row(
                children: [
                  Image.asset('assets/images/gold.png', width: 24),
                  const SizedBox(width: 6),
                  Text('$goldCount',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
            ),
            Positioned(
              top: 80,
              right: 20,
              child: Row(
                children: List.generate(5, (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Image.asset(
                      'assets/images/heart.png',
                      width: 24,
                      color: index < health
                          ? null
                          : Colors.grey, // hết máu thì mờ đi
                    ),
                  );
                }),
              ),
            ),
            ...moveMarkers,
            Positioned(
              top: 160,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (flashCount > 0 && !isGameOver) {
                        activateFlash();
                      }
                    },
                    child: Row(
                      children: [
                        Image.asset('assets/images/flash.png', width: 24),
                        const SizedBox(width: 6),
                        Text(
                          '$flashCount',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () {
                      if (freezeCount > 0 && !isGameOver) {
                        activateFreeze();
                      }
                    },
                    child: Row(
                      children: [
                        Image.asset('assets/images/freeze.png', width: 24),
                        const SizedBox(width: 6),
                        Text(
                          '$freezeCount',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () {
                      if (magnetCount > 0 && !isGameOver) {
                        activateMagnet();
                      }
                    },
                    child: Row(
                      children: [
                        Image.asset('assets/images/magnet.png', width: 24),
                        const SizedBox(width: 6),
                        Text(
                          '$magnetCount',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () {
                      if (powerCount > 0 && !isGameOver) {
                        activatePower();
                      }
                    },
                    child: Row(
                      children: [
                        Image.asset('assets/images/power.png', width: 24),
                        const SizedBox(width: 6),
                        Text(
                          '$powerCount',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
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
}

class Enemy {
  final Offset position;
  Enemy({required this.position});
}

class RotatingSword {
  final double angleOffset; // góc lệch ban đầu
  RotatingSword(this.angleOffset);
}

extension OffsetExtensions on Offset {
  Offset normalize() {
    final length = distance;
    return length == 0 ? Offset.zero : this / length;
  }
}

class Chest {
  Offset position;
  bool collected;

  Chest({required this.position, this.collected = false});
}

class Gold {
  Offset position;
  bool collected;
  double opacity;
  double scale;

  Gold({
    required this.position,
    this.collected = false,
    this.opacity = 1.0,
    this.scale = 1.0,
  });
}

class Heal {
  Offset position;
  bool collected;

  Heal({required this.position, this.collected = false});
}

class AnimatedFlyingGold extends StatefulWidget {
  final Offset start;
  final Offset end;
  final VoidCallback onComplete;

  const AnimatedFlyingGold({
    super.key,
    required this.start,
    required this.end,
    required this.onComplete,
  });

  @override
  State<AnimatedFlyingGold> createState() => _AnimatedFlyingGoldState();
}

class _AnimatedFlyingGoldState extends State<AnimatedFlyingGold>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _position;
  late Animation<double> _scale;

  @override
  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _position = Tween<Offset>(begin: widget.start, end: widget.end)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _scale = Tween<double>(begin: 1.0, end: 0.5).animate(_controller);

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  Widget build(BuildContext context) {
    return _controller.isCompleted
        ? const SizedBox.shrink() // khi xong thì ẩn
        : AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              return Positioned(
                left: _position.value.dx - 28,
                top: _position.value.dy + 55,
                child: Transform.scale(
                  scale: _scale.value,
                  child: Image.asset('assets/images/gold.png', width: 32),
                ),
              );
            },
          );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class MagnetPulse extends StatefulWidget {
  final Offset position;
  final double size;
  const MagnetPulse({
    super.key,
    required this.position,
    this.size = 80,
  });

  @override
  State<MagnetPulse> createState() => _MagnetPulseState();
}

class _MagnetPulseState extends State<MagnetPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true); // phồng–xẹp loop

    _scale = Tween(begin: 1.0, end: 1.25).animate(_ctrl);
    _opacity = Tween(begin: 0.7, end: 0.15).animate(_ctrl);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Positioned(
        left: widget.position.dx - widget.size / 2,
        top: widget.position.dy - widget.size / 2,
        child: Transform.scale(
          scale: _scale.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // RadialGradient cho cảm giác “năng lượng”
              gradient: RadialGradient(
                colors: [
                  Colors.cyanAccent.withOpacity(_opacity.value),
                  Colors.transparent
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}

class PowerAura extends StatefulWidget {
  final Offset center;
  const PowerAura({super.key, required this.center});

  @override
  State<PowerAura> createState() => _PowerAuraState();
}

class _PowerAuraState extends State<PowerAura>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale;
  late final Animation<double> _angle;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(); // loop liên tục

    _scale = Tween(begin: .9, end: 1.3)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

    _angle = Tween(begin: 0.0, end: 2 * pi).animate(_c);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final size = 90 * _scale.value; // phồng–xẹp
        return Positioned(
          left: widget.center.dx - size / 2,
          top: widget.center.dy - size / 2,
          child: Transform.rotate(
            angle: _angle.value, // xoay tròn
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  // “xoáy” vàng–cam
                  colors: [
                    Colors.deepOrangeAccent.withOpacity(.0),
                    Colors.yellow.withOpacity(.7),
                    Colors.orange.withOpacity(.0),
                  ],
                  stops: const [0.25, 0.55, 1],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amberAccent.withOpacity(.5),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }
}
