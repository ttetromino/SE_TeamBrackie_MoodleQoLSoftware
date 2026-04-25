// /lib/signup_page.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'services/lms_service.dart';
import 'services/biometric_service.dart';
import 'package:local_auth/local_auth.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController lmsUsernameController = TextEditingController();
  final TextEditingController lmsPasswordController = TextEditingController();

  bool loading = false;
  bool isLmsPasswordVisible = false;
  final BiometricService _biometricService = BiometricService();
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  // US-01-T-02: Biometrics Verification

  Future<void> _checkBiometricAvailability() async {
    final available = await _biometricService.isBiometricAvailable();
    print('🔍 Biometric available: $available');
    setState(() {
      _biometricAvailable = available;
    });
  }

  Future<void> signup() async {
    final String name = nameController.text.trim();
    final String email = emailController.text.trim();
    final String password = passwordController.text.trim();
    final String lmsUsername = lmsUsernameController.text.trim();
    final String lmsPassword = lmsPasswordController.text.trim();

    // Validate all fields
    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        lmsUsername.isEmpty ||
        lmsPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All fields are required including LMS credentials'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // B-01-260313: Invalid Email Syntax
    // Validate email
    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please include an "@" in the email address.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => loading = true);

    // STEP 1: Verify LMS credentials first
    bool lmsVerified = await _verifyLMSCredentials(lmsUsername, lmsPassword);

    if (!lmsVerified) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'LMS login failed. Please check your uphslms.com credentials.',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    // STEP 2: If LMS credentials are valid, proceed with signup
    await _createAccount(name, email, password, lmsUsername, lmsPassword);
  }

  Future<void> _createAccount(
    String name,
    String email,
    String password,
    String lmsUsername,
    String lmsPassword,
  ) async {
    final Uri url = Uri.parse('http://10.0.2.2:5000/users');

    Map<String, dynamic> requestBody = {
      'name': name,
      'email': email,
      'password': password,
      'lmsUsername': lmsUsername,
      'lmsPassword': lmsPassword,
    };

    print('Creating account...');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      print('Response status: ${response.statusCode}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        if (!mounted) return;

        print('Attempting immediate LMS login after signup...');
        final lmsService = LMSService(userId: email);
        bool lmsLoginSuccess = await lmsService.loginToLMS(
          lmsUsername,
          lmsPassword,
        );

        if (lmsLoginSuccess) {
          print('LMS login successful after signup');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Signup successful! LMS connected.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          print('LMS login failed after signup');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Signup successful but LMS connection failed. You can try again in the app.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }

        // ALWAYS ask to enable biometrics after signup (if available)
        if (_biometricAvailable && mounted) {
          // Wait a moment for the snackbar to be visible
          await Future.delayed(const Duration(milliseconds: 500));
          _showBiometricSetupDialog(email);
        } else {
          // Navigate to login page
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['error'] ?? 'Signup failed'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => loading = false);
      }
    } catch (e) {
      print('Signup error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
      setState(() => loading = false);
    }
  }

  Future<bool> _verifyLMSCredentials(String username, String password) async {
    try {
      print('Verifying LMS credentials...');
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/api/lms/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        print('LMS credentials verified');
        return true;
      } else {
        print('LMS verification failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('LMS verification error: $e');
      return false;
    }
  }

  Future<void> _showBiometricSetupDialog(String email) async {
    // Get available biometrics
    final biometrics = await _biometricService.getAvailableBiometrics();
    String biometricTypeName = 'Biometric';
    if (biometrics.isNotEmpty) {
      biometricTypeName = _biometricService.getBiometricTypeName(
        biometrics.first,
      );
    }

    // Determine icon based on available biometrics
    IconData biometricIcon = Icons.fingerprint;
    if (biometrics.contains(BiometricType.face)) {
      biometricIcon = Icons.face;
    } else if (biometrics.contains(BiometricType.fingerprint)) {
      biometricIcon = Icons.fingerprint;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🔐 Secure Your Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF9D2BD1).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                biometricIcon,
                size: 60,
                color: const Color(0xFF9D2BD1),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Enable $biometricTypeName Login',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Use your ${biometrics.contains(BiometricType.fingerprint) ? 'fingerprint' : 'face ID'} to login quickly and securely.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.security, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your biometric data stays on your device and is never shared with our servers.',
                      style: TextStyle(fontSize: 12, color: Colors.green[800]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You can change this anytime in Settings',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => loading = true);

              // Show loading indicator
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Setting up biometric authentication...'),
                  duration: Duration(seconds: 2),
                ),
              );

              await Future.delayed(const Duration(milliseconds: 500));

              setState(() => loading = false);
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text('Set Up Later'),
          ),

          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => loading = true);

              // Show setup progress
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Setting up $biometricTypeName authentication...',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );

              // Enable biometric with better error handling
              bool enabled = false;
              try {
                enabled = await _biometricService.enableBiometric(email);
                print('Biometric enabled result: $enabled');
              } catch (e) {
                print('Error enabling biometric: $e');
                enabled = false;
              }

              setState(() => loading = false);

              if (enabled && mounted) {
                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✓ $biometricTypeName login enabled!'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );

                // Show success dialog
                await Future.delayed(const Duration(milliseconds: 500));

                if (mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => AlertDialog(
                      title: const Text('🎉 Success!'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 60,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '$biometricTypeName authentication enabled!',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Next time you login, use your $biometricTypeName for quick access.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pushReplacementNamed(context, '/login');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9D2BD1),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Continue to Login'),
                        ),
                      ],
                    ),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Could not enable biometrics. You can enable it later in settings.',
                      ),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 3),
                    ),
                  );

                  // Still navigate to login after a short delay
                  await Future.delayed(const Duration(seconds: 2));
                  if (mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9D2BD1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Enable $biometricTypeName',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showBiometricDemoDialog(String biometricTypeName) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Setup Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 60),
            const SizedBox(height: 16),
            Text(
              '$biometricTypeName authentication has been enabled!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(
              'Next time you login, you can use your $biometricTypeName instead of your password.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9D2BD1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up - MoodlePlus'),
        backgroundColor: const Color(0xFF9D2BD1),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF9D2BD1).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.school,
                  size: 40,
                  color: Color(0xFF9D2BD1),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Create Account',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sign up to access MoodlePlus and your LMS courses',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),

            // Personal Information Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Color(0xFF9D2BD1)),
                        const SizedBox(width: 8),
                        const Text(
                          'Personal Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                        hintText: 'Enter your full name',
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                        hintText: 'Enter your email',
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                        hintText: 'Create a password',
                      ),
                      obscureText: true,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // LMS Credentials Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.school, color: Color(0xFF9D2BD1)),
                        const SizedBox(width: 8),
                        const Text(
                          'LMS Credentials (Required)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.black.withOpacity(0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.black,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Will be verified before account creation',
                            style: TextStyle(color: Colors.black, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: lmsUsernameController,
                      decoration: const InputDecoration(
                        labelText: 'LMS Username',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                        hintText: 'Enter your uphslms.com username',
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: lmsPasswordController,
                      decoration: InputDecoration(
                        labelText: 'LMS Password',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline),
                        hintText: 'Enter your uphslms.com password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            isLmsPasswordVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              isLmsPasswordVisible = !isLmsPasswordVisible;
                            });
                          },
                        ),
                      ),
                      obscureText: !isLmsPasswordVisible,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Signup Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: loading ? null : signup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9D2BD1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: loading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Verifying credentials...'),
                        ],
                      )
                    : const Text(
                        'Sign Up',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: RichText(
                  text: TextSpan(
                    text: 'Already have an account? ',
                    style: const TextStyle(color: Colors.grey),
                    children: [
                      TextSpan(
                        text: 'Login',
                        style: TextStyle(
                          color: const Color(0xFF9D2BD1),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
