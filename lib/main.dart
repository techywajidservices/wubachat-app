import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.containsKey('user_id');
  runApp(WubachatApp(isLoggedIn: isLoggedIn));
}

class WubachatApp extends StatelessWidget {
  final bool isLoggedIn;
  const WubachatApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wubachat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF008069),
          primary: const Color(0xFF008069),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: isLoggedIn ? const HomeScreen() : const AuthScreen(),
    );
  }
}

// =========================================================================
// 1. AUTH SCREEN (LOGIN & REGISTER)
// =========================================================================
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  String selectedRole = 'user';
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
        await prefs.setString('user_name', data['user']['name'] ?? 'User');
        await prefs.setString('user_phone', data['user']['phone'] ?? phone);
        await prefs.setString('user_role', data['user']['role'] ?? selectedRole);
        await prefs.setDouble('balance', (data['user']['balance'] as num?)?.toDouble() ?? 0.0);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Authentication failed')),
          );
        }
      }
    } catch (e) {
      // Demo / Offline fallback testing ke liye
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', '1');
      await prefs.setString('user_name', name.isNotEmpty ? name : 'Wajid Ali');
      await prefs.setString('user_phone', phone);
      await prefs.setString('user_role', selectedRole);
      await prefs.setDouble('balance', 10.0);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
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
                    if (!isLogin) ...[
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          hintText: 'Full / Business Name',
                          prefixIcon: const Icon(Icons.person_outline),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF00A884), width: 1.8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF00A884), width: 1.8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                          child: const Text('Forgot Password?', style: TextStyle(color: Color(0xFF00A884), fontSize: 13)),
                        ),
                      ),
                    ] else
                      const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : handleAuth,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00A884),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
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
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              color: const Color(0xFFF8FAFC),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _launchURL('https://wubachat.com'),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.language, size: 15, color: Colors.grey),
                        SizedBox(width: 5),
                        Text(
                          'https://wubachat.com',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 7),
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
                            Text('support@wubachat.com', style: TextStyle(fontSize: 11.5, color: Colors.black87)),
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
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0B4636)),
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

