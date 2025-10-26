# PROFILE API Documentation

## Overview

API cho chức năng Profile Screen với các tính năng xem và chỉnh sửa thông tin cá nhân, đổi mật khẩu, cập nhật avatar, và quản lý cài đặt.

---

## Endpoints

### 1. GET `/api/profile/me` - Xem profile đầy đủ

**Description:** Lấy thông tin profile chi tiết của người dùng hiện tại.

**Headers:**

- `Authorization: Bearer <token>` (required)

**Response:**

```json
{
  "id": 5,
  "username": "devtest",
  "email": "devtest@example.com",
  "avatar_url": "https://example.com/avatar.jpg",
  "bio": "Professional Caro player",
  "provider": "local",
  "created_at": "2025-10-20T10:30:00Z",
  "rating": 1450,
  "total_matches": 37,
  "wins": 25,
  "losses": 10,
  "draws": 2,
  "win_rate": 67.57,
  "total_friends": 15
}
```

**Use Cases:**

- Hiển thị Profile Screen
- Load data khi mở app
- Refresh profile sau khi update

---

### 2. PUT `/api/profile/update` - Cập nhật profile

**Description:** Cập nhật thông tin cá nhân (username, bio, avatar).

**Headers:**

- `Authorization: Bearer <token>` (required)

**Request Body:**

```json
{
  "username": "newusername",
  "bio": "Updated bio",
  "avatar_url": "https://example.com/new-avatar.jpg"
}
```

**Note:** Tất cả fields đều optional. Chỉ cần gửi field muốn update.

**Response:** Giống như `/api/profile/me` (profile đầy đủ sau khi update)

**Validation:**

- `username`: 3-50 ký tự, phải unique
- `bio`: Tối đa 500 ký tự
- `avatar_url`: URL hợp lệ

**Use Cases:**

- Edit Profile Screen
- Update thông tin cá nhân

---

### 3. PUT `/api/profile/avatar` - Cập nhật avatar

**Description:** Endpoint riêng để update avatar nhanh chóng.

**Headers:**

- `Authorization: Bearer <token>` (required)

**Request Body:**

```json
{
  "avatar_url": "https://example.com/new-avatar.jpg"
}
```

**Response:** Profile đầy đủ sau khi update

**Use Cases:**

- Upload avatar từ gallery/camera
- Change avatar nhanh
- Avatar picker screen

---

### 4. POST `/api/profile/change-password` - Đổi mật khẩu

**Description:** Đổi mật khẩu cho local account.

**Headers:**

- `Authorization: Bearer <token>` (required)

**Request Body:**

```json
{
  "old_password": "oldpassword123",
  "new_password": "newpassword456"
}
```

**Response:**

```json
{
  "message": "Password changed successfully",
  "success": true
}
```

**Errors:**

- `400` - Provider không phải local (Google OAuth account)
- `400` - Mật khẩu cũ không đúng
- `400` - Mật khẩu mới giống mật khẩu cũ

**Validation:**

- Mật khẩu cũ phải đúng
- Mật khẩu mới tối thiểu 6 ký tự
- Mật khẩu mới phải khác mật khẩu cũ

**Use Cases:**

- Change Password Screen
- Security settings

**Note:** Chỉ áp dụng cho local account. Google OAuth account không thể đổi mật khẩu.

---

### 5. DELETE `/api/profile/delete-account` - Xóa tài khoản

**Description:** Xóa tài khoản và tất cả dữ liệu liên quan.

**Headers:**

- `Authorization: Bearer <token>` (required)

**Query Parameters:**

- `password` (string, optional): Mật khẩu xác nhận (required nếu là local account)

**Request:**

```
DELETE /api/profile/delete-account?password=mypassword123
```

**Response:**

```json
{
  "message": "Account deleted successfully",
  "success": true
}
```

**Warnings:**

- ⚠️ Hành động này không thể hoàn tác
- ⚠️ Tất cả dữ liệu sẽ bị xóa: matches, friends, ratings, etc.

**Use Cases:**

- Delete Account Screen
- Account settings

---

### 6. POST `/api/profile/logout` - Đăng xuất

**Description:** Đăng xuất khỏi app.

**Headers:**

- `Authorization: Bearer <token>` (required)

**Response:**

```json
{
  "message": "Logged out successfully",
  "success": true,
  "instruction": "Please delete the access token from client storage"
}
```

**Note:**

