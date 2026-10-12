import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const WubachatApp());
}

class WubachatApp extends StatelessWidget {
  const WubachatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wubachat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00A884),
          primary: const Color(0xFF00A884),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const AuthScreen(),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  String selectedRole = 'user'; // 'user' ya 'admin'
  bool obscurePassword = true;
  bool isLoading = false;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Future<void> handleAuth() async {
    final phone = phoneController.text.trim();
    final password = passwordController.text.trim();
    final name = nameController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    if (!isLogin && name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final url = Uri.parse('https://web.wubachat.com/api/app_auth.php');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': isLogin ? 'login' : 'register',
          'phone': phone,
          'password': password,
          'role': selectedRole,
          'name': name,
        }),
      );

      final data = jsonDecode(response.body);

      if (data['status'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token'] ?? '');
        await prefs.setString('user_id', data['user']['id'].toString());
        await prefs.setString('user_name', data['user']['name'] ?? '');
        await prefs.setString('user_phone', data['user']['phone'] ?? '');
        await prefs.setString('user_role', data['user']['role'] ?? selectedRole);
        await prefs.setDouble('balance', (data['user']['balance'] as num).toDouble());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Success'),
              backgroundColor: const Color(0xFF00A884),
            ),
          );
          // Yahan se Home Screen navigate hogi
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Authentication failed')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Column(
                  children: [
                    const SizedBox(height: 35),
                    
                    // --- 1. WUBACHAT LOGO & BRANDING ---
                    Center(
                      child: Image.asset(
                        'assets/logo.png',
                        height: 95,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.chat_bubble_rounded,
                          size: 80,
                          color: Color(0xFF00A884),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'wubachat',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0B4636),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Text(
                      'Fast & Friendly Chats',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF0B4636),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 25),

                    // --- 2. LOGIN / REGISTER TABS ---
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => isLogin = true),
                            child: Column(
                              children: [
                                Text(
                                  'LOGIN',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isLogin ? const Color(0xFF00A884) : Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  height: 2.5,
                                  color: isLogin ? const Color(0xFF00A884) : Colors.transparent,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => isLogin = false),
                            child: Column(
                              children: [
                                Text(
                                  'REGISTER',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: !isLogin ? const Color(0xFF00A884) : Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  height: 2.5,
                                  color: !isLogin ? const Color(0xFF00A884) : Colors.transparent,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // --- 3. USER / ADMIN SELECTION ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Radio<String>(
                          value: 'user',
                          groupValue: selectedRole,
                          activeColor: const Color(0xFF00A884),
                          onChanged: (val) => setState(() => selectedRole = val!),
                        ),
                        const Text('User', style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(width: 30),
                        Radio<String>(
                          value: 'admin',
                          groupValue: selectedRole,
                          activeColor: const Color(0xFF00A884),
                          onChanged: (val) => setState(() => selectedRole = val!),
                        ),
                        const Text('Admin', style: TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // --- 4. EXTRA NAME FIELD (SIRF REGISTER PAR) ---
                    if (!isLogin) ...[
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          hintText: 'Full / Business Name',
                          prefixIcon: const Icon(Icons.person_outline),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade400),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF00A884), width: 1.8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // --- 5. MOBILE NUMBER INPUT ---
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        prefixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 12),
                            const Text('🇮🇳 +91', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(width: 8),
                            Container(width: 1, height: 22, color: Colors.grey.shade400),
                            const SizedBox(width: 10),
                          ],
                        ),
                        hintText: 'Mobile Number',
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF00A884), width: 1.8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // --- 6. PASSWORD INPUT ---
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: Colors.grey.shade600,
                          ),
                          onPressed: () => setState(() => obscurePassword = !obscurePassword),
                        ),
                        hintText: 'Password',
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF00A884), width: 1.8),
                        ),
                      ),
                    ),

                    if (isLogin) ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {},
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(color: Color(0xFF00A884), fontSize: 13),
                          ),
                        ),
                      ),
                    ] else
                      const SizedBox(height: 18),

                    // --- 7. CONTINUE ACTION BUTTON ---
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : handleAuth,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00A884),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    isLogin ? 'CONTINUE' : 'REGISTER NOW',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 25),
                  ],
                ),
              ),
            ),

            // --- 8. COMPACT BRANDING FOOTER (NO EXTRA VERTICAL GAP) ---
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              color: const Color(0xFFF8FAFC),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Upper Centered Website Link
                  GestureDetector(
                    onTap: () => _launchURL('https://wubachat.com'),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.language, size: 15, color: Colors.grey),
                        SizedBox(width: 5),
                        Text(
                          'https://wubachat.com',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 7),
                  // Bottom Row: Side-by-Side (Support Email & Founder Credit)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => _launchURL('mailto:support@wubachat.com'),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.email_outlined, size: 14, color: Colors.grey),
                            SizedBox(width: 4),
                            Text(
                              'support@wubachat.com',
                              style: TextStyle(fontSize: 11.5, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 14, color: Color(0xFF00A884)),
                          SizedBox(width: 4),
                          Text(
                            'Founder : Humera Ameer',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0B4636),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
