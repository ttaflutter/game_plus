import 'package:flutter/material.dart';
import '../../../../models/profile_model.dart';
import '../../../../services/profile_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ProfileSettings? _settings;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final settings = await ProfileService.getSettings();
      if (mounted) {
        setState(() {
          _settings = settings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_settings == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await ProfileService.updateSettings(_settings!);
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Cài đặt đã được lưu'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài Đặt'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          if (_settings != null)
            TextButton(
              onPressed: _isSaving ? null : _saveSettings,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Lưu',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _settings == null
          ? const Center(child: Text('Không thể tải cài đặt'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSection(
                  title: 'Thông Báo',
                  children: [
                    _buildSwitchTile(
                      title: 'Lời mời kết bạn',
                      subtitle: 'Nhận thông báo khi có lời mời kết bạn',
                      value: _settings!.notifications.friendRequests,
                      onChanged: (value) {
                        setState(() {
                          _settings = ProfileSettings(
                            notifications: _settings!.notifications.copyWith(
                              friendRequests: value,
                            ),
                            language: _settings!.language,
                            theme: _settings!.theme,
                          );
                        });
                      },
                    ),
                    _buildSwitchTile(
                      title: 'Thách đấu',
                      subtitle: 'Nhận thông báo khi có người thách đấu',
                      value: _settings!.notifications.challenges,
                      onChanged: (value) {
                        setState(() {
                          _settings = ProfileSettings(
                            notifications: _settings!.notifications.copyWith(
                              challenges: value,
                            ),
                            language: _settings!.language,
                            theme: _settings!.theme,
                          );
                        });
                      },
                    ),
                    _buildSwitchTile(
                      title: 'Cập nhật trận đấu',
                      subtitle: 'Nhận thông báo về trận đấu của bạn',
                      value: _settings!.notifications.matchUpdates,
                      onChanged: (value) {
                        setState(() {
                          _settings = ProfileSettings(
                            notifications: _settings!.notifications.copyWith(
                              matchUpdates: value,
                            ),
                            language: _settings!.language,
                            theme: _settings!.theme,
                          );
                        });
                      },
                    ),
                    _buildSwitchTile(
                      title: 'Tin nhắn',
                      subtitle: 'Nhận thông báo khi có tin nhắn mới',
                      value: _settings!.notifications.chatMessages,
                      onChanged: (value) {
                        setState(() {
                          _settings = ProfileSettings(
                            notifications: _settings!.notifications.copyWith(
                              chatMessages: value,
                            ),
                            language: _settings!.language,
                            theme: _settings!.theme,
                          );
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: 'Giao Diện',
                  children: [
                    _buildSelectTile(
                      title: 'Ngôn ngữ',
                      value: _settings!.language == 'vi'
                          ? 'Tiếng Việt'
                          : 'English',
                      onTap: () => _showLanguageDialog(),
                    ),
                    _buildSelectTile(
                      title: 'Chủ đề',
                      value: _settings!.theme == 'light'
                          ? 'Sáng'
                          : _settings!.theme == 'dark'
                          ? 'Tối'
                          : 'Hệ thống',
                      onTap: () => _showThemeDialog(),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.blue.shade600,
    );
  }

  Widget _buildSelectTile({
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: Colors.grey.shade400),
        ],
      ),
      onTap: onTap,
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn Ngôn Ngữ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Tiếng Việt'),
              value: 'vi',
              groupValue: _settings!.language,
              onChanged: (value) {
                setState(() {
                  _settings = ProfileSettings(
                    notifications: _settings!.notifications,
                    language: value!,
                    theme: _settings!.theme,
                  );
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('English'),
              value: 'en',
              groupValue: _settings!.language,
              onChanged: (value) {
                setState(() {
                  _settings = ProfileSettings(
                    notifications: _settings!.notifications,
                    language: value!,
                    theme: _settings!.theme,
                  );
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn Chủ Đề'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Sáng'),
              value: 'light',
              groupValue: _settings!.theme,
              onChanged: (value) {
                setState(() {
                  _settings = ProfileSettings(
                    notifications: _settings!.notifications,
                    language: _settings!.language,
                    theme: value!,
                  );
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Tối'),
              value: 'dark',
              groupValue: _settings!.theme,
              onChanged: (value) {
                setState(() {
                  _settings = ProfileSettings(
                    notifications: _settings!.notifications,
                    language: _settings!.language,
                    theme: value!,
                  );
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Theo hệ thống'),
              value: 'system',
              groupValue: _settings!.theme,
              onChanged: (value) {
                setState(() {
                  _settings = ProfileSettings(
                    notifications: _settings!.notifications,
                    language: _settings!.language,
                    theme: value!,
                  );
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