- JWT không có state trên server, nên logout được handle ở client
- Client cần xóa token khỏi storage (SharedPreferences, SecureStorage, etc.)
- Endpoint này chỉ để confirm action

**Use Cases:**

- Logout button
- Settings screen

---

### 7. GET `/api/profile/stats` - Thống kê chi tiết

**Description:** Lấy thống kê chi tiết hơn.

**Headers:**

- `Authorization: Bearer <token>` (required)

**Query Parameters:**

- `game_name` (string, optional): Tên game (mặc định: "Caro")

**Response:**

```json
{
  "rating": 1450,
  "total_matches": 37,
  "wins": 25,
  "losses": 10,
  "draws": 2,
  "win_rate": 67.57
}
```

**Use Cases:**

- Stats detail screen
- Performance analytics

---

### 8. GET `/api/profile/settings` - Lấy cài đặt

**Description:** Lấy cài đặt người dùng.

**Headers:**

- `Authorization: Bearer <token>` (required)

**Response:**

```json
{
  "notifications": {
    "friend_requests": true,
    "challenges": true,
    "match_updates": true,
    "chat_messages": true
  },
  "language": "vi",
  "theme": "light"
}
```

**Note:** Hiện tại return default settings. TODO: Lưu vào database.

---

### 9. PUT `/api/profile/settings` - Cập nhật cài đặt

**Description:** Cập nhật cài đặt người dùng.

**Headers:**

- `Authorization: Bearer <token>` (required)

**Request Body:**

```json
{
  "notifications": {
    "friend_requests": true,
    "challenges": false,
    "match_updates": true,
    "chat_messages": true
  },
  "language": "en",
  "theme": "dark"
}
```

**Response:**

```json
{
  "message": "Settings updated successfully",
  "settings": { ... }
}
```

---

## Workflow cho Flutter App

### Profile Screen Structure

```dart
class ProfileScreen extends StatefulWidget {
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfileDetail? profile;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    setState(() => isLoading = true);
    try {
      final response = await dio.get('/api/profile/me');
      setState(() {
        profile = UserProfileDetail.fromJson(response.data);
        isLoading = false;
      });
    } catch (e) {
      // Handle error
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Avatar
          ProfileAvatar(
            imageUrl: profile!.avatar_url,
            onTap: () => _showAvatarOptions(),
          ),

          // Username & Bio
          ProfileInfo(
            username: profile!.username,
            bio: profile!.bio,
            onEdit: () => _showEditProfile(),
          ),

          // Stats Card
          StatsCard(
            rating: profile!.rating,
            wins: profile!.wins,
            losses: profile!.losses,
            draws: profile!.draws,
            winRate: profile!.win_rate,
          ),

          // Friends Count
          FriendsCount(
            total: profile!.total_friends,
            onTap: () => _navigateToFriends(),
          ),

          // Settings Sections
          SettingsSection(
            title: 'Account',
            items: [
              SettingsItem('Edit Profile', () => _showEditProfile()),
              SettingsItem('Change Password', () => _showChangePassword()),
              SettingsItem('Notifications', () => _showNotifications()),
            ],
          ),

          SettingsSection(
            title: 'App',
            items: [
              SettingsItem('Language', () => _showLanguage()),
              SettingsItem('Theme', () => _showTheme()),
            ],
          ),

          SettingsSection(
            title: 'Danger Zone',
            items: [
              SettingsItem('Delete Account', () => _confirmDeleteAccount()),
              SettingsItem('Logout', () => _confirmLogout()),
            ],
            isDanger: true,
          ),
        ],
      ),
    );
  }

  void _showEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(profile: profile!),
      ),
    ).then((updated) {
      if (updated == true) {
        loadProfile(); // Refresh
      }
    });
  }

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => AvatarOptionsSheet(
        onGallery: () => _pickFromGallery(),
        onCamera: () => _pickFromCamera(),
        onUrl: () => _showEnterUrl(),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      // Upload to server/storage
      final url = await uploadImage(image);

      // Update avatar
      await dio.put('/api/profile/avatar', data: {
        'avatar_url': url,
      });

      // Refresh
      loadProfile();
    }
  }

  void _showChangePassword() async {
    if (profile!.provider != 'local') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Cannot Change Password'),
          content: Text(
            'You signed in with ${profile!.provider}. '
            'Please use ${profile!.provider} to manage your password.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangePasswordScreen(),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout'),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _logout();
            },
            child: Text('Logout'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    try {
      // Call logout endpoint (optional)
      await dio.post('/api/profile/logout');

      // Delete token from storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');

      // Navigate to login
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      // Handle error
    }
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Account'),
        content: Text(
          'Are you sure you want to delete your account? '
          'This action cannot be undone and all your data will be lost.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showDeleteConfirmation();
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() async {
    if (profile!.provider == 'local') {
      // Show password input
      final password = await showDialog<String>(
        context: context,
        builder: (context) => PasswordConfirmDialog(),
      );

      if (password != null) {
        await _deleteAccount(password);
      }
    } else {
      // Google account, no password needed
      await _deleteAccount(null);
    }
  }

  Future<void> _deleteAccount(String? password) async {
    try {
      await dio.delete(
        '/api/profile/delete-account',
        queryParameters: password != null ? {'password': password} : null,
      );

      // Clear storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Navigate to login
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      // Handle error
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Error'),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}
```

