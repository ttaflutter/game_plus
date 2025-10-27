import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'auth_service.dart';
import '../schemas/auth_schemas.dart';

class GoogleAuthService {
  // Khởi tạo GoogleSignIn
  // Web cần clientId riêng, mobile tự động lấy từ config
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],

    clientId: kIsWeb
        ? 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com' // THAY ĐỔI NÀY!
        : null, // Mobile tự động detect
  );

  final AuthService _authService = AuthService();

  /// Sign in với Google và gửi thông tin đến backend
  Future<TokenResponse> signInWithGoogle() async {
    try {
      // 0. Sign out trước để user có thể chọn tài khoản khác
      // Không dùng tài khoản đã cache
      await _googleSignIn.signOut();

      // 1. Trigger Google Sign In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        throw Exception('Google Sign-In cancelled by user');
      }

      // 2. Lấy thông tin authentication
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 3. Lấy ID token (optional, chỉ cần để verify)
      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;

      print('🔑 ID Token: ${idToken != null ? "✅ Available" : "❌ Null"}');
      print(
        '🔑 Access Token: ${accessToken != null ? "✅ Available" : "❌ Null"}',
      );

      // ID token có thể null trên một số platform/config
      // Nhưng vẫn có thể lấy user info từ GoogleSignInAccount
      if (idToken == null && accessToken == null) {
        throw Exception(
          'Failed to get Google authentication tokens. '
          'Please check:\n'
          '1. SHA-1 fingerprint đã add vào Google Cloud Console chưa?\n'
          '2. OAuth consent screen đã setup chưa?\n'
          '3. Đợi 5-10 phút sau khi config xong.\n'
          'Run: cd android && gradlew signingReport',
        );
      }

      // 4. Parse user info
      final String email = googleUser.email;
      final String? name = googleUser.displayName;
      final String? avatarUrl = googleUser.photoUrl;
      final String sub = googleUser.id; // Google User ID

      print('📧 Google User: $email');
      print('👤 Name: $name');
      print('🆔 Google ID (sub): $sub');

      // 5. Gửi thông tin đến backend để tạo/login user
      final tokenResponse = await _authService.loginWithGoogle(
        email: email,
        name: name ?? email.split('@')[0],
        sub: sub,
        avatarUrl: avatarUrl,
      );

      print('✅ Google Login successful!');
      return tokenResponse;
    } catch (e) {
      print('❌ Google Sign-In error: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _authService.logout();
  }

  /// Check if user is currently signed in with Google
  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  /// Get current Google user (if signed in)
  Future<GoogleSignInAccount?> getCurrentUser() async {
    return _googleSignIn.currentUser;
  }
}
