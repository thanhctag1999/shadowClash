import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:runandhit/home.dart';
import 'package:runandhit/map.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Game1Page extends StatefulWidget {
  final int level;

  const Game1Page({super.key, required this.level});

  @override
  State<Game1Page> createState() => _Game1PageState();
}

class _Game1PageState extends State<Game1Page> {
  int target = 10;
  int nextLevel = 2;
  Offset playerPosition = const Offset(0, 0);
  Offset? targetPosition;
  List<Enemy> enemies = [];
  final double playerSpeed = 3;
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
  bool isFrozen = false;
  List<Widget> lightningEffects = [];

  @override
  void initState() {
    super.initState();
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
    });
    enemyMoveTimer =
        Timer.periodic(const Duration(milliseconds: 30), (_) => moveEnemies());

    swordSpawnTimer =
        Timer.periodic(const Duration(seconds: 4), (_) => spawnSwords());
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

  Future<void> loadPowerupsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      freezeCount = prefs.getInt('freeze') ?? 0;
      flashCount = prefs.getInt('flash') ?? 0;
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
      swordRotationAngle += 0.05; // tốc độ xoay
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
    safeSetState(() {
      swords = List.generate(5, (i) => RotatingSword(i * 2 * pi / 5));
    });

    // Xoá kiếm sau 1 giây
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && !isGameOver) {
        safeSetState(() {
          swords.clear();
        });
      }
    });
  }

  void takeDamage() {
    if (health > 0) {
      safeSetState(() {
        health--;
      });

      if (health == 0 && !isGameOver) {
        triggerGameOver();
      }
    }
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

  void activateFlash() async {
    safeSetState(() {
      flashCount--;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('flash', flashCount);

    // Hiển thị hiệu ứng lightning tại vị trí enemy
    for (var e in enemies) {
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

  Future<void> triggerWin() async {
    isGameOver = true;

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

  void collectGolds() {
    final List<Gold> collected = [];

    for (var g in golds) {
      if (!g.collected && (g.position - playerPosition).distance < 30) {
        g.collected = true;
        collected.add(g);

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
          safeSetState(() {
            touchPosition = details.localPosition;
          });
        },
        onPanUpdate: (details) {
          safeSetState(() {
            touchPosition = details.localPosition;
          });
        },
        onPanEnd: (_) {
          safeSetState(() {
            touchPosition = null;
          });
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
            Positioned(
              left: playerPosition.dx - 25,
              top: playerPosition.dy - 25,
              child: Image.asset('assets/images/player.png', width: 50),
            ),
            ...healingEffects,
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