### Edit Profile Screen

```dart
class EditProfileScreen extends StatefulWidget {
  final UserProfileDetail profile;

  const EditProfileScreen({required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController usernameController;
  late TextEditingController bioController;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    usernameController = TextEditingController(text: widget.profile.username);
    bioController = TextEditingController(text: widget.profile.bio ?? '');
  }

  Future<void> _saveChanges() async {
    setState(() => isLoading = true);

    try {
      await dio.put('/api/profile/update', data: {
        'username': usernameController.text,
        'bio': bioController.text,
      });

      Navigator.pop(context, true); // Return true = updated
    } catch (e) {
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: isLoading ? null : _saveChanges,
            child: Text('Save'),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                hintText: 'Enter username',
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: bioController,
              decoration: InputDecoration(
                labelText: 'Bio',
                hintText: 'Tell us about yourself',
              ),
              maxLines: 3,
              maxLength: 500,
            ),
          ],
        ),
      ),
    );
  }
}
```

### Change Password Screen

```dart
class ChangePasswordScreen extends StatefulWidget {
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final oldPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool isLoading = false;

  Future<void> _changePassword() async {
    // Validation
    if (newPasswordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    if (newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await dio.post('/api/profile/change-password', data: {
        'old_password': oldPasswordController.text,
        'new_password': newPasswordController.text,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password changed successfully')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Change Password')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: oldPasswordController,
              decoration: InputDecoration(labelText: 'Old Password'),
              obscureText: true,
            ),
            TextField(
              controller: newPasswordController,
              decoration: InputDecoration(labelText: 'New Password'),
              obscureText: true,
            ),
            TextField(
              controller: confirmPasswordController,
              decoration: InputDecoration(labelText: 'Confirm New Password'),
              obscureText: true,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: isLoading ? null : _changePassword,
              child: Text('Change Password'),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Error Handling

### Common Errors:

**400 Bad Request:**

- Username already taken
- Password incorrect
- Invalid validation

**401 Unauthorized:**

- Token expired/invalid

**403 Forbidden:**

- Cannot change password for OAuth account

### Example Error Response:

```json
{
  "detail": "Username already taken"
}
```

---

## Security Notes

1. **Password Change:**

   - Chỉ cho local accounts
   - Yêu cầu mật khẩu cũ
   - Mật khẩu mới phải khác cũ

2. **Account Deletion:**

   - Yêu cầu confirm mật khẩu
   - Không thể hoàn tác
   - Cascade delete tất cả data

3. **Token Management:**
   - JWT không có server-side state
   - Logout = xóa token ở client
   - Token auto expire

---

## Testing

### Get Profile

```bash
curl -X GET "http://localhost:8000/api/profile/me" \
  -H "Authorization: Bearer TOKEN"
```

### Update Profile

```bash
curl -X PUT "http://localhost:8000/api/profile/update" \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "newname",
    "bio": "New bio"
  }'
```

### Change Password

```bash
curl -X POST "http://localhost:8000/api/profile/change-password" \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "old_password": "old123",
    "new_password": "new456"
  }'
```

### Logout

```bash
curl -X POST "http://localhost:8000/api/profile/logout" \
  -H "Authorization: Bearer TOKEN"
```

---

## Future Enhancements

1. **Profile Picture Upload**: Direct upload endpoint thay vì URL
2. **Settings Persistence**: Lưu settings vào database
3. **Session Management**: Quản lý multiple sessions
4. **Two-Factor Authentication**: Bảo mật cao hơn
5. **Activity Log**: Track login history, actions
6. **Privacy Settings**: Control visibility
