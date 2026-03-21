import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'home_page.dart';
import 'signup_page.dart';

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

  Future<void> login() async {
    final String email = emailController.text.trim();
    final String password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All fields are required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => loading = true);

    final Uri url = Uri.parse('http://10.0.2.2:5000/login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        if (!mounted) return;

        // Show LMS status message if credentials exist
        if (data['hasLMSCredentials'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login successful. LMS credentials found.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

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
      }
    } catch (e) {
      print('❌ Login error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => loading = false);
  }
    //     US-01-T-05: Create Login
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFA12DC6), // Purple
              Color(0xFFE06C75), // Pink/Red
              Color(0xFFFADB5F), // Yellow
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (constraints.maxWidth > 600)
                    const SizedBox(width: 0),
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
                                const SizedBox(height: 16),

                                // Signup Link
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushReplacementNamed(
                                        context,
                                        '/signup'
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
                  if (constraints.maxWidth > 600)
                    const SizedBox(width: 100),
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
    //     US-01-T-05: Create Login
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
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
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
