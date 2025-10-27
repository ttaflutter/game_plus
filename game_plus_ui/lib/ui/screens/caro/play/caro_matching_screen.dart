import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:game_plus/configs/app_config.dart';
import 'package:game_plus/services/auth_service.dart';

/// Màn hình loading tìm đối thủ với animation chuyên nghiệp
class CaroMatchingScreen extends StatefulWidget {
  final String? myUsername;
  final String? myAvatar;
  final int? myRating;
  final Future<int?> Function()? onFindMatch;
  final Function(int matchId, int myRating, int opponentRating)?
  onMatchFound; // Thêm ratings

  const CaroMatchingScreen({
    super.key,
    this.myUsername,
    this.myAvatar,
    this.myRating,
    this.onFindMatch,
    this.onMatchFound,
  });

  @override
  State<CaroMatchingScreen> createState() => _CaroMatchingScreenState();
}

class _CaroMatchingScreenState extends State<CaroMatchingScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotateController;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _rotateAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideLeftAnimation;
  late Animation<Offset> _slideRightAnimation;

  bool _isMatched = false;
  bool _isPreparing = false; // Trạng thái đang chuẩn bị phòng
  int _preparingCountdown = 5; // Countdown 5 giây
  Timer? _preparingTimer;
  String? _opponentUsername;
  int? _opponentRating;
  String? _opponentAvatar;
  int? _currentMatchId;
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  bool _isCancelled = false;

  @override
  void initState() {
    super.initState();

    // Rotate animation cho icon VS
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _rotateAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(parent: _rotateController, curve: Curves.linear));

    // Pulse animation cho các player cards
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Slide animation khi tìm thấy đối thủ
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _slideLeftAnimation =
        Tween<Offset>(begin: const Offset(-2, 0), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
        );

    _slideRightAnimation =
        Tween<Offset>(begin: const Offset(2, 0), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
        );

    // Start finding match
    _findMatch();
  }

  Future<void> _findMatch() async {
    try {
      // Get token
      final token = await AuthService.getToken();
      if (token == null) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Vui lòng đăng nhập')));
        }
        return;
      }

      print("🔑 Token: ${token.substring(0, 20)}...");

      // Connect WebSocket
      final wsUrl = AppConfig.wsMatchmakingUrl(token);
      print("🔌 Connecting to matchmaking WebSocket: $wsUrl");

      try {
        _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
        print("✅ WebSocket connection initiated");

        // Listen to messages
        _wsSubscription = _wsChannel!.stream.listen(
          (data) {
            if (_isCancelled) {
              print("⏭️ Ignoring message after cancellation");
              return;
            }

            try {
              print("📩 Raw message: $data");
              final message = jsonDecode(data);
              _handleWebSocketMessage(message);
            } catch (e) {
              print("⚠️ Error parsing WebSocket message: $e");
            }
          },
          onError: (error) {
            if (_isCancelled) {
              print("⏭️ Ignoring error after cancellation");
              return;
            }

            print("❌ WebSocket error: $error");
            if (mounted) {
              // Close WebSocket before showing error
              _cleanupWebSocket();

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Lỗi kết nối matchmaking.\n'
                    'Kiểm tra backend đã chạy?\n'
                    'URL: $wsUrl',
                  ),
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          },
          onDone: () {
            if (_isCancelled) {
              print("⏭️ Ignoring onDone after cancellation");
              return;
            }

            print("🔌 WebSocket connection closed");
            if (mounted && !_isMatched) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Kết nối bị đóng. Vui lòng thử lại.'),
                ),
              );
            }
          },
        );
      } catch (wsError) {
        print("❌ WebSocket connection error: $wsError");
        throw wsError;
      }
    } catch (e) {
      print("❌ Error in _findMatch: $e");
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể kết nối: ${e.toString()}')),
        );
      }
    }
  }

  void _handleWebSocketMessage(Map<String, dynamic> message) {
    final type = message['type'];
    final payload = message['payload'];

    print("📨 Received message: $type");

    switch (type) {
      case 'searching':
        print(
          "🔍 Searching for opponent... Queue size: ${payload['queue_size']}",
        );
        break;

      case 'match_found':
        print("✅ Match found!");
        final matchId = payload['match_id'];
        final players = payload['players'] as List;

        _currentMatchId = matchId; // Store for debugging
        print("🎮 Match ID: $_currentMatchId");
        print("👥 Players: $players");

        // Find opponent (player khác với mình)
        final opponent = players.firstWhere(
          (p) => p['username'] != widget.myUsername,
          orElse: () => players.length > 1 ? players[1] : players[0],
        );

        // Find myself to get accurate info from backend
        final me = players.firstWhere(
          (p) => p['username'] == widget.myUsername,
          orElse: () => players[0],
        );

        print("🎯 Me: ${me['username']} (Rating: ${me['rating']})");
        print(
          "🎯 Opponent: ${opponent['username']} (Rating: ${opponent['rating']})",
        );

        if (mounted) {
          setState(() {
            _isMatched = true;
            _currentMatchId = matchId;
            _opponentUsername = opponent['username'];
            _opponentRating = opponent['rating'] ?? 1200;
            _opponentAvatar = opponent['avatar_url'];
          });

          _slideController.forward();

          // Wait for slide animation then show preparing screen
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) {
              _startPreparingPhase();
            }
          });
        }
        break;

      case 'error':
        print("❌ Error from server: $payload");
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Lỗi: $payload')));
        }
        break;

      case 'ping':
        // Just keep-alive, ignore
        break;

      default:
        print("⚠️ Unknown message type: $type");
    }
  }

  @override
  void didUpdateWidget(CaroMatchingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  void _cancelMatching() {
    print("🚫 Cancelling matchmaking...");
    _cleanupWebSocket();
    // Pop screen
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _startPreparingPhase() {
    setState(() {
      _isPreparing = true;
      _preparingCountdown = 5; // 5 giây
    });

    // Countdown timer
    _preparingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _preparingCountdown--;
      });

      // Navigate khi countdown về 0
      if (_preparingCountdown <= 0) {
        timer.cancel();
        if (mounted && widget.onMatchFound != null) {
          widget.onMatchFound!(
            _currentMatchId!,
            widget.myRating ?? 1200,
            _opponentRating ?? 1200,
          );
        }
      }
    });
  }

  void _cleanupWebSocket() {
    _isCancelled = true;
    _preparingTimer?.cancel();

    // Send cancel message to backend BEFORE closing
    try {
      if (_wsChannel != null) {
        final cancelMessage = jsonEncode({
          'type': 'cancel',
          'payload': {'message': 'User cancelled matchmaking'},
        });
        _wsChannel!.sink.add(cancelMessage);
        print("📤 Sent cancel message to backend");
      }
    } catch (e) {
      print("⚠️ Error sending cancel message: $e");
    }

    // Wait a bit for message to be sent
    Future.delayed(const Duration(milliseconds: 100), () {
      // Cancel subscription
      try {
        _wsSubscription?.cancel();
        print("✅ WebSocket subscription cancelled");
      } catch (e) {
        print("⚠️ Error cancelling subscription: $e");
      }

      // Then close WebSocket
      try {
        _wsChannel?.sink.close();
        print("✅ WebSocket closed");
      } catch (e) {
        print("⚠️ Error closing WebSocket: $e");
      }
    });
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    _preparingTimer?.cancel();
    _cleanupWebSocket();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 600;
    final isVerySmallScreen = screenWidth < 360;

    // Responsive sizes
    final vsIconSize = isSmallScreen ? 60.0 : 80.0;
    final vsFontSize = isSmallScreen ? 24.0 : 32.0;
    final headerFontSize = isVerySmallScreen
        ? 18.0
        : (isSmallScreen ? 20.0 : 24.0);
    final statusFontSize = isSmallScreen ? 16.0 : 20.0;
    final matchedIconSize = isSmallScreen ? 48.0 : 64.0;
    final matchedFontSize = isSmallScreen ? 18.0 : 24.0;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade700,
              Colors.blue.shade500,
              Colors.blue.shade400,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        // Header
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isVerySmallScreen ? 8.0 : 16.0,
                            vertical: isSmallScreen ? 12.0 : 20.0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                onPressed: _cancelMatching,
                                icon: Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: isSmallScreen ? 24 : 28,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              Flexible(
                                child: Text(
                                  'SẴN SÀNG CHƠI',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: headerFontSize,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: isVerySmallScreen ? 1 : 2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                onPressed: () {},
                                icon: Icon(
                                  Icons.menu,
                                  color: Colors.white,
                                  size: isSmallScreen ? 24 : 28,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: isSmallScreen ? 20 : 40),

                        // Players VS Section
                        Flexible(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isVerySmallScreen ? 12.0 : 20.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Player 1 (Me)
                                Expanded(
                                  child: SlideTransition(
                                    position: _isMatched
                                        ? _slideLeftAnimation
                                        : const AlwaysStoppedAnimation(
                                            Offset.zero,
                                          ),
                                    child: _buildPlayerCard(
                                      context: context,
                                      username: widget.myUsername ?? 'Player 1',
                                      avatar: widget.myAvatar,
                                      rating: widget.myRating ?? 1200,
                                      isMe: true,
                                      isSearching:
                                          false, // Always show rating for me
                                    ),
                                  ),
                                ),

                                // VS Icon
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isVerySmallScreen ? 8.0 : 16.0,
                                  ),
                                  child: AnimatedBuilder(
                                    animation: _rotateAnimation,
                                    builder: (context, child) {
                                      return Transform.rotate(
                                        angle: _rotateAnimation.value,
                                        child: Container(
                                          width: vsIconSize,
                                          height: vsIconSize,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: RadialGradient(
                                              colors: [
                                                Colors.white.withOpacity(0.3),
                                                Colors.white.withOpacity(0.1),
                                              ],
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              'VS',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: vsFontSize,
                                                fontWeight: FontWeight.w900,
                                                shadows: const [
                                                  Shadow(
                                                    color: Colors.black26,
                                                    blurRadius: 8,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),

                                // Player 2 (Opponent)
                                Expanded(
                                  child: SlideTransition(
                                    position: _isMatched
                                        ? _slideRightAnimation
                                        : const AlwaysStoppedAnimation(
                                            Offset.zero,
                                          ),
                                    child: _buildPlayerCard(
                                      context: context,
                                      username:
                                          _opponentUsername ?? 'Đang tìm...',
                                      avatar: _opponentAvatar,
                                      rating: _opponentRating ?? 1200,
                                      isMe: false,
                                      isSearching: !_isMatched,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: isSmallScreen ? 20 : 40),

                        // Status Text
                        if (_isPreparing)
                          // Preparing battle screen
                          _buildPreparingSection(
                            isSmallScreen,
                            matchedIconSize,
                            matchedFontSize,
                          )
                        else if (!_isMatched)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                final opacity =
                                    (0.7 + (_pulseAnimation.value - 0.95) * 0.3)
                                        .clamp(0.0, 1.0);
                                return Opacity(
                                  opacity: opacity,
                                  child: Column(
                                    children: [
                                      Text(
                                        'Đang tìm đối thủ...',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: statusFontSize,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      SizedBox(height: isSmallScreen ? 12 : 16),
                                      SizedBox(
                                        width: isSmallScreen ? 150 : 200,
                                        child: LinearProgressIndicator(
                                          backgroundColor: Colors.white
                                              .withOpacity(0.3),
                                          valueColor:
                                              const AlwaysStoppedAnimation<
                                                Color
                                              >(Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 600),
                              tween: Tween(begin: 0.0, end: 1.0),
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                        size: matchedIconSize,
                                      ),
                                      SizedBox(height: isSmallScreen ? 8 : 12),
                                      Text(
                                        'Đã tìm thấy đối thủ!',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: matchedFontSize,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),

                        SizedBox(height: isSmallScreen ? 30 : 60),

                        // Cancel Button
                        if (!_isMatched)
                          Padding(
                            padding: EdgeInsets.only(
                              left: 20,
                              right: 20,
                              bottom: isSmallScreen ? 16 : 20,
                            ),
                            child: TextButton(
                              onPressed: _cancelMatching,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isVerySmallScreen ? 24 : 40,
                                  vertical: isSmallScreen ? 12 : 16,
                                ),
                                backgroundColor: Colors.white.withOpacity(0.2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  side: const BorderSide(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Text(
                                'HUỶ TÌM KIẾM',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isSmallScreen ? 14 : 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: isVerySmallScreen ? 0.5 : 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerCard({
    required BuildContext context,
    required String username,
    String? avatar,
    required int rating,
    required bool isMe,
    bool isSearching = false,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = MediaQuery.of(context).size.height < 600;
    final isVerySmallScreen = screenWidth < 360;

    // Responsive avatar size
    final avatarSize = isVerySmallScreen
        ? 80.0
        : (isSmallScreen ? 100.0 : 120.0);
    final usernameFontSize = isVerySmallScreen
        ? 14.0
        : (isSmallScreen ? 16.0 : 18.0);
    final ratingFontSize = isVerySmallScreen
        ? 13.0
        : (isSmallScreen ? 14.0 : 16.0);
    final iconSize = isVerySmallScreen ? 40.0 : (isSmallScreen ? 50.0 : 60.0);

    return AnimatedBuilder(
      animation: isSearching
          ? _pulseAnimation
          : const AlwaysStoppedAnimation(1.0),
      builder: (context, child) {
        return Transform.scale(
          scale: isSearching ? _pulseAnimation.value : 1.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: isVerySmallScreen ? 3 : 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: isSmallScreen ? 12 : 20,
                      spreadRadius: isSmallScreen ? 3 : 5,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: isSearching
                      ? Container(
                          color: Colors.white.withOpacity(0.3),
                          child: Icon(
                            Icons.question_mark,
                            size: iconSize,
                            color: Colors.white,
                          ),
                        )
                      : (avatar != null
                            ? Image.network(
                                avatar,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey.shade300,
                                    child: Icon(
                                      Icons.person,
                                      size: iconSize,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: Colors.grey.shade300,
                                child: Icon(
                                  Icons.person,
                                  size: iconSize,
                                  color: Colors.grey,
                                ),
                              )),
                ),
              ),

              SizedBox(height: isSmallScreen ? 12 : 16),

              // Username
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  username.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: usernameFontSize,
                    fontWeight: FontWeight.bold,
                    letterSpacing: isVerySmallScreen ? 0.5 : 1,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              SizedBox(height: isSmallScreen ? 6 : 8),

              // Rating - Always show, but with different content if searching
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isVerySmallScreen ? 10 : 16,
                  vertical: isVerySmallScreen ? 4 : 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isSearching
                        ? [Colors.grey.shade400, Colors.grey.shade300]
                        : [Colors.amber.shade600, Colors.amber.shade400],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: isSearching
                          ? Colors.grey.withOpacity(0.3)
                          : Colors.amber.withOpacity(0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.emoji_events,
                      color: Colors.white,
                      size: isVerySmallScreen ? 14 : 18,
                    ),
                    SizedBox(width: isVerySmallScreen ? 4 : 6),
                    Text(
                      isSearching ? '???' : '$rating',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: ratingFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPreparingSection(
    bool isSmallScreen,
    double iconSize,
    double fontSize,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmallScreen = screenWidth < 360;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Animated sword crossing icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.8 + (0.2 * value),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow effect
                    Container(
                      width: iconSize * 1.5,
                      height: iconSize * 1.5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.amber.withOpacity(0.3 * value),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    // Main icon
                    Icon(
                      Icons.sports_esports_rounded,
                      size: iconSize,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.amber.withOpacity(0.8),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          SizedBox(height: isSmallScreen ? 16 : 24),

          // "Preparing Battle" text
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [Colors.white, Colors.amber.shade200, Colors.white],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds),
            child: Text(
              'CHUẨN BỊ TRẬN ĐẤU',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          SizedBox(height: isSmallScreen ? 12 : 16),

          // Countdown with pulse animation
          TweenAnimationBuilder<double>(
            key: ValueKey(_preparingCountdown), // Reset animation on change
            tween: Tween(begin: 1.2, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  width: isSmallScreen ? 80 : 100,
                  height: isSmallScreen ? 80 : 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Colors.amber.shade400, Colors.orange.shade600],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$_preparingCountdown',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 40 : 50,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            offset: const Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          SizedBox(height: isSmallScreen ? 16 : 24),

          // Loading text (simple, no animation)
          Text(
            'Đang vào phòng...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: isSmallScreen ? 12 : 16),

          // Progress bar
          Container(
            width: isSmallScreen ? 200 : 250,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(3),
            ),
            child: TweenAnimationBuilder<double>(
              key: ValueKey(_preparingCountdown),
              tween: Tween(
                begin: 1.0 - (_preparingCountdown / 5),
                end: 1.0 - ((_preparingCountdown - 1) / 5),
              ),
              duration: const Duration(seconds: 1),
              curve: Curves.linear,
              builder: (context, value, child) {
                return FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber.shade300, Colors.orange.shade500],
                      ),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.6),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          SizedBox(height: isSmallScreen ? 20 : 32),

          // Tips or messages
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12 : 24,
              vertical: isSmallScreen ? 10 : 16,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: Colors.amber.shade300,
                  size: isSmallScreen ? 18 : 24,
                ),
                SizedBox(width: isSmallScreen ? 6 : 12),
                Flexible(
                  child: Text(
                    isVerySmallScreen
                        ? 'Chiếm trung tâm!'
                        : 'Mẹo: Chiếm trung tâm bàn cờ!',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: isSmallScreen ? 12 : 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
