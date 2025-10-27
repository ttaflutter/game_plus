import 'package:flutter/material.dart';
import 'package:game_plus/ui/screens/history/match_history_screen.dart';
import 'package:intl/intl.dart';
import '../../../models/profile_model.dart';
import '../../../services/profile_service.dart';
import '../../widgets/custom_bottom_nav.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';
import 'settings_screen.dart';
import '../friends/friends_screen.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  MyProfile? _profile;
  bool _isLoading = true;
  String? _error;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _loadProfile();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profile = await ProfileService.getMyProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmLogout() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Đăng Xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF44336),
            ),
            child: const Text('Đăng Xuất'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await _logout();
    }
  }

  Future<void> _logout() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await ProfileService.logout();

      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Xóa Tài Khoản',
          style: TextStyle(color: Color(0xFFF44336)),
        ),
        content: const Text(
          'Bạn có chắc chắn muốn xóa tài khoản?\n\n'
          '⚠️ Hành động này không thể hoàn tác!\n'
          '⚠️ Tất cả dữ liệu của bạn sẽ bị xóa vĩnh viễn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF44336),
            ),
            child: const Text('Xóa Tài Khoản'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await _deleteAccount();
    }
  }

  Future<void> _deleteAccount() async {
    String? password;

    if (_profile!.isLocalAccount) {
      password = await showDialog<String>(
        context: context,
        builder: (context) {
          final controller = TextEditingController();
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Xác Nhận Mật Khẩu'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu',
                hintText: 'Nhập mật khẩu để xác nhận',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: const Text('Xác Nhận'),
              ),
            ],
          );
        },
      );

      if (password == null || password.isEmpty) return;
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await ProfileService.deleteAccount(password: password);

      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              )
            : _error != null
            ? _buildErrorWidget()
            : _buildProfileContent(),
      ),
      bottomNavigationBar: const CustomBottomNav(currentIndex: 4),
    );
  }

  Widget _buildProfileContent() {
    if (_profile == null) return const SizedBox();

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isTablet = screenWidth > 600;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildHeader(screenWidth, isTablet),
                SizedBox(height: isTablet ? 32 : 24),
                _buildStatsCard(screenWidth, isTablet),
                SizedBox(height: isTablet ? 24 : 16),
                _buildQuickActions(screenWidth, isTablet),
                SizedBox(height: isTablet ? 24 : 16),
                _buildAccountSection(screenWidth, isTablet),
                SizedBox(height: isTablet ? 24 : 16),
                _buildAppSection(screenWidth, isTablet),
                SizedBox(height: isTablet ? 24 : 16),
                _buildDangerZone(screenWidth, isTablet),
                SizedBox(height: isTablet ? 40 : 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(double screenWidth, bool isTablet) {
    final maxWidth = isTablet ? 800.0 : screenWidth;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 32 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade600, Colors.blue.shade800],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade600.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -50,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.02),
                  ],
                ),
              ),
            ),
          ),
          // Decorative icons
          Positioned(
            top: 20,
            right: 30,
            child: Icon(
              Icons.person_rounded,
              size: 70,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 25,
            child: Icon(
              Icons.star_rounded,
              size: 50,
              color: Colors.amber.withOpacity(0.15),
            ),
          ),
          Positioned(
            top: 60,
            left: 40,
            child: Transform.rotate(
              angle: 0.3,
              child: Icon(
                Icons.emoji_events_rounded,
                size: 40,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          // Content
          Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Hero(
                        tag: 'profile_avatar',
                        child: Container(
                          width: isTablet ? 140 : 120,
                          height: isTablet ? 140 : 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child:
                              _profile!.avatarUrl != null &&
                                  _profile!.avatarUrl!.isNotEmpty
                              ? ClipOval(
                                  child: Image.network(
                                    _profile!.avatarUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return _buildDefaultAvatar(isTablet);
                                    },
                                  ),
                                )
                              : _buildDefaultAvatar(isTablet),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _showAvatarOptions,
                          child: Container(
                            width: isTablet ? 44 : 40,
                            height: isTablet ? 44 : 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.camera_alt_rounded,
                              size: isTablet ? 22 : 20,
                              color: const Color(0xFF1976D2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isTablet ? 20 : 16),
                  Text(
                    _profile!.username.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isTablet ? 32 : 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isTablet ? 12 : 8),
                  Text(
                    _profile!.email,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: isTablet ? 16 : 14,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_profile!.bio != null && _profile!.bio!.isNotEmpty) ...[
                    SizedBox(height: isTablet ? 12 : 8),
                    Text(
                      _profile!.bio!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: isTablet ? 15 : 13,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar(bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade400, Colors.blue.shade600],
        ),
      ),
      child: Center(
        child: Text(
          _profile!.username[0].toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontSize: isTablet ? 56 : 48,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard(double screenWidth, bool isTablet) {
    final maxWidth = isTablet ? 800.0 : screenWidth;
    final padding = isTablet ? 32.0 : 16.0;

    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: EdgeInsets.symmetric(horizontal: padding),
        padding: EdgeInsets.all(isTablet ? 28 : 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade600.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Rating
            Container(
              padding: EdgeInsets.all(isTablet ? 24 : 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.amber.shade400, Colors.orange.shade600],
                ),
                borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(isTablet ? 12 : 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.star_rounded,
                      color: Colors.white,
                      size: isTablet ? 36 : 32,
                    ),
                  ),
                  SizedBox(width: isTablet ? 20 : 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RATING',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                      SizedBox(height: isTablet ? 6 : 4),
                      Text(
                        '${_profile!.rating}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isTablet ? 40 : 36,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: isTablet ? 28 : 24),
            // Stats grid
            LayoutBuilder(
              builder: (context, constraints) {
                return Wrap(
                  spacing: isTablet ? 16 : 12,
                  runSpacing: isTablet ? 16 : 12,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildStatItem(
                      'THẮNG',
                      '${_profile!.wins}',
                      const Color(0xFF4CAF50),
                      constraints.maxWidth / 3 - (isTablet ? 11 : 8),
                      isTablet,
                    ),
                    _buildStatItem(
                      'THUA',
                      '${_profile!.losses}',
                      const Color(0xFFF44336),
                      constraints.maxWidth / 3 - (isTablet ? 11 : 8),
                      isTablet,
                    ),
                    _buildStatItem(
                      'HÒA',
                      '${_profile!.draws}',
                      const Color(0xFF9E9E9E),
                      constraints.maxWidth / 3 - (isTablet ? 11 : 8),
                      isTablet,
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: isTablet ? 24 : 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TỶ LỆ THẮNG',
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '${_profile!.winRate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: isTablet ? 20 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
            SizedBox(height: isTablet ? 12 : 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(isTablet ? 12 : 10),
              child: LinearProgressIndicator(
                value: _profile!.winRate / 100,
                minHeight: isTablet ? 16 : 14,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
              ),
            ),
            SizedBox(height: isTablet ? 24 : 20),
            Container(
              padding: EdgeInsets.all(isTablet ? 16 : 14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
                border: Border.all(
                  color: Colors.blue.shade600.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.games_rounded,
                    color: Colors.blue.shade600,
                    size: isTablet ? 26 : 24,
                  ),
                  SizedBox(width: isTablet ? 12 : 10),
                  Text(
                    'TỔNG SỐ TRẬN: ${_profile!.totalMatches}',
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.blue.shade600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isTablet ? 16 : 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  color: Colors.grey.shade500,
                  size: isTablet ? 16 : 14,
                ),
                SizedBox(width: isTablet ? 8 : 6),
                Text(
                  'Tham gia: ${DateFormat('dd/MM/yyyy').format(_profile!.createdAt)}',
                  style: TextStyle(
                    fontSize: isTablet ? 14 : 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    Color color,
    double width,
    bool isTablet,
  ) {
    return Container(
      width: width,
      padding: EdgeInsets.all(isTablet ? 18 : 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: isTablet ? 28 : 24,
              fontWeight: FontWeight.bold,
              color: color,
              height: 1.0,
            ),
          ),
          SizedBox(height: isTablet ? 8 : 6),
          Text(
            label,
            style: TextStyle(
              fontSize: isTablet ? 13 : 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(double screenWidth, bool isTablet) {
    final maxWidth = isTablet ? 800.0 : screenWidth;
    final padding = isTablet ? 32.0 : 16.0;

    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: EdgeInsets.symmetric(horizontal: padding),
        child: Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.history_rounded,
                label: 'LỊCH SỬ',
                color: Colors.blue.shade600,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MatchHistoryScreen(),
                    ),
                  );
                },
                isTablet: isTablet,
              ),
            ),
            SizedBox(width: isTablet ? 20 : 16),
            Expanded(
              child: _buildActionButton(
                icon: Icons.people_rounded,
                label: 'BẠN BÈ',

                color: const Color(0xFF4CAF50),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FriendsScreen(),
                    ),
                  );
                },
                isTablet: isTablet,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    String? subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isTablet,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(isTablet ? 24 : 20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
            border: Border.all(color: color.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: isTablet ? 36 : 32),
              SizedBox(height: isTablet ? 12 : 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: isTablet ? 15 : 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 0.8,
                ),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                SizedBox(height: isTablet ? 6 : 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountSection(double screenWidth, bool isTablet) {
    return _buildSection(
      title: 'TÀI KHOẢN',
      screenWidth: screenWidth,
      isTablet: isTablet,
      items: [
        _buildMenuItem(
          icon: Icons.edit_rounded,
          title: 'Chỉnh Sửa Hồ Sơ',
          onTap: () async {
            final updated = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (context) => EditProfileScreen(profile: _profile!),
              ),
            );
            if (updated == true) {
              _loadProfile();
            }
          },
          isTablet: isTablet,
        ),
        if (_profile!.isLocalAccount)
          _buildMenuItem(
            icon: Icons.lock_rounded,
            title: 'Đổi Mật Khẩu',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChangePasswordScreen(),
                ),
              );
            },
            isTablet: isTablet,
          ),
      ],
    );
  }

  Widget _buildAppSection(double screenWidth, bool isTablet) {
    return _buildSection(
      title: 'ỨNG DỤNG',
      screenWidth: screenWidth,
      isTablet: isTablet,
      items: [
        _buildMenuItem(
          icon: Icons.settings_rounded,
          title: 'Cài Đặt',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
          isTablet: isTablet,
        ),
        _buildMenuItem(
          icon: Icons.info_outline_rounded,
          title: 'Giới Thiệu',
          onTap: () {
            showAboutDialog(
              context: context,
              applicationName: 'Game Plus',
              applicationVersion: '1.0.0',
              applicationLegalese: '© 2025 Game Plus',
            );
          },
          isTablet: isTablet,
        ),
      ],
    );
  }

  Widget _buildDangerZone(double screenWidth, bool isTablet) {
    return _buildSection(
      title: 'Hệ Thống',
      screenWidth: screenWidth,
      isTablet: isTablet,
      isDanger: true,
      items: [
        _buildMenuItem(
          icon: Icons.logout_rounded,
          title: 'Đăng Xuất',
          isDanger: true,
          onTap: _confirmLogout,
          isTablet: isTablet,
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required double screenWidth,
    required bool isTablet,
    required List<Widget> items,
    bool isDanger = false,
  }) {
    final maxWidth = isTablet ? 800.0 : screenWidth;
    final padding = isTablet ? 32.0 : 16.0;

    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: EdgeInsets.symmetric(horizontal: padding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
          border: isDanger
              ? Border.all(
                  color: const Color(0xFFF44336).withOpacity(0.3),
                  width: 2,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: isDanger
                  ? const Color(0xFFF44336).withOpacity(0.15)
                  : Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                isTablet ? 24 : 20,
                isTablet ? 24 : 20,
                isTablet ? 24 : 20,
                isTablet ? 12 : 8,
              ),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: isTablet ? 18 : 16,
                  fontWeight: FontWeight.bold,
                  color: isDanger
                      ? const Color(0xFFF44336)
                      : Colors.grey.shade800,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            ...items,
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isTablet,
    bool isDanger = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 24 : 20,
            vertical: isTablet ? 18 : 16,
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 12 : 10),
                decoration: BoxDecoration(
                  color: isDanger
                      ? const Color(0xFFF44336).withOpacity(0.1)
                      : Colors.blue.shade600.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isTablet ? 14 : 12),
                ),
                child: Icon(
                  icon,
                  color: isDanger
                      ? const Color(0xFFF44336)
                      : Colors.blue.shade600,
                  size: isTablet ? 26 : 24,
                ),
              ),
              SizedBox(width: isTablet ? 18 : 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.w600,
                    color: isDanger
                        ? const Color(0xFFF44336)
                        : Colors.grey.shade900,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade400,
                size: isTablet ? 28 : 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;

        return Center(
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 48 : 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: isTablet ? 100 : 80,
                  color: const Color(0xFFF44336).withOpacity(0.5),
                ),
                SizedBox(height: isTablet ? 24 : 16),
                Text(
                  'Đã xảy ra lỗi',
                  style: TextStyle(
                    fontSize: isTablet ? 24 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                SizedBox(height: isTablet ? 12 : 8),
                Text(
                  _error ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: isTablet ? 16 : 14,
                  ),
                ),
                SizedBox(height: isTablet ? 32 : 24),
                FilledButton.icon(
                  onPressed: _loadProfile,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Thử lại'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 32 : 24,
                      vertical: isTablet ? 16 : 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.link_rounded, color: Colors.blue.shade600),
                ),
                title: const Text(
                  'Nhập URL Avatar',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showEnterAvatarUrl();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF44336).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.delete_rounded,
                    color: Color(0xFFF44336),
                  ),
                ),
                title: const Text(
                  'Xóa Avatar',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await ProfileService.updateAvatar('');
                    _loadProfile();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Lỗi: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEnterAvatarUrl() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nhập URL Avatar'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://example.com/avatar.jpg',
            labelText: 'URL',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                try {
                  await ProfileService.updateAvatar(url);
                  _loadProfile();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Lỗi: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