// =========================================================================
// 2. WHATSAPP STYLE HOME SCREEN (CHATS, TOOLS, WALLET)
// =========================================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String userName = 'User';
  double balance = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('user_name') ?? 'User';
      balance = prefs.getDouble('balance') ?? 0.0;
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Wubachat',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 21, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF008069), // Classic WhatsApp Green
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (val) {
              if (val == 'logout') _logout();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'broadcast', child: Text('New Broadcast')),
              const PopupMenuItem(value: 'linked', child: Text('Linked Devices (Meta)')),
              const PopupMenuItem(value: 'settings', child: Text('Settings')),
              const PopupMenuItem(value: 'logout', child: Text('Logout', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3.5,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'CHATS'),
            Tab(text: 'TOOLS'),
            Tab(text: 'WALLET'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatsTab(),
          _buildToolsTab(),
          _buildWalletTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00A884),
        child: const Icon(Icons.chat, color: Colors.white),
        onPressed: () => _openNewChatDialog(context),
      ),
    );
  }

  // --- TAB 1: CHATS LIST ---
  Widget _buildChatsTab() {
    final mockChats = [
      {'name': 'Meta WhatsApp Cloud API', 'msg': 'Session active. Ready to broadcast.', 'time': '10:45 AM', 'unread': 1},
      {'name': 'Support Helpline', 'msg': 'Welcome to Wubachat! Let us know if you need help.', 'time': 'Yesterday', 'unread': 0},
      {'name': 'National Survey Team', 'msg': 'Vehicle claims verification sync updated.', 'time': '09/10/26', 'unread': 0},
    ];

    return ListView.separated(
      itemCount: mockChats.length,
      separatorBuilder: (context, index) => const Divider(height: 1, indent: 75),
      itemBuilder: (context, index) {
        final chat = mockChats[index];
        return ListTile(
          leading: CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFF25D366).withOpacity(0.18),
            child: const Icon(Icons.person, color: Color(0xFF008069), size: 30),
          ),
          title: Text(chat['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          subtitle: Text(
            chat['msg'] as String,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(chat['time'] as String, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
              const SizedBox(height: 4),
              if ((chat['unread'] as int) > 0)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: Color(0xFF25D366), shape: BoxShape.circle),
                  child: Text(
                    '${chat['unread']}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ChatDetailScreen(name: chat['name'] as String)),
            );
          },
        );
      },
    );
  }

  // --- TAB 2: TOOLS MODULE ---
  Widget _buildToolsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Modular Business & Utility Tools', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        _toolCard(
          icon: Icons.directions_car,
          title: 'mParivahan RC & DL Verification',
          subtitle: 'Instant vehicle details verification engine',
          badge: 'Services API',
        ),
        _toolCard(
          icon: Icons.picture_as_pdf,
          title: 'PDF to Excel Data Extractor',
          subtitle: 'Parse tabular documents directly into spreadsheets',
          badge: 'Online Tool',
        ),
        _toolCard(
          icon: Icons.campaign,
          title: 'Official WhatsApp Bulk Campaign',
          subtitle: 'Send approved templates via Meta Cloud API',
          badge: 'Wubachat Core',
        ),
      ],
    );
  }

  Widget _toolCard({required IconData icon, required String title, required String subtitle, required String badge}) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFF008069).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: const Color(0xFF008069)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: Chip(
          label: Text(badge, style: const TextStyle(fontSize: 10, color: Color(0xFF008069), fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF008069).withOpacity(0.08),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  // --- TAB 3: WALLET & ACCOUNT ---
  Widget _buildWalletTab() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF008069), Color(0xFF00A884)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Current Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 6),
                Text('₹${balance.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Credit'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF008069)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          ListTile(
            leading: const Icon(Icons.account_circle, color: Color(0xFF008069)),
            title: Text(userName),
            subtitle: const Text('Account Name'),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.security, color: Color(0xFF008069)),
            title: Text('Meta Cloud API Status'),
            subtitle: Text('Connected & Verified'),
            trailing: Icon(Icons.check_circle, color: Colors.green),
          ),
        ],
      ),
    );
  }

  void _openNewChatDialog(BuildContext context) {
    final phoneController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start New Conversation'),
        content: TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(hintText: 'Enter 10-digit mobile number', prefixText: '+91 '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884)),
            onPressed: () {
              final num = phoneController.text.trim();
              if (num.isNotEmpty) {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ChatDetailScreen(name: '+91 $num')),
                );
              }
            },
            child: const Text('Chat', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// 3. WHATSAPP CHAT ROOM DETAIL SCREEN
// =========================================================================
class ChatDetailScreen extends StatefulWidget {
  final String name;
  const ChatDetailScreen({super.key, required this.name});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _msgController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [
    {'text': 'Hello! How can I help you today?', 'isMe': false, 'time': '10:40 AM'},
  ];

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add({'text': text, 'isMe': true, 'time': 'Now'});
    });
    _msgController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFE7DE), // Classic WhatsApp Chat Wallpaper tone
      appBar: AppBar(
        backgroundColor: const Color(0xFF008069),
        leadingWidth: 70,
        leading: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            const CircleAvatar(radius: 16, backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white, size: 20)),
          ],
        ),
        title: Text(widget.name, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.call, color: Colors.white), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                final bool isMe = m['isMe'] as bool;
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFFE7FFDB) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(m['text'] as String, style: const TextStyle(fontSize: 15)),
                        const SizedBox(height: 3),
                        Text(m['time'] as String, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
                    child: Row(
                      children: [
                        const Icon(Icons.emoji_emotions_outlined, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _msgController,
                            decoration: const InputDecoration(hintText: 'Message', border: InputBorder.none),
                          ),
                        ),
                        const Icon(Icons.attach_file, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                CircleAvatar(
                  backgroundColor: const Color(0xFF00A884),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
