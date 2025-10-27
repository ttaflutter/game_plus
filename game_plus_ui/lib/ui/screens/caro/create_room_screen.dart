import 'package:flutter/material.dart';
import '../../../models/room_model.dart';
import '../../../services/room_service.dart';
import 'room_waiting_screen.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomNameController = TextEditingController();
  final _passwordController = TextEditingController();

  int _maxPlayers = 2;
  int _boardRows = 15;
  int _boardCols = 19;
  int _winLen = 5;
  bool _isPublic = true;
  bool _hasPassword = false;
  bool _isCreating = false;

  @override
  void dispose() {
    _roomNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final request = CreateRoomRequest(
        roomName: _roomNameController.text.trim(),
        password: _hasPassword ? _passwordController.text.trim() : null,
        maxPlayers: _maxPlayers,
        boardRows: _boardRows,
        boardCols: _boardCols,
        winLen: _winLen,
        isPublic: _isPublic,
      );

      final roomDetail = await RoomService.createRoom(request);

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Đã tạo phòng: ${roomDetail.roomCode}')),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          duration: const Duration(seconds: 2),
        ),
      );

      // Pop màn hình tạo phòng và navigate đến waiting screen
      navigator.pop(); // Pop CreateRoomScreen
      navigator.push(
        MaterialPageRoute(
          builder: (context) => RoomWaitingScreen(roomDetail: roomDetail),
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(e.toString())),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Tạo Phòng Mới'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Room Name
            _buildSectionTitle('Thông tin phòng', Icons.info_outline),
            const SizedBox(height: 12),
            _buildCard(
              child: Column(
                children: [
                  TextFormField(
                    controller: _roomNameController,
                    decoration: InputDecoration(
                      labelText: 'Tên phòng *',
                      hintText: 'Nhập tên phòng',
                      prefixIcon: const Icon(Icons.meeting_room_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Vui lòng nhập tên phòng';
                      }
                      if (value.trim().length > 100) {
                        return 'Tên phòng tối đa 100 ký tự';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Is Public
                  SwitchListTile(
                    value: _isPublic,
                    onChanged: (value) => setState(() => _isPublic = value),
                    title: const Text('Phòng công khai'),
                    subtitle: const Text(
                      'Hiển thị trong danh sách phòng',
                      style: TextStyle(fontSize: 12),
                    ),
                    secondary: Icon(
                      _isPublic ? Icons.public : Icons.lock_outline,
                      color: Colors.blue.shade600,
                    ),
                  ),
                  // Has Password
                  SwitchListTile(
                    value: _hasPassword,
                    onChanged: (value) => setState(() => _hasPassword = value),
                    title: const Text('Đặt mật khẩu'),
                    subtitle: const Text(
                      'Yêu cầu mật khẩu để tham gia',
                      style: TextStyle(fontSize: 12),
                    ),
                    secondary: Icon(
                      Icons.lock_rounded,
                      color: Colors.orange.shade600,
                    ),
                  ),
                  if (_hasPassword) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu *',
                        hintText: 'Nhập mật khẩu',
                        prefixIcon: const Icon(Icons.key_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (_hasPassword && (value == null || value.isEmpty)) {
                          return 'Vui lòng nhập mật khẩu';
                        }
                        if (_hasPassword && value!.length > 50) {
                          return 'Mật khẩu tối đa 50 ký tự';
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Game Settings
            _buildSectionTitle('Cài đặt game', Icons.settings_rounded),
            const SizedBox(height: 12),
            _buildCard(
              child: Column(
                children: [
                  // Max Players
                  _buildSliderOption(
                    title: 'Số người chơi',
                    value: _maxPlayers.toDouble(),
                    min: 2,
                    max: 4,
                    divisions: 2,
                    label: '$_maxPlayers người',
                    icon: Icons.people_rounded,
                    color: Colors.green,
                    onChanged: (value) =>
                        setState(() => _maxPlayers = value.toInt()),
                  ),
                  const Divider(height: 32),
                  // Board Rows
                  _buildSliderOption(
                    title: 'Số hàng',
                    value: _boardRows.toDouble(),
                    min: 10,
                    max: 20,
                    divisions: 10,
                    label: '$_boardRows hàng',
                    icon: Icons.view_headline_rounded,
                    color: Colors.blue,
                    onChanged: (value) =>
                        setState(() => _boardRows = value.toInt()),
                  ),
                  const Divider(height: 32),
                  // Board Cols
                  _buildSliderOption(
                    title: 'Số cột',
                    value: _boardCols.toDouble(),
                    min: 10,
                    max: 25,
                    divisions: 15,
                    label: '$_boardCols cột',
                    icon: Icons.view_week_rounded,
                    color: Colors.blue,
                    onChanged: (value) =>
                        setState(() => _boardCols = value.toInt()),
                  ),
                  const Divider(height: 32),
                  // Win Length
                  _buildSliderOption(
                    title: 'Số quân để thắng',
                    value: _winLen.toDouble(),
                    min: 3,
                    max: 7,
                    divisions: 4,
                    label: '$_winLen quân',
                    icon: Icons.emoji_events_rounded,
                    color: Colors.amber,
                    onChanged: (value) =>
                        setState(() => _winLen = value.toInt()),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Preview
            _buildSectionTitle('Xem trước', Icons.preview_rounded),
            const SizedBox(height: 12),
            _buildCard(
              child: Column(
                children: [
                  _buildPreviewRow(
                    'Bàn cờ',
                    '$_boardRows × $_boardCols',
                    Icons.grid_4x4_rounded,
                  ),
                  const Divider(height: 20),
                  _buildPreviewRow(
                    'Điều kiện thắng',
                    '$_winLen quân liên tiếp',
                    Icons.flag_rounded,
                  ),
                  const Divider(height: 20),
                  _buildPreviewRow(
                    'Số người',
                    '$_maxPlayers người chơi',
                    Icons.people_rounded,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Create Button
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createRoom,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isCreating
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
                          Icon(Icons.add_circle_rounded, size: 24),
                          SizedBox(width: 12),
                          Text(
                            'TẠO PHÒNG',
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

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: child,
    );
  }

  Widget _buildSliderOption({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String label,
    required IconData icon,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: label,
          activeColor: color,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildPreviewRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue.shade600),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }
}
