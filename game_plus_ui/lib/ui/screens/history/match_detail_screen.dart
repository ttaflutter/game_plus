import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/match_history_model.dart';
import '../../../services/match_history_service.dart';

class MatchDetailScreen extends StatefulWidget {
  final int matchId;

  const MatchDetailScreen({super.key, required this.matchId});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen>
    with TickerProviderStateMixin {
  MatchDetail? _matchDetail;
  bool _isLoading = true;
  String? _errorMessage;

  // Replay state
  int _currentMoveIndex = 0;
  bool _isPlaying = false;
  Timer? _playTimer;
  int _playbackSpeed = 1000; // milliseconds per move

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    _fadeController.forward();
    _scaleController.forward();

    _loadMatchDetail();
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _loadMatchDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final detail = await MatchHistoryService.getMatchDetail(widget.matchId);
      if (mounted) {
        setState(() {
          _matchDetail = detail;
          _currentMoveIndex = detail.moves.length; // Show final state
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _togglePlayback() {
    if (_isPlaying) {
      _pausePlayback();
    } else {
      _startPlayback();
    }
  }

  void _startPlayback() {
    if (_matchDetail == null || _matchDetail!.moves.isEmpty) return;

    // If at the end, restart from beginning
    if (_currentMoveIndex >= _matchDetail!.moves.length) {
      setState(() {
        _currentMoveIndex = 0;
      });
    }

    setState(() {
      _isPlaying = true;
    });

    _playTimer = Timer.periodic(Duration(milliseconds: _playbackSpeed), (
      timer,
    ) {
      if (_currentMoveIndex < _matchDetail!.moves.length) {
        setState(() {
          _currentMoveIndex++;
        });
      } else {
        _pausePlayback();
      }
    });
  }

  void _pausePlayback() {
    _playTimer?.cancel();
    setState(() {
      _isPlaying = false;
    });
  }

  void _stepBackward() {
    if (_currentMoveIndex > 0) {
      setState(() {
        _currentMoveIndex--;
      });
    }
  }

  void _stepForward() {
    if (_matchDetail != null &&
        _currentMoveIndex < _matchDetail!.moves.length) {
      setState(() {
        _currentMoveIndex++;
      });
    }
  }

  void _jumpToStart() {
    setState(() {
      _currentMoveIndex = 0;
    });
  }

  void _jumpToEnd() {
    if (_matchDetail != null) {
      setState(() {
        _currentMoveIndex = _matchDetail!.moves.length;
      });
    }
  }

  List<List<String?>> _buildCurrentBoard() {
    if (_matchDetail == null) return [];

    return MatchHistoryService.buildBoardFromMoves(
      rows: _matchDetail!.boardRows,
      cols: _matchDetail!.boardCols,
      moves: _matchDetail!.moves,
      upToMoveIndex: _currentMoveIndex,
    );
  }

  bool _isWinningCell(int row, int col) {
    if (_matchDetail?.winningLine == null) return false;
    if (_currentMoveIndex < _matchDetail!.moves.length) return false;

    return _matchDetail!.winningLine!.any(
      (cell) => cell.x == row && cell.y == col,
    );
  }

  bool _isLastMove(int row, int col) {
    if (_currentMoveIndex == 0 || _matchDetail == null) return false;

    final lastMove = _matchDetail!.moves[_currentMoveIndex - 1];
    return lastMove.x == row && lastMove.y == col;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A1929)
          : const Color(0xFFF8FAFC),
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState(isDark)
            : _errorMessage != null
            ? _buildErrorWidget(isDark)
            : _matchDetail == null
            ? _buildEmptyState(isDark)
            : _buildContent(isDark),
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF2196F3).withOpacity(0.2),
                  const Color(0xFF1976D2).withOpacity(0.2),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Đang tải dữ liệu...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Modern App Bar with Glassmorphism
        _buildAppBar(isDark),

        // Content
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildPlayersSection(isDark),
                const SizedBox(height: 16),
                _buildStatsCards(isDark),
                const SizedBox(height: 16),
                _buildBoardSection(isDark),
                const SizedBox(height: 16),
                _buildReplayControls(isDark),
                const SizedBox(height: 16),
                _buildMovesList(isDark),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1565C0), const Color(0xFF0D47A1)]
                : [const Color(0xFF2196F3), const Color(0xFF1976D2)],
          ),
        ),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Positioned(
              bottom: -20,
              left: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            // Title
            FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
              title: FadeTransition(
                opacity: _fadeAnimation,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.sports_esports_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Trận #${widget.matchId}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildErrorWidget(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.red.shade400.withOpacity(0.2),
                    Colors.red.shade600.withOpacity(0.2),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 60,
                color: isDark ? Colors.red.shade300 : Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Đã xảy ra lỗi',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey.shade600,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadMatchDetail,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: const Color(0xFF2196F3).withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2196F3).withOpacity(0.1),
                  const Color(0xFF1976D2).withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.info_outline_rounded,
              size: 60,
              color: isDark ? Colors.blue.shade300 : const Color(0xFF2196F3),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Không tìm thấy dữ liệu',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(bool isDark) {
    if (_matchDetail == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _buildStatCard(
                icon: Icons.calendar_today_rounded,
                label: 'Ngày chơi',
                value: DateFormat(
                  'dd/MM/yyyy',
                ).format(_matchDetail!.finishedAt ?? _matchDetail!.createdAt),
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1565C0), const Color(0xFF0D47A1)]
                      : [const Color(0xFF2196F3), const Color(0xFF1976D2)],
                ),
                isDark: isDark,
                isCompact: isCompact,
              ),
              _buildStatCard(
                icon: Icons.access_time_rounded,
                label: 'Thời lượng',
                value: _formatDuration(_matchDetail!.durationSeconds ?? 0),
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF00897B), const Color(0xFF00695C)]
                      : [const Color(0xFF26A69A), const Color(0xFF00897B)],
                ),
                isDark: isDark,
                isCompact: isCompact,
              ),
              _buildStatCard(
                icon: Icons.grid_on_rounded,
                label: 'Bàn cờ',
                value: '${_matchDetail!.boardRows}x${_matchDetail!.boardCols}',
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF6A1B9A), const Color(0xFF4A148C)]
                      : [const Color(0xFF9C27B0), const Color(0xFF7B1FA2)],
                ),
                isDark: isDark,
                isCompact: isCompact,
              ),
              _buildStatCard(
                icon: Icons.touch_app_rounded,
                label: 'Tổng nước đi',
                value: '${_matchDetail!.moves.length}',
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFFE65100), const Color(0xFFBF360C)]
                      : [const Color(0xFFFF6F00), const Color(0xFFE65100)],
                ),
                isDark: isDark,
                isCompact: isCompact,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Gradient gradient,
    required bool isDark,
    required bool isCompact,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, animValue, child) {
        return Transform.scale(scale: animValue, child: child);
      },
      child: Container(
        constraints: BoxConstraints(minWidth: isCompact ? 150 : 160),
        padding: EdgeInsets.all(isCompact ? 12 : 16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: isCompact ? 24 : 28),
            SizedBox(height: isCompact ? 6 : 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: isCompact ? 11 : 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: isCompact ? 4 : 6),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: isCompact ? 16 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayersSection(bool isDark) {
    final players = _matchDetail!.players;
    final player1 = players[0];
    final player2 = players.length > 1 ? players[1] : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;

        return ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: EdgeInsets.all(isCompact ? 20 : 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF1A237E).withOpacity(0.3),
                        const Color(0xFF0D47A1).withOpacity(0.3),
                      ]
                    : [Colors.white, const Color(0xFFF8FAFC)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : const Color(0xFF2196F3).withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2196F3).withOpacity(0.1),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // Match result header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2196F3).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.emoji_events_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _matchDetail!.isDraw ? 'HÒA' : 'KẾT QUẢ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isCompact ? 20 : 24),

                // Players comparison
                Row(
                  children: [
                    Expanded(
                      child: _buildPlayerCard(player1, isCompact, isDark),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 12 : 16,
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF2196F3,
                                  ).withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Text(
                              'VS',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF2196F3).withOpacity(0.2),
                                  const Color(0xFF1976D2).withOpacity(0.2),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF2196F3).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 12,
                                  color: Color(0xFF2196F3),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDuration(
                                    _matchDetail!.durationSeconds ?? 0,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2196F3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (player2 != null)
                      Expanded(
                        child: _buildPlayerCard(player2, isCompact, isDark),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayerCard(PlayerInfo player, bool isCompact, bool isDark) {
    final ratingChange = player.ratingChange;
    final isWinner = player.isWinner == true;
    final isDraw = player.isWinner == null;

    return Column(
      children: [
        // Avatar with animated result indicator
        Stack(
          alignment: Alignment.center,
          children: [
            // Glow effect for winner
            if (isWinner)
              Container(
                width: isCompact ? 90 : 100,
                height: isCompact ? 90 : 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF4CAF50).withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

            // Avatar container
            Container(
              width: isCompact ? 80 : 90,
              height: isCompact ? 80 : 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isWinner
                      ? [const Color(0xFF4CAF50), const Color(0xFF66BB6A)]
                      : isDraw
                      ? [const Color(0xFF42A5F5), const Color(0xFF1E88E5)]
                      : [const Color(0xFFEF5350), const Color(0xFFE53935)],
                ),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color:
                        (isWinner
                                ? const Color(0xFF4CAF50)
                                : isDraw
                                ? const Color(0xFF42A5F5)
                                : const Color(0xFFEF5350))
                            .withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: CircleAvatar(
                  backgroundColor: isDark
                      ? const Color(0xFF1E3A5F)
                      : const Color(0xFFE3F2FD),
                  backgroundImage:
                      player.avatarUrl != null && player.avatarUrl!.isNotEmpty
                      ? NetworkImage(player.avatarUrl!)
                      : null,
                  child: player.avatarUrl == null || player.avatarUrl!.isEmpty
                      ? Text(
                          player.username[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: isCompact ? 30 : 34,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2196F3),
                          ),
                        )
                      : null,
                ),
              ),
            ),

            // Winner crown/badge
            if (isWinner)
              Positioned(
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFC107)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withOpacity(0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: isCompact ? 12 : 14),

        // Username
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : const Color(0xFF2196F3).withOpacity(0.2),
            ),
          ),
          child: Text(
            player.username,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isCompact ? 14 : 16,
              color: isWinner
                  ? const Color(0xFF4CAF50)
                  : isDark
                  ? Colors.white
                  : Colors.grey.shade900,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Symbol badge
        SizedBox(height: isCompact ? 10 : 12),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 16 : 18,
            vertical: isCompact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: player.symbol == 'X'
                  ? [const Color(0xFF2196F3), const Color(0xFF1976D2)]
                  : [const Color(0xFFEF5350), const Color(0xFFE53935)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color:
                    (player.symbol == 'X'
                            ? const Color(0xFF2196F3)
                            : const Color(0xFFEF5350))
                        .withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            player.symbol,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isCompact ? 20 : 24,
              color: Colors.white,
            ),
          ),
        ),

        // Rating change
        if (ratingChange != null) ...[
          SizedBox(height: isCompact ? 10 : 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.shade300, Colors.amber.shade500],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star_rounded,
                  size: 14,
                  color: Colors.amber.shade900,
                ),
                const SizedBox(width: 4),
                Text(
                  '${player.ratingBefore}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.amber.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  ratingChange >= 0
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 12,
                  color: ratingChange >= 0
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFC62828),
                ),
                const SizedBox(width: 2),
                Text(
                  '${ratingChange.abs()}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: ratingChange >= 0
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFC62828),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Result badge
        SizedBox(height: isCompact ? 10 : 12),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 12 : 14,
            vertical: isCompact ? 6 : 7,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isWinner
                  ? [const Color(0xFF4CAF50), const Color(0xFF66BB6A)]
                  : isDraw
                  ? [const Color(0xFF42A5F5), const Color(0xFF1E88E5)]
                  : [const Color(0xFFEF5350), const Color(0xFFE53935)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color:
                    (isWinner
                            ? const Color(0xFF4CAF50)
                            : isDraw
                            ? const Color(0xFF42A5F5)
                            : const Color(0xFFEF5350))
                        .withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isWinner
                    ? Icons.check_circle_rounded
                    : isDraw
                    ? Icons.handshake_rounded
                    : Icons.close_rounded,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                isWinner
                    ? 'THẮNG'
                    : isDraw
                    ? 'HÒA'
                    : 'THUA',
                style: TextStyle(
                  fontSize: isCompact ? 11 : 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBoardSection(bool isDark) {
    final currentBoard = _buildCurrentBoard();
    if (currentBoard.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final maxBoardSize = screenWidth - 32;
        final cellSize = (maxBoardSize / _matchDetail!.boardCols).clamp(
          20.0,
          40.0,
        );

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF1A237E).withOpacity(0.3),
                      const Color(0xFF0D47A1).withOpacity(0.3),
                    ]
                  : [Colors.white, const Color(0xFFF8FAFC)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : const Color(0xFF2196F3).withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2196F3).withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Move counter
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2196F3).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.touch_app_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'NƯỚC ĐI: $_currentMoveIndex / ${_matchDetail!.moves.length}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Board
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF2196F3),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2196F3).withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: List.generate(
                        _matchDetail!.boardRows,
                        (row) => Row(
                          children: List.generate(
                            _matchDetail!.boardCols,
                            (col) => _buildCell(
                              row,
                              col,
                              currentBoard,
                              cellSize,
                              isDark,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCell(
    int row,
    int col,
    List<List<String?>> board,
    double size,
    bool isDark,
  ) {
    final symbol = board[row][col];
    final isWinner = _isWinningCell(row, col);
    final isLast = _isLastMove(row, col);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (row + col) * 20),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(opacity: value, child: child);
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: isWinner
              ? const LinearGradient(
                  colors: [Color(0xFFFFF9C4), Color(0xFFFFF59D)],
                )
              : null,
          color: isWinner
              ? null
              : isLast
              ? const Color(0xFFE3F2FD)
              : isDark
              ? const Color(0xFF1A237E).withOpacity(0.1)
              : Colors.white,
          border: Border.all(
            color: isWinner
                ? Colors.amber.shade600
                : isLast
                ? const Color(0xFF2196F3)
                : isDark
                ? Colors.white.withOpacity(0.1)
                : const Color(0xFFE0E0E0),
            width: isWinner
                ? 2.5
                : isLast
                ? 2
                : 0.5,
          ),
        ),
        child: Center(
          child: symbol != null
              ? TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(scale: value, child: child);
                  },
                  child: Text(
                    symbol,
                    style: TextStyle(
                      fontSize: size * 0.6,
                      fontWeight: FontWeight.bold,
                      color: symbol == 'X'
                          ? const Color(0xFF2196F3)
                          : const Color(0xFFEF5350),
                      shadows: [
                        Shadow(
                          color:
                              (symbol == 'X'
                                      ? const Color(0xFF2196F3)
                                      : const Color(0xFFEF5350))
                                  .withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildReplayControls(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1A237E).withOpacity(0.3),
                  const Color(0xFF0D47A1).withOpacity(0.3),
                ]
              : [Colors.white, const Color(0xFFF8FAFC)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : const Color(0xFF2196F3).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Slider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: const Color(0xFF2196F3),
                inactiveTrackColor: isDark
                    ? Colors.white.withOpacity(0.1)
                    : const Color(0xFFE0E0E0),
                thumbColor: const Color(0xFF2196F3),
                overlayColor: const Color(0x332196F3),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              ),
              child: Slider(
                value: _currentMoveIndex.toDouble(),
                min: 0,
                max: (_matchDetail?.moves.length ?? 0).toDouble(),
                divisions: _matchDetail?.moves.length ?? 1,
                onChanged: (value) {
                  setState(() {
                    _currentMoveIndex = value.toInt();
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Control buttons
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              // Jump to start
              _buildControlButton(
                icon: Icons.skip_previous_rounded,
                onPressed: _jumpToStart,
                isDark: isDark,
              ),

              // Step backward
              _buildControlButton(
                icon: Icons.chevron_left_rounded,
                onPressed: _stepBackward,
                isDark: isDark,
              ),

              // Play/Pause
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2196F3).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: _togglePlayback,
                  icon: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                  ),
                  iconSize: 36,
                ),
              ),

              // Step forward
              _buildControlButton(
                icon: Icons.chevron_right_rounded,
                onPressed: _stepForward,
                isDark: isDark,
              ),

              // Jump to end
              _buildControlButton(
                icon: Icons.skip_next_rounded,
                onPressed: _jumpToEnd,
                isDark: isDark,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Speed control
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              Icon(
                Icons.speed_rounded,
                size: 18,
                color: isDark ? Colors.white70 : const Color(0xFF2196F3),
              ),
              const SizedBox(width: 4),
              Text(
                'TỐC ĐỘ:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : const Color(0xFF2196F3),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              _buildSpeedButton('0.5x', 2000, isDark),
              _buildSpeedButton('1x', 1000, isDark),
              _buildSpeedButton('2x', 500, isDark),
              _buildSpeedButton('4x', 250, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        color: const Color(0xFF2196F3),
        iconSize: 28,
      ),
    );
  }

  Widget _buildSpeedButton(String label, int speed, bool isDark) {
    final isSelected = _playbackSpeed == speed;

    return ElevatedButton(
      onPressed: () {
        setState(() {
          _playbackSpeed = speed;
        });
        if (_isPlaying) {
          _pausePlayback();
          _startPlayback();
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? const Color(0xFF2196F3)
            : isDark
            ? Colors.white.withOpacity(0.05)
            : const Color(0xFFF5F5F5),
        foregroundColor: isSelected
            ? Colors.white
            : isDark
            ? Colors.white70
            : const Color(0xFF757575),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        elevation: isSelected ? 4 : 0,
        shadowColor: isSelected
            ? const Color(0xFF2196F3).withOpacity(0.4)
            : null,
        minimumSize: const Size(60, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMovesList(bool isDark) {
    if (_matchDetail == null || _matchDetail!.moves.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1A237E).withOpacity(0.3),
                  const Color(0xFF0D47A1).withOpacity(0.3),
                ]
              : [Colors.white, const Color(0xFFF8FAFC)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : const Color(0xFF2196F3).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.list_alt_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'DANH SÁCH NƯỚC ĐI',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2196F3),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Moves list
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _matchDetail!.moves.length,
            itemBuilder: (context, index) {
              final move = _matchDetail!.moves[index];
              final isCurrentMove = index == _currentMoveIndex - 1;

              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 300 + (index * 20)),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(20 * (1 - value), 0),
                    child: Opacity(opacity: value, child: child),
                  );
                },
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _currentMoveIndex = index + 1;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      gradient: isCurrentMove
                          ? const LinearGradient(
                              colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
                            )
                          : null,
                      color: isCurrentMove
                          ? null
                          : isDark
                          ? Colors.white.withOpacity(0.02)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrentMove
                            ? const Color(0xFF2196F3)
                            : isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.shade200,
                        width: isCurrentMove ? 2 : 1,
                      ),
                      boxShadow: isCurrentMove
                          ? [
                              BoxShadow(
                                color: const Color(0xFF2196F3).withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        // Move number
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: isCurrentMove
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF2196F3),
                                      Color(0xFF1976D2),
                                    ],
                                  )
                                : null,
                            color: isCurrentMove
                                ? null
                                : isDark
                                ? Colors.white.withOpacity(0.05)
                                : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${move.turnNo}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isCurrentMove
                                  ? Colors.white
                                  : isDark
                                  ? Colors.white60
                                  : const Color(0xFF757575),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Symbol
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: move.symbol == 'X'
                                  ? [
                                      const Color(0xFF2196F3),
                                      const Color(0xFF1976D2),
                                    ]
                                  : [
                                      const Color(0xFFEF5350),
                                      const Color(0xFFE53935),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (move.symbol == 'X'
                                            ? const Color(0xFF2196F3)
                                            : const Color(0xFFEF5350))
                                        .withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            move.symbol,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Username
                        Expanded(
                          child: Text(
                            move.username,
                            style: TextStyle(
                              fontWeight: isCurrentMove
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              fontSize: 14,
                              color: isCurrentMove
                                  ? const Color(0xFF2196F3)
                                  : isDark
                                  ? Colors.white70
                                  : Colors.grey.shade800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Position
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : const Color(0xFFE0E0E0),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '(${move.x}, ${move.y})',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white60
                                  : Colors.grey.shade700,
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Time
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 12,
                              color: isDark
                                  ? Colors.white38
                                  : Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('HH:mm:ss').format(move.madeAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      return '${minutes}p ${remainingSeconds}s';
    } else {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      return '${hours}h ${minutes}p';
    }
  }
}
