// /lib/login_page.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'home_page.dart';
import 'signup_page.dart';
import 'services/biometric_service.dart';
import 'package:local_auth/local_auth.dart';
import 'config/api_config.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool loading = false;
  bool isPasswordVisible = false;
  final BiometricService _biometricService = BiometricService();
  bool _hasBiometricSaved = false;
  bool _isCheckingBiometric = true;
  bool _biometricInProgress = false; // PREVENT DOUBLE BIOMETRIC

  @override
  void initState() {
    super.initState();
    emailController.text = '';
    passwordController.text = '';
    _checkBiometricAndAutoLogin();
  }

  Future<void> _checkBiometricAndAutoLogin() async {
    setState(() => _isCheckingBiometric = true);

    final prefs = await SharedPreferences.getInstance();
    final lastEmail = prefs.getString('last_login_email');

    if (lastEmail != null) {
      emailController.text = lastEmail;
      final hasBiometric = await _biometricService.isBiometricEnabledForUser(lastEmail);

      setState(() {
        _hasBiometricSaved = hasBiometric;
      });

      // ONLY attempt biometric if not already in progress
      if (hasBiometric && !_biometricInProgress && mounted) {
        _biometricInProgress = true;
        await _performBiometricAutoLogin(lastEmail);
      }
    }

    if (mounted) {
      setState(() => _isCheckingBiometric = false);
    }
  }

  Future<void> _performBiometricAutoLogin(String email) async {
    if (!mounted) return;

    print('🔐 Showing fingerprint prompt for: $email');

    // Show fingerprint dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Biometric Login'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fingerprint, size: 80, color: Color(0xFF9D2BD1)),
            const SizedBox(height: 16),
            const Text('Verify your identity', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9D2BD1)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _biometricInProgress = false;
              },
              child: const Text('Use Password'),
            ),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 500));

    final authenticated = await _biometricService.authenticateWithBiometrics();

    if (!mounted) return;
    Navigator.pop(context); // Close dialog

    if (authenticated) {
      print('✅ Fingerprint success, logging in...');

      // Get user data via biometric login - PASS alreadyAuthenticated=true to skip second prompt
      final userData = await _biometricService.biometricLogin(email, alreadyAuthenticated: true);

      if (userData != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric login successful!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage(user: userData)),
        );
        return;
      }
    }

    // Fingerprint failed - reset flag
    _biometricInProgress = false;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometric failed. Please login manually.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> login() async {
    final String email = emailController.text.trim();
    final String password = passwordController.text;

    // B-01-260313: Invalid Email Syntax validation
    // Check if email is empty
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email address is required'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Validate email contains @ symbol
    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please include an "@" in the email address.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Optional: Additional validation for proper email format
    final atIndex = email.indexOf('@');
    if (atIndex == 0 || atIndex == email.length - 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address (e.g., name@domain.com)'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Check if password is empty
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password is required'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => loading = true);

    final Uri url = Uri.parse('${ApiConfig.baseUrl}/login');

    print('🔄 Attempting login to: $url');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 30));

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (!mounted) return;

        // Save last login email
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_login_email', email);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login successful!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );

        setState(() => loading = false);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage(user: data['user'])),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['error'] ?? 'Login failed'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => loading = false);
      }
    } catch (e) {
      print('❌ Login error: $e');

      // Show specific error message
      String errorMsg = 'Connection failed. ';
      if (e.toString().contains('SocketException')) {
        errorMsg = 'Cannot connect to server. Please check your internet connection.';
      } else if (e.toString().contains('TimeoutException')) {
        errorMsg = 'Server is taking too long to respond. Please try again.';
      } else if (e.toString().contains('Failed host lookup')) {
        errorMsg = 'Cannot resolve server address. Please check your internet connection.';
      } else {
        errorMsg = 'Error: $e';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingBiometric) {
      return Scaffold(
        body: Container(
          height: double.infinity,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFA12DC6), Color(0xFFE06C75), Color(0xFFFADB5F)],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                SizedBox(height: 16),
                Text(
                  'Checking for biometric login...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFA12DC6), Color(0xFFE06C75), Color(0xFFFADB5F)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (constraints.maxWidth > 600) const SizedBox(width: 0),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 380),
                      margin: EdgeInsets.symmetric(
                        horizontal: constraints.maxWidth > 600 ? 0 : 16,
                        vertical: 16,
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Login Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.only(
                              top: 50,
                              left: 40,
                              right: 40,
                              bottom: 40,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 35,
                                  offset: Offset(0, 15),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Title
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Log In',
                                    style: TextStyle(
                                      color: Color(0xFF9610D4),
                                      fontSize: 45,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 30),

                                // Email Field
                                _buildInputField(
                                  label: 'Email',
                                  controller: emailController,
                                  obscureText: false,
                                ),
                                const SizedBox(height: 20),

                                // Password Field
                                _buildInputField(
                                  label: 'Password',
                                  controller: passwordController,
                                  obscureText: !isPasswordVisible,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      isPasswordVisible
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        isPasswordVisible = !isPasswordVisible;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(height: 30),

                                // Login Button
                                if (loading)
                                  const Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF9D2BD1),
                                      ),
                                    ),
                                  )
                                else
                                  _buildLoginButton(),

                                const SizedBox(height: 12),
                                const SizedBox(height: 16),

                                // Signup Link
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushReplacementNamed(
                                      context,
                                      '/signup',
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF9D2BD1),
                                  ),
                                  child: const Text(
                                    'Don\'t have an account? Sign up',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Floating M+ Logo
                          Positioned(
                            top: -65,
                            right: constraints.maxWidth > 600 ? 110 : 90,
                            child: Container(
                              padding: const EdgeInsets.all(0),
                              child: _MPlusLogo(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (constraints.maxWidth > 600) const SizedBox(width: 100),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required bool obscureText,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6A6A6A),
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF6F6F6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFD1D1D1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFD1D1D1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF9D2BD1), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: login,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF9D2BD1),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Log In',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// Custom M+ Logo Widget
class _MPlusLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 100,
            fontWeight: FontWeight.w900,
            letterSpacing: -2,
          ),
          children: [
            TextSpan(
              text: 'M',
              style: TextStyle(
                foreground: Paint()
                  ..shader = const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF8300bb), Color(0xFFff910b)],
                  ).createShader(const Rect.fromLTWH(0, 0, 200, 200))
                  ..style = PaintingStyle.fill,
              ),
            ),
            TextSpan(
              text: '+',
              style: TextStyle(
                fontSize: 50,
                foreground: Paint()
                  ..shader = const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF8300bb), Color(0xFFff910b)],
                  ).createShader(const Rect.fromLTWH(0, 0, 200, 200))
                  ..style = PaintingStyle.fill,
              ),
            ),
          ],
        ),
      ),
    );
  }
}