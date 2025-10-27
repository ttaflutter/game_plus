// lib/ui/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:game_plus/schemas/auth_schemas.dart';
import 'package:game_plus/services/auth_service.dart';
import 'package:game_plus/services/google_auth_service.dart';
import 'package:game_plus/ui/screens/caro/caro_home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _error;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = AuthService();
      final tokenRes = await service.register(
        RegisterRequest(
          username: _usernameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text.trim(),
        ),
      );

      // Save user info
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("username", tokenRes.user.username);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CaroHomeScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _registerWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _error = null;
    });

    try {
      final googleAuthService = GoogleAuthService();
      final tokenRes = await googleAuthService.signInWithGoogle();

      // Save user info
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("username", tokenRes.user.username);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CaroHomeScreen()),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _error = e
              .toString()
              .replaceAll('Exception: ', '')
              .replaceAll('PlatformException', 'Google Sign-In không khả dụng');
        });
        print('❌ Google Sign-In Error Details: $e');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Đăng ký Google thất bại. Vui lòng dùng Email/Password.';
        });
        print('❌ Unexpected Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 600;
    final maxWidth = isSmallScreen ? screenWidth : 500.0;

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
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    screenHeight -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 24 : 40,
                      vertical: 40,
                    ),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Container(
                          constraints: BoxConstraints(maxWidth: maxWidth),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Logo & Title
                              _buildHeader(isSmallScreen),

                              SizedBox(height: isSmallScreen ? 32 : 48),

                              // Register Card
                              _buildRegisterCard(isSmallScreen),

                              SizedBox(height: isSmallScreen ? 24 : 32),

                              // Login link
                              _buildLoginLink(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isSmallScreen) {
    return Column(
      children: [
        // Logo/Icon
        Container(
          width: isSmallScreen ? 80 : 100,
          height: isSmallScreen ? 80 : 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Colors.white, Colors.white.withOpacity(0.9)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Icon(
            Icons.person_add_rounded,
            size: isSmallScreen ? 48 : 60,
            color: Colors.blue.shade600,
          ),
        ),
        SizedBox(height: isSmallScreen ? 16 : 24),
        // Title
        Text(
          'Create Account',
          style: TextStyle(
            fontSize: isSmallScreen ? 28 : 36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: isSmallScreen ? 8 : 12),
        Text(
          'Join us and start your gaming journey',
          style: TextStyle(
            fontSize: isSmallScreen ? 14 : 16,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRegisterCard(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 24 : 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 30,
            spreadRadius: 10,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Google Sign-Up Button
            if (!kIsWeb) ...[
              _buildGoogleButton(isSmallScreen),
              SizedBox(height: isSmallScreen ? 20 : 24),

              // Divider
              Row(
                children: [
                  Expanded(
                    child: Divider(color: Colors.grey.shade300, thickness: 1),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(color: Colors.grey.shade300, thickness: 1),
                  ),
                ],
              ),
              SizedBox(height: isSmallScreen ? 20 : 24),
            ],

            // Username Field
            _buildUsernameField(isSmallScreen),

            SizedBox(height: isSmallScreen ? 16 : 20),

            // Email Field
            _buildEmailField(isSmallScreen),

            SizedBox(height: isSmallScreen ? 16 : 20),

            // Password Field
            _buildPasswordField(isSmallScreen),

            SizedBox(height: isSmallScreen ? 16 : 20),

            // Confirm Password Field
            _buildConfirmPasswordField(isSmallScreen),

            SizedBox(height: isSmallScreen ? 20 : 24),

            // Error Message
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: isSmallScreen ? 13 : 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isSmallScreen ? 16 : 20),
            ],

            // Register Button
            _buildRegisterButton(isSmallScreen),

            SizedBox(height: isSmallScreen ? 16 : 20),

            // Terms & Privacy
            _buildTermsText(isSmallScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleButton(bool isSmallScreen) {
    return SizedBox(
      height: isSmallScreen ? 52 : 56,
      child: OutlinedButton.icon(
        onPressed: _isGoogleLoading ? null : _registerWithGoogle,
        icon: _isGoogleLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.grey.shade600),
                ),
              )
            : Image.network(
                'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                width: 20,
                height: 20,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.g_mobiledata_rounded,
                  size: 28,
                  color: Colors.grey.shade700,
                ),
              ),
        label: Text(
          'Continue with Google',
          style: TextStyle(
            fontSize: isSmallScreen ? 15 : 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
            letterSpacing: 0.3,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildUsernameField(bool isSmallScreen) {
    return TextFormField(
      controller: _usernameCtrl,
      keyboardType: TextInputType.text,
      style: TextStyle(
        fontSize: isSmallScreen ? 15 : 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: 'Username',
        hintText: 'Choose a username',
        prefixIcon: Icon(
          Icons.account_circle_outlined,
          color: Colors.blue.shade600,
          size: 22,
        ),
        labelStyle: TextStyle(
          fontSize: isSmallScreen ? 14 : 15,
          color: Colors.grey.shade700,
        ),
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
          fontSize: isSmallScreen ? 14 : 15,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.purple.shade600, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.shade600, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return "Please enter a username";
        if (v.length < 3) return "Username must be at least 3 characters";
        if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) {
          return "Only letters, numbers, and underscore allowed";
        }
        return null;
      },
    );
  }

  Widget _buildEmailField(bool isSmallScreen) {
    return TextFormField(
      controller: _emailCtrl,
      keyboardType: TextInputType.emailAddress,
      style: TextStyle(
        fontSize: isSmallScreen ? 15 : 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: 'Email',
        hintText: 'your@email.com',
        prefixIcon: Icon(
          Icons.email_outlined,
          color: Colors.blue.shade600,
          size: 22,
        ),
        labelStyle: TextStyle(
          fontSize: isSmallScreen ? 14 : 15,
          color: Colors.grey.shade700,
        ),
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
          fontSize: isSmallScreen ? 14 : 15,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.shade600, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return "Please enter your email";
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
          return "Please enter a valid email";
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField(bool isSmallScreen) {
    return TextFormField(
      controller: _passwordCtrl,
      obscureText: _obscurePassword,
      style: TextStyle(
        fontSize: isSmallScreen ? 15 : 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: 'Create a strong password',
        prefixIcon: Icon(
          Icons.lock_outline,
          color: Colors.blue.shade600,
          size: 22,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey.shade600,
            size: 22,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        labelStyle: TextStyle(
          fontSize: isSmallScreen ? 14 : 15,
          color: Colors.grey.shade700,
        ),
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
          fontSize: isSmallScreen ? 14 : 15,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.shade600, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return "Please enter a password";
        if (v.length < 6) return "Password must be at least 6 characters";
        return null;
      },
    );
  }

  Widget _buildConfirmPasswordField(bool isSmallScreen) {
    return TextFormField(
      controller: _confirmPasswordCtrl,
      obscureText: _obscureConfirmPassword,
      style: TextStyle(
        fontSize: isSmallScreen ? 15 : 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: 'Confirm Password',
        hintText: 'Re-enter your password',
        prefixIcon: Icon(
          Icons.lock_outline,
          color: Colors.blue.shade600,
          size: 22,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey.shade600,
            size: 22,
          ),
          onPressed: () {
            setState(() {
              _obscureConfirmPassword = !_obscureConfirmPassword;
            });
          },
        ),
        labelStyle: TextStyle(
          fontSize: isSmallScreen ? 14 : 15,
          color: Colors.grey.shade700,
        ),
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
          fontSize: isSmallScreen ? 14 : 15,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.shade600, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return "Please confirm your password";
        if (v != _passwordCtrl.text) return "Passwords do not match";
        return null;
      },
    );
  }

  Widget _buildRegisterButton(bool isSmallScreen) {
    return SizedBox(
      height: isSmallScreen ? 52 : 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _register,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 4,
          shadowColor: Colors.blue.shade600.withOpacity(0.4),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
      ),
    );
  }

  Widget _buildTermsText(bool isSmallScreen) {
    return Text(
      'By creating an account, you agree to our Terms of Service and Privacy Policy',
      style: TextStyle(
        fontSize: isSmallScreen ? 11 : 12,
        color: Colors.grey.shade600,
        height: 1.4,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Already have an account? ",
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Sign In',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
              decorationColor: Colors.white,
              decorationThickness: 2,
            ),
          ),
        ),
      ],
    );
  }
}
