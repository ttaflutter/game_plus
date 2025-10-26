import 'package:flutter/material.dart';
import 'package:game_plus/ui/widgets/custom_bottom_nav.dart';
import 'package:game_plus/ui/widgets/custom_sliver_app_bar.dart';
import 'package:intl/intl.dart';
import '../../../models/match_history_model.dart';
import '../../../services/match_history_service.dart';
import 'match_detail_screen.dart';

class MatchHistoryScreen extends StatefulWidget {
  final int?
  userId; // null = xem lịch sử của mình, có giá trị = xem lịch sử user khác

  const MatchHistoryScreen({super.key, this.userId});

  @override
  State<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends State<MatchHistoryScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  late TabController _tabController;
  late AnimationController _headerAnimationController;
  late Animation<double> _headerAnimation;
  List<MatchHistoryItem> _matches = [];

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20;

  // Filter cho từng tab
  String? _currentResultFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);

    // Initialize header animation
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _headerAnimation = CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOut,
    );
    _headerAnimationController.forward();

    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _headerAnimationController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      // Tab đã thay đổi, load data mới
      setState(() {
        switch (_tabController.index) {
          case 0:
            _currentResultFilter = null; // All
            break;
          case 1:
            _currentResultFilter = 'win';
            break;
          case 2:
            _currentResultFilter = 'loss';
            break;
          case 3:
            _currentResultFilter = 'draw';
            break;
        }
        _matches.clear();
        _offset = 0;
        _hasMore = true;
      });
      _loadMatches();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadInitialData() async {
    await _loadMatches();
  }

  Future<void> _loadMatches() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final matches = widget.userId == null
          ? await MatchHistoryService.getMyMatches(
              offset: _offset,
              limit: _limit,
              result: _currentResultFilter,
            )
          : await MatchHistoryService.getUserMatches(
              widget.userId!,
              offset: _offset,
              limit: _limit,
              result: _currentResultFilter,
            );

      if (mounted) {
        setState(() {
          _matches = matches;
          _hasMore = matches.length >= _limit;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi tải lịch sử: $e')));
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
      _offset += _limit;
    });

    try {
      final moreMatches = widget.userId == null
          ? await MatchHistoryService.getMyMatches(
              offset: _offset,
              limit: _limit,
              result: _currentResultFilter,
            )
          : await MatchHistoryService.getUserMatches(
              widget.userId!,
              offset: _offset,
              limit: _limit,
              result: _currentResultFilter,
            );

      if (mounted) {
        setState(() {
          _matches.addAll(moreMatches);
          _hasMore = moreMatches.length >= _limit;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _offset -= _limit; // Rollback offset
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi tải thêm: $e')));
      }
    }
  }

  Future<void> _onRefresh() async {
    setState(() {
      _matches.clear();
      _offset = 0;
      _hasMore = true;
    });
    await _loadInitialData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // AppBar với gradient xanh
            CustomSliverAppBar(
              title: 'Lịch Sử Đấu',
              icon: Icons.history_rounded,
              backgroundIcon: Icons.history_rounded,
              animation: _headerAnimation,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: Colors.blue.shade600,
                    unselectedLabelColor: Colors.grey.shade500,
                    indicatorColor: Colors.blue.shade600,
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    tabs: const [
                      Tab(text: 'Tất Cả'),
                      Tab(text: 'Thắng'),
                      Tab(text: 'Thua'),
                      Tab(text: 'Hòa'),
                    ],
                  ),
                ),
              ),
            ),

            // Pull to refresh
            SliverToBoxAdapter(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                child: const SizedBox.shrink(),
              ),
            ),

            // Match list
            if (_isLoading && _matches.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
              )
            else if (_matches.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 80,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Chưa có trận đấu nào',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bắt đầu chơi để xem lịch sử',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index < _matches.length) {
                      return TweenAnimationBuilder<double>(
                        duration: Duration(milliseconds: 300 + index * 30),
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: _buildMatchCard(_matches[index]),
                      );
                    } else if (_isLoadingMore) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue,
                            ),
                          ),
                        ),
                      );
                    }
                    return null;
                  }, childCount: _matches.length + (_isLoadingMore ? 1 : 0)),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNav(currentIndex: 3),
    );
  }

  Widget _buildMatchCard(MatchHistoryItem match) {
    final isWin = match.result == 'win';
    final isLose = match.result == 'loss';

    Color resultColor;
    IconData resultIcon;
    String resultText;

    if (isWin) {
      resultColor = const Color(0xFF4CAF50); // Green
      resultIcon = Icons.emoji_events_rounded;
      resultText = 'THẮNG';
    } else if (isLose) {
      resultColor = const Color(0xFFF44336); // Red
      resultIcon = Icons.close_rounded;
      resultText = 'THUA';
    } else {
      resultColor = const Color(0xFFFF9800); // Orange
      resultIcon = Icons.handshake_rounded;
      resultText = 'HÒA';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 400;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: resultColor.withOpacity(0.3), width: 2),
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      MatchDetailScreen(matchId: match.matchId),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: EdgeInsets.all(isCompact ? 14 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: result badge + date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Result badge
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 10 : 12,
                          vertical: isCompact ? 5 : 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [resultColor, resultColor.withOpacity(0.8)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: resultColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              resultIcon,
                              size: isCompact ? 14 : 16,
                              color: Colors.white,
                            ),
                            SizedBox(width: isCompact ? 3 : 4),
                            Text(
                              resultText,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: isCompact ? 11 : 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Date
                      Flexible(
                        child: Text(
                          _formatDate(match.createdAt),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: isCompact ? 11 : 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isCompact ? 10 : 12),

                  // Opponent info
                  Row(
                    children: [
                      // Opponent avatar
                      Container(
                        width: isCompact ? 44 : 48,
                        height: isCompact ? 44 : 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.blue.shade600.withOpacity(0.3),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: isCompact ? 20 : 22,
                          backgroundColor: Colors.blue.shade50,
                          backgroundImage: match.opponentAvatarUrl != null
                              ? NetworkImage(match.opponentAvatarUrl!)
                              : null,
                          child: match.opponentAvatarUrl == null
                              ? Text(
                                  match.opponentUsername[0].toUpperCase(),
                                  style: TextStyle(
                                    fontSize: isCompact ? 18 : 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade600,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      SizedBox(width: isCompact ? 10 : 12),
                      // Opponent info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              match.opponentUsername,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isCompact ? 15 : 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: isCompact ? 3 : 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    match.opponentSymbol,
                                    style: TextStyle(
                                      color: Colors.blue.shade600,
                                      fontSize: isCompact ? 12 : 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Arrow icon
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey.shade400,
                        size: isCompact ? 24 : 28,
                      ),
                    ],
                  ),

                  SizedBox(height: isCompact ? 10 : 12),

                  // Match info: duration, moves
                  Container(
                    padding: EdgeInsets.all(isCompact ? 10 : 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200, width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Expanded(
                          child: _buildMatchInfoItem(
                            Icons.access_time_rounded,
                            _formatDuration(match.durationSeconds ?? 0),
                            'Thời gian',
                            isCompact,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: Colors.grey.shade300,
                        ),
                        Expanded(
                          child: _buildMatchInfoItem(
                            Icons.sports_esports_rounded,
                            '${match.totalMoves}',
                            'Số nước đi',
                            isCompact,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMatchInfoItem(
    IconData icon,
    String value,
    String label,
    bool isCompact,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: isCompact ? 14 : 16, color: Colors.blue.shade600),
            SizedBox(width: isCompact ? 3 : 4),
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isCompact ? 13 : 14,
                  color: Colors.grey.shade800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        SizedBox(height: isCompact ? 3 : 4),
        Text(
          label,
          style: TextStyle(
            fontSize: isCompact ? 10 : 11,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Vừa xong';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ngày trước';
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
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
