import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/room_model.dart';
import '../../../services/room_service.dart';
import '../../../services/auth_service.dart';
import '../../../game/caro/caro_controller.dart';
import 'caro_playing_screen.dart';

class RoomWaitingScreen extends StatefulWidget {
  final RoomDetail roomDetail;

  const RoomWaitingScreen({super.key, required this.roomDetail});

  @override
  State<RoomWaitingScreen> createState() => _RoomWaitingScreenState();
}

class _RoomWaitingScreenState extends State<RoomWaitingScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late RoomDetail _room;
  Timer? _pollTimer;
  bool _isHost = false;
  int? _currentUserId;
  bool _isProcessing = false;

  // Countdown khi start game
  bool _isPreparing = false;
  int _preparingCountdown = 5;
  Timer? _preparingTimer;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _room = widget.roomDetail;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();

    _initializeRoom();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Tắt polling khi app ở background, bật lại khi về foreground
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _stopPolling();
    } else if (state == AppLifecycleState.resumed) {
      _startPolling();
      _loadRoomDetail(); // Refresh ngay khi quay lại
    }
  }

  Future<void> _initializeRoom() async {
    // Get current user ID
    try {
      final user = await AuthService().getCurrentUser();
      _currentUserId = user.id;
      _isHost = (_room.hostId == _currentUserId);

      // Start polling
      _startPolling();
    } catch (e) {
      print('Error initializing room: $e');
    }
  }

  void _startPolling() {
    _stopPolling(); // Clear timer cũ nếu có

    // Poll every 2 seconds để real-time
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) _loadRoomDetail();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    _preparingTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadRoomDetail() async {
    if (_isProcessing) return;

    try {
      final roomDetail = await RoomService.getRoomDetail(_room.id);

      if (mounted) {
        setState(() {
          _room = roomDetail;
        });

        // Check if current user was kicked (not in players list)
        final isStillInRoom = _room.players.any(
          (p) => p.userId == _currentUserId,
        );
        if (!isStillInRoom) {
          _stopPolling();
          _handleKicked();
          return;
        }

        // If game started -> show countdown (guest also sees it!)
        if (_room.status == 'playing' &&
            _room.matchId != null &&
            !_isPreparing) {
          _stopPolling(); // Dừng polling trước khi chuyển màn hình
          _startCountdownForGuest(_room.matchId!);
        }
      }
    } catch (e) {
      print('Error polling room: $e');

      // If room not found or access denied -> user was kicked or room deleted
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('not found') ||
          errorMsg.contains('404') ||
          errorMsg.contains('not in this room') ||
          errorMsg.contains('403')) {
        if (mounted) {
          _stopPolling();
          _handleKicked();
        }
      }
    }
  }

  void _handleKicked() {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Show notification
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 12),
            Text('Bạn đã bị kick khỏi phòng hoặc phòng đã bị xóa'),
          ],
        ),
        backgroundColor: Colors.orange.shade600,
        duration: const Duration(seconds: 3),
      ),
    );

    // Navigate back to lobby
    navigator.pop();
  }

  void _navigateToGame(int matchId) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => CaroController(
            matchId: matchId,
            initialMyRating: _getCurrentPlayerRating(),
            initialOpponentRating: _getOpponentRating(),
          ),
          child: const CaroScreen(),
        ),
      ),
    );
  }

  int _getCurrentPlayerRating() {
    final player = _room.players.firstWhere(
      (p) => p.userId == _currentUserId,
      orElse: () => _room.players.first,
    );
    return player.rating;
  }

  int _getOpponentRating() {
    final opponent = _room.players.firstWhere(
      (p) => p.userId != _currentUserId,
      orElse: () => _room.players.last,
    );
    return opponent.rating;
  }

  Future<void> _toggleReady() async {
    if (_isProcessing || _isHost) return;

    final currentPlayer = _room.players.firstWhere(
      (p) => p.userId == _currentUserId,
    );

    setState(() => _isProcessing = true);

    try {
      await RoomService.toggleReady(
        roomId: _room.id,
        isReady: !currentPlayer.isReady,
      );

      await _loadRoomDetail();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // Guest cũng thấy countdown khi phát hiện game started
  void _startCountdownForGuest(int matchId) {
    if (_isPreparing) return; // Đã đang countdown rồi

    setState(() {
      _isPreparing = true;
      _preparingCountdown = 5;
    });

    // Start countdown timer
    _preparingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _preparingCountdown--;
      });

      if (_preparingCountdown <= 0) {
        timer.cancel();
        if (mounted) {
          _navigateToGame(matchId);
        }
      }
    });
  }

  Future<void> _startGame() async {
    if (_isProcessing || !_isHost) return;

    setState(() {
      _isProcessing = true;
      _isPreparing = true;
      _preparingCountdown = 5;
    });
    _stopPolling(); // Dừng polling khi start game

    try {
      final response = await RoomService.startGame(_room.id);
      final matchId = response['match_id'];

      // Start countdown timer
      _preparingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        setState(() {
          _preparingCountdown--;
        });

        if (_preparingCountdown <= 0) {
          timer.cancel();
          if (mounted) {
            _navigateToGame(matchId);
          }
        }
      });
    } catch (e) {
      // Bật lại polling nếu start thất bại
      _startPolling();

      if (mounted) {
        setState(() {
          _isPreparing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(e.toString())),
              ],
            ),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _kickPlayer(int userId) async {
    if (_isProcessing || !_isHost) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.orange),
            SizedBox(width: 12),
            Text('Kick người chơi'),
          ],
        ),
        content: const Text('Bạn có chắc muốn kick người chơi này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Kick'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);

    try {
      await RoomService.kickPlayer(roomId: _room.id, userId: userId);
      await _loadRoomDetail();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Đã kick người chơi'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _leaveRoom() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.exit_to_app_rounded, color: Colors.orange),
            SizedBox(width: 12),
            Text('Rời phòng'),
          ],
        ),
        content: Text(
          _isHost
              ? 'Bạn là host, rời phòng sẽ xóa phòng này. Bạn có chắc?'
              : 'Bạn có chắc muốn rời phòng?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ở lại'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Rời phòng'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    _stopPolling(); // Dừng polling khi rời phòng

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await RoomService.leaveRoom(_room.id);
      navigator.pop(); // Return to lobby
    } catch (e) {
      // Bật lại polling nếu rời phòng thất bại
      _startPolling();

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  void _copyRoomCode() {
    Clipboard.setData(ClipboardData(text: _room.roomCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Đã copy mã phòng'),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allReady = _room.players.every((p) => p.isReady);
    final canStart = _isHost && allReady && _room.players.length >= 2;

    return WillPopScope(
      onWillPop: () async {
        _leaveRoom();
        return false;
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.grey.shade50,
            appBar: AppBar(
              title: Text(_room.roomName),
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _leaveRoom,
              ),
            ),
            body: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // Room Info Card
                  _buildRoomInfoCard(),

                  // Players List
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount:
                          _room.players.length +
                          (_room.players.length < _room.maxPlayers ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < _room.players.length) {
                          return _buildPlayerCard(_room.players[index]);
                        } else {
                          return _buildEmptySlotCard();
                        }
                      },
                    ),
                  ),

                  // Bottom Actions
                  _buildBottomActions(canStart),
                ],
              ),
            ),
          ),

          // Countdown Overlay
          if (_isPreparing) _buildPreparingOverlay(),
        ],
      ),
    );
  }

  Widget _buildRoomInfoCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade800],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade600.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Room Code
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.vpn_key_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              const Text(
                'MÃ PHÒNG:',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _room.roomCode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _copyRoomCode,
                icon: const Icon(Icons.copy_rounded, color: Colors.white),
                tooltip: 'Copy mã',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatChip(
                Icons.people_rounded,
                '${_room.currentPlayers}/${_room.maxPlayers}',
                'Người chơi',
              ),
              _buildStatChip(
                Icons.grid_4x4_rounded,
                '${_room.boardRows}×${_room.boardCols}',
                'Bàn cờ',
              ),
              _buildStatChip(
                Icons.flag_rounded,
                '${_room.winLen} quân',
                'Thắng',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildPlayerCard(RoomPlayer player) {
    final isCurrentUser = player.userId == _currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: player.isHost ? Colors.amber.shade300 : Colors.grey.shade200,
          width: player.isHost ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: player.isHost
                          ? [Colors.amber.shade400, Colors.amber.shade600]
                          : [Colors.blue.shade400, Colors.blue.shade600],
                    ),
                  ),
                  child:
                      player.avatarUrl != null && player.avatarUrl!.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            player.avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _buildDefaultAvatar(player),
                          ),
                        )
                      : _buildDefaultAvatar(player),
                ),
                if (player.isHost)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade600,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          player.username,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Bạn',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Colors.amber.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${player.rating}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Status
            if (player.isReady)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green.shade600,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Sẵn sàng',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            // Kick button (for host)
            if (_isHost && !player.isHost) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _kickPlayer(player.userId),
                icon: Icon(Icons.close_rounded, color: Colors.red.shade600),
                tooltip: 'Kick',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(RoomPlayer player) {
    return Center(
      child: Text(
        player.username[0].toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptySlotCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade300,
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade200,
            ),
            child: Icon(
              Icons.person_add_rounded,
              color: Colors.grey.shade400,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Đang chờ người chơi...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(bool canStart) {
    // Find current player safely
    final currentPlayer = _currentUserId != null
        ? _room.players.firstWhere(
            (p) => p.userId == _currentUserId,
            orElse: () => _room.players.first,
          )
        : _room.players.first;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (!_isHost)
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _toggleReady,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: currentPlayer.isReady
                          ? Colors.orange.shade600
                          : Colors.green.shade600,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          currentPlayer.isReady
                              ? Icons.close_rounded
                              : Icons.check_circle_rounded,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          currentPlayer.isReady ? 'HỦY SẴN SÀNG' : 'SẴN SÀNG',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_isHost)
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: canStart && !_isProcessing ? _startGame : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow_rounded, size: 28),
                              SizedBox(width: 8),
                              Text(
                                'BẮT ĐẦU',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreparingOverlay() {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 600;

    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Game controller icon with glow
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
                        width: (isSmallScreen ? 64 : 80) * 1.5,
                        height: (isSmallScreen ? 64 : 80) * 1.5,
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
                        size: isSmallScreen ? 64 : 80,
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

            SizedBox(height: isSmallScreen ? 24 : 32),

            // Title
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [Colors.white, Colors.amber.shade200, Colors.white],
                stops: const [0.0, 0.5, 1.0],
              ).createShader(bounds),
              child: Text(
                'CHUẨN BỊ TRẬN ĐẤU',
                style: TextStyle(
                  fontSize: isSmallScreen ? 24 : 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            SizedBox(height: isSmallScreen ? 16 : 24),

            // Countdown circle
            TweenAnimationBuilder<double>(
              key: ValueKey(_preparingCountdown),
              tween: Tween(begin: 1.2, end: 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: isSmallScreen ? 100 : 120,
                    height: isSmallScreen ? 100 : 120,
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
                          fontSize: isSmallScreen ? 50 : 60,
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

            SizedBox(height: isSmallScreen ? 24 : 32),

            // Loading text
            Text(
              'Đang vào phòng...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: isSmallScreen ? 16 : 20),

            // Progress bar
            Container(
              width: isSmallScreen ? 220 : 280,
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
                          colors: [
                            Colors.amber.shade300,
                            Colors.orange.shade500,
                          ],
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

            SizedBox(height: isSmallScreen ? 24 : 32),

            // Tips
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 16 : 24,
                vertical: isSmallScreen ? 12 : 16,
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
                    size: isSmallScreen ? 20 : 24,
                  ),
                  SizedBox(width: isSmallScreen ? 8 : 12),
                  Flexible(
                    child: Text(
                      'Mẹo: Chiếm trung tâm bàn cờ để có lợi thế!',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: isSmallScreen ? 13 : 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
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
