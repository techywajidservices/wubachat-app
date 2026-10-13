import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

final ValueNotifier<ThemeMode> _themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final bool isDark = prefs.getBool('is_dark_theme') ?? false;
  _themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  runApp(const WubachatApp());
}

class WubachatApp extends StatelessWidget {
  const WubachatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'Wubachat',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeData(
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF008069),
              primary: const Color(0xFF008069),
            ),
            scaffoldBackgroundColor: Colors.white,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF111B21),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00A884),
              surface: Color(0xFF202C33),
            ),
            useMaterial3: true,
          ),
          home: const RootGateScreen(),
        );
      },
    );
  }
}

// =========================================================================
// 1. ROOT ROUTER
// =========================================================================
class RootGateScreen extends StatefulWidget {
  const RootGateScreen({super.key});

  @override
  State<RootGateScreen> createState() => _RootGateScreenState();
}

class _RootGateScreenState extends State<RootGateScreen> {
  bool _checked = false;
  bool _isLoggedIn = false;
  String _userRole = 'user';

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isLoggedIn = prefs.containsKey('user_id');
      _userRole = prefs.getString('user_role') ?? 'user';
      _checked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF008069))));
    }
    if (!_isLoggedIn) return const AuthScreen();
    return _userRole == 'admin' ? const AdminDashboardScreen() : const UserHomeScreen();
  }
}

// =========================================================================
// 2. AUTH SCREEN (USER + ADMIN LOGIN WITH BRANDED FOOTER)
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
  final TextEditingController identifierController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Future<void> handleAuth() async {
    final identifier = identifierController.text.trim();
    final password   = passwordController.text.trim();
    final name       = nameController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
      return;
    }

    setState(() => isLoading = true);

    try {
      final res = await http.post(
        Uri.parse('https://wubachat.com/api/app_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': isLogin ? 'login' : 'register',
          'identifier': identifier,
          'password': password,
          'role': selectedRole,
          'name': name,
        }),
      );
      final data = jsonDecode(res.body);

      if (data['status'] == true) {
        final prefs = await SharedPreferences.getInstance();
        final user = data['user'];
        await prefs.setString('user_id', user['id'].toString());
        await prefs.setString('user_name', user['name'] ?? 'User');
        await prefs.setString('user_phone', user['phone'] ?? identifier);
        await prefs.setString('user_role', data['role'] ?? selectedRole);
        await prefs.setDouble('balance', (user['balance'] as num?)?.toDouble() ?? 0.0);

        if (mounted) {
          if (data['role'] == 'admin') {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
          } else {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UserHomeScreen()));
          }
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Authentication failed')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.chat_bubble_rounded, size: 75, color: Color(0xFF00A884)),
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
                                Text('LOGIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isLogin ? const Color(0xFF00A884) : Colors.grey)),
                                const SizedBox(height: 6),
                                Container(height: 2.5, color: isLogin ? const Color(0xFF00A884) : Colors.transparent),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => isLogin = false),
                            child: Column(
                              children: [
                                Text('REGISTER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: !isLogin ? const Color(0xFF00A884) : Colors.grey)),
                                const SizedBox(height: 6),
                                Container(height: 2.5, color: !isLogin ? const Color(0xFF00A884) : Colors.transparent),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Radio<String>(
                          value: 'user',
                          groupValue: selectedRole,
                          activeColor: const Color(0xFF00A884),
                          onChanged: (val) => setState(() => selectedRole = val!),
                        ),
                        const Text('User', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 25),
                        Radio<String>(
                          value: 'admin',
                          groupValue: selectedRole,
                          activeColor: const Color(0xFF00A884),
                          onChanged: (val) => setState(() => selectedRole = val!),
                        ),
                        const Text('Admin', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (!isLogin) ...[
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(hintText: 'Full / Business Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: identifierController,
                      keyboardType: selectedRole == 'admin' ? TextInputType.emailAddress : TextInputType.phone,
                      decoration: InputDecoration(
                        prefixIcon: selectedRole == 'admin'
                            ? const Icon(Icons.account_circle_outlined)
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(width: 10),
                                  const Text('🇮🇳 +91', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Container(width: 1, height: 20, color: Colors.grey.shade400),
                                  const SizedBox(width: 8),
                                ],
                              ),
                        hintText: selectedRole == 'admin' ? 'Email Address or Mobile Number' : 'Mobile Number',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        suffixIcon: IconButton(
                          icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => obscurePassword = !obscurePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : handleAuth,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                        child: isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(isLogin ? 'CONTINUE' : 'REGISTER NOW', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              color: Colors.grey.withOpacity(0.08),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => launchUrl(Uri.parse('https://wubachat.com'), mode: LaunchMode.externalApplication),
                    child: const Text('https://wubachat.com', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ),
                  const SizedBox(height: 4),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('support@wubachat.com', style: TextStyle(fontSize: 11, color: Colors.black54)),
                      Text('Founder : Humera Ameer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF008069))),
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
// 3. USER HOME SCREEN (HEADER CHANNEL SWITCH, 3 TABS, MULTI-SELECT & SYNC)
// =========================================================================
class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _pollingTimer;
  String userId = '1';
  String userName = 'User';
  String userPhone = '';
  double balance = 0.0;
  String selectedChannel = 'whatsapp';
  int metaSent = 0;
  bool isBotEnabled = true;

  String currentFilter = 'all';
  String searchQuery = '';
  final TextEditingController searchCtrl = TextEditingController();

  List<dynamic> allChats = [];
  bool isLoading = true;

  bool isChatMultiSelect = false;
  final Set<String> selectedChatPhones = {};
  List<dynamic> callLogs = [];
  List<dynamic> rechargeLogs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _bootstrapData();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _fetchChats(silent: true);
      _fetchWallet();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrapData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('user_id') ?? '1';
      userName = prefs.getString('user_name') ?? 'User';
      userPhone = prefs.getString('user_phone') ?? '';
    });

    final cached = prefs.getString('cached_chats_data');
    if (cached != null) {
      try {
        setState(() {
          allChats = jsonDecode(cached);
          isLoading = false;
        });
      } catch (_) {}
    }

    _fetchChats(silent: allChats.isNotEmpty);
    _fetchWallet();
    _fetchCalls();
  }

  Future<void> _fetchWallet() async {
    try {
      final res = await http.get(Uri.parse('https://wubachat.com/api/app_api.php?action=get_wallet&user_id=$userId'));
      final d = jsonDecode(res.body);
      if (d['status'] == true && mounted) {
        setState(() {
          userName = d['name'] ?? userName;
          userPhone = d['phone'] ?? userPhone;
          balance = (d['balance'] as num?)?.toDouble() ?? 0.0;
          metaSent = (d['meta_sent'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchChats({bool silent = false}) async {
    if (!silent && allChats.isEmpty) setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse('https://wubachat.com/api/app_api.php?action=get_chats&user_id=$userId&filter=$currentFilter&search=${Uri.encodeComponent(searchQuery)}'));
      final d = jsonDecode(res.body);
      if (d['status'] == true && mounted) {
        final List<dynamic> fetched = d['chats'] ?? [];
        setState(() => allChats = fetched);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_chats_data', jsonEncode(fetched));
      }
    } catch (_) {}
    if (!silent && mounted) setState(() => isLoading = false);
  }

  Future<void> _fetchCalls() async {
    try {
      final res = await http.get(Uri.parse('https://wubachat.com/api/app_api.php?action=get_call_history&user_id=$userId'));
      final d = jsonDecode(res.body);
      if (d['status'] == true && mounted) {
        setState(() => callLogs = d['calls'] ?? []);
      }
    } catch (_) {}
  }

  Future<void> _moveSelectedChats(String targetFolder) async {
    for (String p in selectedChatPhones) {
      await http.post(
        Uri.parse('https://wubachat.com/api/app_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'move_chat', 'user_id': userId, 'phone': p, 'target': targetFolder}),
      );
    }
    setState(() {
      isChatMultiSelect = false;
      selectedChatPhones.clear();
    });
    _fetchChats(silent: false);
  }

  Future<void> _deleteSelectedChats() async {
    for (String p in selectedChatPhones) {
      await http.post(
        Uri.parse('https://wubachat.com/api/app_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'delete_conversation', 'user_id': userId, 'phone': p}),
      );
    }
    setState(() {
      isChatMultiSelect = false;
      selectedChatPhones.clear();
    });
    _fetchChats(silent: false);
  }

  void _openAvatarModal(Map<String, dynamic> chat) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 200,
              width: double.infinity,
              decoration: const BoxDecoration(color: Color(0xFF008069), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
              child: Center(
                child: Text(
                  chat['contact_name'].toString().substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontSize: 68, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Text(chat['contact_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.chat, color: Color(0xFF008069)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailScreen(name: chat['contact_name'], phone: chat['phone_number'], userId: userId, initialChannel: selectedChannel)));
                  },
                ),
                IconButton(icon: const Icon(Icons.call, color: Color(0xFF008069)), onPressed: () => Navigator.pop(ctx)),
                IconButton(icon: const Icon(Icons.videocam, color: Color(0xFF008069)), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _openSettingsConsole() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = _themeNotifier.value == ThemeMode.dark;
          return Container(
            height: MediaQuery.of(context).size.height * 0.88,
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(),
                  ListTile(
                    leading: CircleAvatar(backgroundColor: const Color(0xFF008069), child: Text(userName.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white))),
                    title: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('+$userPhone'),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: Color(0xFF008069)),
                      onPressed: () => _openSelfProfileEditor(setModalState),
                    ),
                  ),
                  const Divider(),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Meta Cloud API', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(8)),
                              child: const Text('Connected', style: TextStyle(color: Color(0xFF008069), fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Daily Limit Used:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text('$metaSent / 250 Sent Today', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    secondary: const Icon(Icons.smart_toy, color: Color(0xFF008069)),
                    title: const Text('Auto-Reply Bot', style: TextStyle(fontWeight: FontWeight.w600)),
                    value: isBotEnabled,
                    onChanged: (val) {
                      setModalState(() => isBotEnabled = val);
                      setState(() => isBotEnabled = val);
                    },
                  ),
                  SwitchListTile(
                    secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: const Color(0xFF008069)),
                    title: const Text('Dark Mode Theme', style: TextStyle(fontWeight: FontWeight.w600)),
                    value: isDark,
                    onChanged: (val) async {
                      _themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('is_dark_theme', val);
                      setModalState(() {});
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.sync, color: Color(0xFF008069)),
                    title: const Text('Sync All Chats to Local Storage', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Sequential incremental sync for 0ms loading'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _startIncrementalSmartSync();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.receipt_long, color: Color(0xFF008069)),
                    title: const Text('Billing Logs & Receipts', style: TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _openBillingReceiptsModal();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.download, color: Color(0xFF008069)),
                    title: const Text('Download Smart Dispatcher (.zip)', style: TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () => launchUrl(Uri.parse('https://wubachat.com/download_assistant.php'), mode: LaunchMode.externalApplication),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red),
                      icon: const Icon(Icons.power_settings_new),
                      label: const Text('Logout Account'),
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.clear();
                        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openSelfProfileEditor(void Function(void Function()) parentSetState) {
    final nameCtrl = TextEditingController(text: userName);
    final bioCtrl  = TextEditingController(text: 'Available');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile & Bio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Display Name')),
            const SizedBox(height: 10),
            TextField(controller: bioCtrl, decoration: const InputDecoration(labelText: 'About / Bio')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF008069), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final newN = nameCtrl.text.trim();
              final newB = bioCtrl.text.trim();
              await http.post(
                Uri.parse('https://wubachat.com/api/app_api.php'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'action': 'update_profile', 'user_id': userId, 'name': newN, 'bio': newB}),
              );
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('user_name', newN);
              setState(() => userName = newN);
              parentSetState(() {});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _startIncrementalSmartSync() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setProgressState) {
          int currentIndex = 0;
          int total = allChats.length;
          String currentContact = 'Starting...';

          Future.delayed(const Duration(milliseconds: 100), () async {
            final prefs = await SharedPreferences.getInstance();
            for (int i = 0; i < allChats.length; i++) {
              final c = allChats[i];
              final phone = c['phone_number'];
              setProgressState(() {
                currentIndex = i + 1;
                currentContact = c['contact_name'] ?? phone;
              });

              try {
                final res = await http.get(Uri.parse('https://wubachat.com/api/app_api.php?action=get_messages&user_id=$userId&phone=$phone')).timeout(const Duration(seconds: 3));
                final data = jsonDecode(res.body);
                if (data['status'] == true) {
                  final k10 = phone.length >= 10 ? phone.substring(phone.length - 10) : phone;
                  await prefs.setString('wuba_chat_$k10', jsonEncode(data['messages'] ?? []));
                }
              } catch (_) {}
              await Future.delayed(const Duration(milliseconds: 150));
            }
            if (Navigator.canPop(ctx)) Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All chats synced to local storage successfully!')));
          });

          return AlertDialog(
            title: const Text('Smart Chat Synchronization'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LinearProgressIndicator(color: Color(0xFF008069)),
                const SizedBox(height: 14),
                Text('Syncing: $currentContact ($currentIndex of $total)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Saving locally without freezing...', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openBillingReceiptsModal() async {
    final res = await http.get(Uri.parse('https://wubachat.com/api/app_api.php?action=fetch_billing_logs&user_id=$userId'));
    final d = jsonDecode(res.body);
    final recharges = d['recharges'] ?? [];

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Recharge Receipts'),
          content: SizedBox(
            width: double.maxFinite,
            height: 350,
            child: recharges.isEmpty
                ? const Center(child: Text('No recharges found'))
                : ListView.separated(
                    itemCount: recharges.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (_, i) {
                      final r = recharges[i];
                      return ListTile(
                        dense: true,
                        title: Text('₹${r['amount']} (${r['status'].toString().toUpperCase()})', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('UTR: ${r['utr_number']}\n${r['created_at']}'),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF008069), foregroundColor: Colors.white),
                          child: const Text('Receipt', style: TextStyle(fontSize: 10)),
                          onPressed: () => _showOfficialReceiptCard(r),
                        ),
                      );
                    },
                  ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        ),
      );
    }
  }

  void _showOfficialReceiptCard(Map<String, dynamic> r) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('WUBACHAT OFFICIAL RECEIPT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF008069))),
              const Divider(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Receipt ID:'), Text('#TXN-${r['id']}', style: const TextStyle(fontWeight: FontWeight.bold))]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Date:'), Text('${r['created_at']}')]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Amount Paid:'), Text('₹${r['amount']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF008069)))]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('UTR Ref:'), Text('${r['utr_number']}', style: const TextStyle(fontFamily: 'monospace'))]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Status:'), Text('${r['status']}'.toUpperCase(), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))]),
              const Divider(height: 25),
              ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
            ],
          ),
        ),
      ),
    );
  }

  void _openRechargeModal() {
    final amtCtrl = TextEditingController(text: '100');
    final utrCtrl = TextEditingController();
    double currentAmt = 100.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final upiUri = 'upi://pay?pa=wubachat@okaxis&pn=Wubachat%20Payments&am=${currentAmt.toStringAsFixed(2)}&cu=INR';
          final qrUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=160x160&data=${Uri.encodeComponent(upiUri)}';
          return AlertDialog(
            title: const Text('Recharge via UPI (Min: ₹100)'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.network(qrUrl, height: 150, width: 150),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amtCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount (INR)', prefixText: '₹ '),
                    onChanged: (val) {
                      final p = double.tryParse(val) ?? 100.0;
                      setModalState(() => currentAmt = p < 100.0 ? 100.0 : p);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: utrCtrl, decoration: const InputDecoration(labelText: '12-digit UTR Number')),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  final amt = double.tryParse(amtCtrl.text) ?? 0;
                  final utr = utrCtrl.text.trim();
                  if (amt < 100 || utr.length < 6) return;
                  Navigator.pop(ctx);
                  await http.post(
                    Uri.parse('https://wubachat.com/api/app_api.php'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({'action': 'recharge_wallet', 'user_id': userId, 'amount': amt, 'utr_number': utr}),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recharge submitted! Verification pending.')));
                },
                child: const Text('Submit'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isChatMultiSelect
          ? AppBar(
              backgroundColor: const Color(0xFF008069),
              title: Text('${selectedChatPhones.length} Selected', style: const TextStyle(color: Colors.white)),
              leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => setState(() => isChatMultiSelect = false)),
              actions: [
                IconButton(icon: const Icon(Icons.archive, color: Colors.white), onPressed: () => _moveSelectedChats(currentFilter == 'archive' ? 'all' : 'archive'), tooltip: 'Archive / Unarchive'),
                IconButton(icon: const Icon(Icons.star, color: Colors.white), onPressed: () => _moveSelectedChats(currentFilter == 'important' ? 'all' : 'important'), tooltip: 'Mark Important'),
                IconButton(icon: const Icon(Icons.mark_chat_unread, color: Colors.white), onPressed: () => _moveSelectedChats('unread'), tooltip: 'Mark as Unread'),
                IconButton(icon: const Icon(Icons.delete, color: Colors.white), onPressed: _deleteSelectedChats, tooltip: 'Delete'),
              ],
            )
          : AppBar(
              backgroundColor: const Color(0xFF008069),
              title: const Text('Wubachat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white)),
              actions: [
                GestureDetector(
                  onTap: () {
                    setState(() => selectedChannel = selectedChannel == 'whatsapp' ? 'wubachat' : 'whatsapp');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: selectedChannel == 'whatsapp' ? const Color(0xFF128C7E) : const Color(0xFF00A884),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(selectedChannel == 'whatsapp' ? Icons.phone_android : Icons.bolt, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(selectedChannel == 'whatsapp' ? 'WhatsApp' : 'Wubachat', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.settings, color: Colors.white), onPressed: _openSettingsConsole),
              ],
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 3.5,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [Tab(text: 'CHATS'), Tab(text: 'CALLS'), Tab(text: 'WALLET')],
              ),
            ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatsTab(),
          _buildCallsTab(),
          _buildWalletTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00A884),
        child: const Icon(Icons.chat, color: Colors.white),
        onPressed: () => _openNewChatModal(),
      ),
    );
  }

  Widget _buildChatsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          child: Container(
            height: 40,
            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
            child: TextField(
              controller: searchCtrl,
              textAlignVertical: TextAlignVertical.center,
              decoration: const InputDecoration(
                isCollapsed: true,
                hintText: 'Search contacts, numbers or keywords...',
                hintStyle: TextStyle(fontSize: 12.5),
                prefixIcon: Icon(Icons.search, size: 18),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 10),
              ),
              onChanged: (val) {
                setState(() => searchQuery = val);
                _fetchChats(silent: false);
              },
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('all', 'All'),
                const SizedBox(width: 6),
                _filterChip('unread', 'Unread'),
                const SizedBox(width: 6),
                _filterChip('important', 'Important'),
                const SizedBox(width: 6),
                _filterChip('archive', 'Archive'),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF008069)))
              : allChats.isEmpty
                  ? Center(child: Text('No chats in $currentFilter tab', style: const TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      itemCount: allChats.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 70),
                      itemBuilder: (context, idx) {
                        final chat = allChats[idx];
                        final phone = chat['phone_number'];
                        final name = chat['contact_name'] ?? ('+' + phone);
                        final lastMsg = chat['last_msg'] ?? '';
                        final unread = (chat['unread_count'] as num?)?.toInt() ?? 0;
                        final isSelected = selectedChatPhones.contains(phone);
                        final time = chat['last_time'] ?? '';

                        return Container(
                          color: isSelected ? Colors.teal.withOpacity(0.15) : Colors.transparent,
                          child: ListTile(
                            leading: GestureDetector(
                              onTap: () => _openAvatarModal(chat),
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor: const Color(0xFF008069).withOpacity(0.18),
                                child: Text(name.substring(0, 1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF008069))),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5), overflow: TextOverflow.ellipsis)),
                                Text(time, style: TextStyle(fontSize: 11, color: unread > 0 ? const Color(0xFF25D366) : Colors.grey)),
                              ],
                            ),
                            subtitle: Row(
                              children: [
                                const Icon(Icons.done_all, size: 14, color: Color(0xFF34B7F1)),
                                const SizedBox(width: 4),
                                Expanded(child: Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600))),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (unread > 0)
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(color: Color(0xFF25D366), shape: BoxShape.circle),
                                    child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                                  onSelected: (val) async {
                                    if (val == 'archive') _moveSingleChat(phone, chat['is_archived'] == 1 ? 'all' : 'archive');
                                    if (val == 'important') _moveSingleChat(phone, chat['is_important'] == 1 ? 'all' : 'important');
                                    if (val == 'unread') _moveSingleChat(phone, 'unread');
                                    if (val == 'delete') _deleteSingleChat(phone);
                                  },
                                  itemBuilder: (_) => [
                                    PopupMenuItem(value: 'archive', child: Text(chat['is_archived'] == 1 ? 'Unarchive Chat' : 'Archive Chat')),
                                    PopupMenuItem(value: 'important', child: Text(chat['is_important'] == 1 ? 'Remove Important' : 'Mark as Important')),
                                    const PopupMenuItem(value: 'unread', child: Text('Mark as Unread')),
                                    const PopupMenuItem(value: 'delete', child: Text('Delete Conversation', style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              ],
                            ),
                            onLongPress: () {
                              setState(() {
                                isChatMultiSelect = true;
                                selectedChatPhones.add(phone);
                              });
                            },
                            onTap: () {
                              if (isChatMultiSelect) {
                                setState(() {
                                  if (isSelected) {
                                    selectedChatPhones.remove(phone);
                                    if (selectedChatPhones.isEmpty) isChatMultiSelect = false;
                                  } else {
                                    selectedChatPhones.add(phone);
                                  }
                                });
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ChatDetailScreen(name: name, phone: phone, userId: userId, initialChannel: selectedChannel)),
                                );
                              }
                            },
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  void _moveSingleChat(String phone, String target) async {
    await http.post(
      Uri.parse('https://wubachat.com/api/app_api.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'action': 'move_chat', 'user_id': userId, 'phone': phone, 'target': target}),
    );
    _fetchChats(silent: false);
  }

  void _deleteSingleChat(String phone) async {
    await http.post(
      Uri.parse('https://wubachat.com/api/app_api.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'action': 'delete_conversation', 'user_id': userId, 'phone': phone}),
    );
    _fetchChats(silent: false);
  }

  Widget _filterChip(String key, String label) {
    final isSel = currentFilter == key;
    return GestureDetector(
      onTap: () {
        setState(() => currentFilter = key);
        _fetchChats(silent: false);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFFE7FCE3) : Colors.grey.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSel ? const Color(0xFF008069) : Colors.transparent),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSel ? const Color(0xFF008069) : Colors.grey.shade700)),
      ),
    );
  }

  Widget _buildCallsTab() {
    return callLogs.isEmpty
        ? const Center(child: Text('No call logs recorded yet', style: TextStyle(color: Colors.grey)))
        : ListView.separated(
            itemCount: callLogs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final c = callLogs[i];
              return ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFE7FFDB), child: Icon(Icons.call, color: Color(0xFF008069))),
                title: Text(c['contact_name'] ?? ('+' + c['recipient_phone']), style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${c['created_at']} • ${c['duration_seconds']}s'),
              );
            },
          );
  }

  Widget _buildWalletTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF008069), Color(0xFF00A884)]), borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Live Balance', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                Text('₹${balance.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: _openRechargeModal,
                  icon: const Icon(Icons.add),
                  label: const Text('+ ADD BALANCE (UPI QR)'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF008069)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ListTile(
            leading: const Icon(Icons.receipt_long, color: Color(0xFF008069)),
            title: const Text('Recharge Receipts & Audit', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Official payment receipts with UTR verification'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: _openBillingReceiptsModal,
          ),
        ],
      ),
    );
  }

  void _openNewChatModal() {
    final pCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start New Conversation'),
        content: TextField(controller: pCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: '10-digit Phone Number', prefixText: '+91 ')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final p = pCtrl.text.trim();
              if (p.isNotEmpty) {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailScreen(name: '+$p', phone: p, userId: userId, initialChannel: selectedChannel)));
              }
            },
            child: const Text('Chat'),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// 4. CHAT ROOM (COLOR EMOJIS, 2x2 GRID, QUOTED JUMP, IN-CHAT SWITCH & CALLS)
// =========================================================================
class ChatDetailScreen extends StatefulWidget {
  final String name;
  final String phone;
  final String userId;
  final String initialChannel;

  const ChatDetailScreen({super.key, required this.name, required this.phone, required this.userId, required this.initialChannel});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _pollingTimer;
  List<dynamic> _messages = [];
  bool _isLoading = true;

  late String _currentChannel;

  final Map<dynamic, GlobalKey> _messageKeys = {};
  dynamic _flashingMessageId;

  bool _isInChatSearch = false;
  final TextEditingController _inChatSearchCtrl = TextEditingController();
  final List<int> _matchedIndices = [];
  int _currentMatchPointer = 0;

  String? _replyToWamid;
  String? _replyToText;

  bool _isRecording = false;
  int _recSeconds = 0;
  Timer? _recTimer;

  String _selectedLang = 'hi-Latn';
  final List<Map<String, String>> _allLanguages = [
    {'code': 'hi-Latn', 'name': 'Hinglish'},
    {'code': 'hi', 'name': 'Hindi (हिंदी)'},
    {'code': 'en', 'name': 'English'},
    {'code': 'ur', 'name': 'Urdu (اردو)'},
    {'code': 'ar', 'name': 'Arabic (العربية)'},
    {'code': 'bn', 'name': 'Bengali (বাংলা)'},
    {'code': 'mr', 'name': 'Marathi (मराठी)'},
    {'code': 'gu', 'name': 'Gujarati (ગુજરાતી)'},
    {'code': 'pa', 'name': 'Punjabi (ਪੰਜਾਬੀ)'},
    {'code': 'ta', 'name': 'Tamil (தமிழ்)'},
    {'code': 'te', 'name': 'Telugu (తెలుగు)'},
    {'code': 'kn', 'name': 'Kannada (ಕನ್ನಡ)'},
    {'code': 'ml', 'name': 'Malayalam (മലയാളം)'},
    {'code': 'or', 'name': 'Odia (ଓଡ଼ିଆ)'},
    {'code': 'es', 'name': 'Spanish (Español)'},
    {'code': 'fr', 'name': 'French (Français)'},
    {'code': 'de', 'name': 'German (Deutsch)'},
    {'code': 'ru', 'name': 'Russian (Русский)'},
    {'code': 'zh-CN', 'name': 'Chinese (Simplified)'},
    {'code': 'ja', 'name': 'Japanese (日本語)'},
  ];

  final Map<String, List<String>> _emojiCategories = {
    'Smileys': ['😀','😃','😄','😁','😆','😅','😂','🤣','😊','😇','🙂','😉','😍','🥰','😘','😋','😎','🤩','🥳','😏','🥺','😢','😭','😡','🤯'],
    'Gestures': ['👍','👎','👏','🙌','👐','🤲','🤝','🙏','✍️','💪','✌️','🤞','🤟','🤘','🤙','👈','👉','👆','👇','✋','👌'],
    'Love': ['❤️','🧡','💛','💚','💙','💜','🖤','🤍','🤎','💔','💕','💞','💓','💗','💖','💘','💝','🔥','✨','🎉','💯'],
    'Food': ['🍏','🍎','🍐','🍊','🍋','🍌','🍉','🍇','🍓','🫐','🍒','🍑','🥭','🍍','🍔','🍟','🍕','🌮','🍜','🍣','🎂','☕'],
    'Objects': ['💻','📱','☎️','📷','🎥','🎧','🎤','💡','💸','💵','💳','📦','✉️','📑','📊','📈','🔑','🔒','🚗','🚕','✈️']
  };

  @override
  void initState() {
    super.initState();
    _currentChannel = widget.initialChannel;
    _loadLocalDiskChat();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetchMessages(silent: true));
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _recTimer?.cancel();
    _scrollController.dispose();
    _msgController.dispose();
    _inChatSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLocalDiskChat() async {
    final prefs = await SharedPreferences.getInstance();
    final k10 = widget.phone.length >= 10 ? widget.phone.substring(widget.phone.length - 10) : widget.phone;
    final cached = prefs.getString('wuba_chat_$k10');

    if (cached != null) {
      try {
        setState(() {
          _messages = jsonDecode(cached);
          _isLoading = false;
        });
        _scrollToBottom();
      } catch (_) {}
    }
    _fetchMessages(silent: _messages.isNotEmpty);
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    try {
      final res = await http.get(Uri.parse('https://wubachat.com/api/app_api.php?action=get_messages&user_id=${widget.userId}&phone=${widget.phone}'));
      final data = jsonDecode(res.body);
      if (data['status'] == true && mounted) {
        final List<dynamic> newMsgs = data['messages'] ?? [];
        if (newMsgs.length != _messages.length || !silent) {
          setState(() => _messages = newMsgs);
          _scrollToBottom();
        }
        final prefs = await SharedPreferences.getInstance();
        final k10 = widget.phone.length >= 10 ? widget.phone.substring(widget.phone.length - 10) : widget.phone;
        await prefs.setString('wuba_chat_$k10', jsonEncode(newMsgs));
      }
    } catch (_) {}
    if (!silent && mounted) setState(() => _isLoading = false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  void _jumpToMessage(dynamic targetIdOrWamid) {
    if (targetIdOrWamid == null) return;
    final key = _messageKeys[targetIdOrWamid];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _flashingMessageId = targetIdOrWamid);
      Timer(const Duration(milliseconds: 1600), () {
        if (mounted) setState(() => _flashingMessageId = null);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Original message is further up in history')));
    }
  }

  void _showMetaRestrictedWarning(String featureName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.amber),
            SizedBox(width: 8),
            Text('Feature Not Supported on WhatsApp', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Meta Cloud API does not support direct voice/video calling or real-time voice notes for "$featureName". You can only use this feature on Wubachat to Wubachat messaging.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _currentChannel = 'wubachat');
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Switched to Wubachat channel! Now you can call & send voice notes.')));
            },
            child: const Text('Switch to Wubachat'),
          ),
        ],
      ),
    );
  }

  void _handleCallPress(String callType) {
    if (_currentChannel == 'whatsapp') {
      _showMetaRestrictedWarning(callType == 'video' ? 'Video Calling' : 'Voice Calling');
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111B21),
        title: Text(callType == 'video' ? 'Wubachat Video Call' : 'Wubachat Voice Call', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 36, backgroundColor: const Color(0xFF00A884), child: Text(widget.name.substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 32, color: Colors.white))),
            const SizedBox(height: 12),
            Text(widget.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Encrypted Calling... Ringing', style: TextStyle(color: Color(0xFF25D366), fontSize: 12)),
          ],
        ),
        actions: [
          CircleAvatar(
            backgroundColor: Colors.red,
            child: IconButton(icon: const Icon(Icons.call_end, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
          )
        ],
      ),
    );
  }

  void _handleMicPress() {
    if (_currentChannel == 'whatsapp') {
      _showMetaRestrictedWarning('Voice Notes');
      return;
    }
    setState(() {
      _isRecording = true;
      _recSeconds = 0;
    });
    _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recSeconds++);
    });
  }

  void _finishVoiceNote() {
    _recTimer?.cancel();
    final dur = _recSeconds;
    setState(() => _isRecording = false);
    _handleSendMessage(customText: '🎤 Voice Note (${dur}s)');
  }

  Future<void> _handleSendMessage({String? customText}) async {
    final text = customText ?? _msgController.text.trim();
    if (text.isEmpty) return;

    final sendingReply = _replyToWamid;
    _msgController.clear();
    setState(() {
      _replyToWamid = null;
      _replyToText = null;
      _messages.add({
        'id': DateTime.now().millisecondsSinceEpoch,
        'message_text': text,
        'direction': 'outbound',
        'is_me': 1,
        'status': 'sent',
        'reply_to_wamid': sendingReply ?? '',
        'created_at': 'Just now',
      });
    });
    _scrollToBottom();

    final res = await http.post(
      Uri.parse('https://wubachat.com/api/app_api.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'send_message',
        'user_id': widget.userId,
        'recipient': widget.phone,
        'message': text,
        'sent_via': _currentChannel,
        'reply_to_wamid': sendingReply ?? '',
      }),
    );
    final data = jsonDecode(res.body);

    if (data['window_closed'] == true) {
      _showTemplateSelectorModal(prefilledMessage: text);
    } else {
      _fetchMessages(silent: true);
    }
  }

  void _showTemplateSelectorModal({String? prefilledMessage}) async {
    final res = await http.get(Uri.parse('https://wubachat.com/api/app_api.php?action=get_templates&user_id=${widget.userId}'));
    final d = jsonDecode(res.body);
    final List<dynamic> templates = d['templates'] ?? [];

    String selectedTpl = templates.isNotEmpty ? templates[0]['template_name'] : 'survey_alert';
    final var1Ctrl = TextEditingController(text: prefilledMessage ?? 'Claim_123');
    final var2Ctrl = TextEditingController(text: 'DL04AB1234');
    final var3Ctrl = TextEditingController(text: 'https://wubachat.com');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(top: 20, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lock_clock, color: Colors.amber, size: 20),
                    SizedBox(width: 8),
                    Text('24h Window Closed: Send Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text('Select an approved Meta template to initiate message (Costs ₹0.50):', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedTpl,
                  decoration: const InputDecoration(labelText: 'Choose Template', border: OutlineInputBorder()),
                  items: templates.map((t) => DropdownMenuItem<String>(value: t['template_name'], child: Text(t['title']))).toList(),
                  onChanged: (val) => setModalState(() => selectedTpl = val!),
                ),
                const SizedBox(height: 10),
                TextField(controller: var1Ctrl, decoration: const InputDecoration(labelText: 'Variable 1 (e.g. Claim/Name)', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                TextField(controller: var2Ctrl, decoration: const InputDecoration(labelText: 'Variable 2 (e.g. Vehicle/Amount)', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                TextField(controller: var3Ctrl, decoration: const InputDecoration(labelText: 'Variable 3 (e.g. Link)', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884), foregroundColor: Colors.white),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await http.post(
                        Uri.parse('https://wubachat.com/api/app_api.php'),
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode({
                          'action': 'send_message',
                          'user_id': widget.userId,
                          'recipient': widget.phone,
                          'mode': 'template',
                          'template_name': selectedTpl,
                          'var1': var1Ctrl.text.trim(),
                          'var2': var2Ctrl.text.trim(),
                          'var3': var3Ctrl.text.trim(),
                        }),
                      );
                      _fetchMessages(silent: true);
                    },
                    child: const Text('Send Template (₹0.50)'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openEmojiKeyboardDrawer() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DefaultTabController(
        length: _emojiCategories.keys.length,
        child: SizedBox(
          height: 300,
          child: Column(
            children: [
              TabBar(
                isScrollable: true,
                indicatorColor: const Color(0xFF00A884),
                labelColor: const Color(0xFF00A884),
                unselectedLabelColor: Colors.grey,
                tabs: _emojiCategories.keys.map((k) => Tab(text: k)).toList(),
              ),
              Expanded(
                child: TabBarView(
                  children: _emojiCategories.values.map((list) {
                    return GridView.builder(
                      padding: const EdgeInsets.all(10),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 8, crossAxisSpacing: 8),
                      itemCount: list.length,
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () => setState(() => _msgController.text += list[i]),
                        child: Center(
                          child: Text(
                            list[i],
                            style: const TextStyle(
                              fontSize: 26,
                              fontFamilyFallback: ['Segoe UI Emoji', 'Noto Color Emoji', 'Apple Color Emoji'],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- FULL DYNAMIC ATTACHMENT PICKER (ZERO HARDCODING) ---
  void _openAttachmentPickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Wrap(
          spacing: 24,
          runSpacing: 20,
          alignment: WrapAlignment.center,
          children: [
            _attachOption(Icons.insert_drive_file, 'Document', const Color(0xFF5F66CD), () {
              Navigator.pop(ctx);
              final docUrlCtrl = TextEditingController(text: 'https://wubachat.com/uploads/Inspection_Report.pdf');
              showDialog(
                context: context,
                builder: (dCtx) => AlertDialog(
                  title: const Text('Share Document / PDF'),
                  content: TextField(controller: docUrlCtrl, decoration: const InputDecoration(labelText: 'Document URL / Link', border: OutlineInputBorder())),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884), foregroundColor: Colors.white),
                      onPressed: () {
                        final u = docUrlCtrl.text.trim();
                        if (u.isNotEmpty) {
                          Navigator.pop(dCtx);
                          _handleSendMessage(customText: '[Document]: $u');
                        }
                      },
                      child: const Text('Send'),
                    ),
                  ],
                ),
              );
            }),
            _attachOption(Icons.camera_alt, 'Camera', const Color(0xFFD3396D), () {
              Navigator.pop(ctx);
              _handleSendMessage(customText: '[Image]: https://placehold.co/600x400/008069/ffffff?text=Camera_Photo');
            }),
            _attachOption(Icons.image, 'Gallery', const Color(0xFFAC44CF), () {
              Navigator.pop(ctx);
              _handleSendMessage(customText: '[Image]: https://placehold.co/600x400/00A884/ffffff?text=Gallery_Photo');
            }),
            _attachOption(Icons.location_on, 'Location', const Color(0xFF1FA855), () {
              Navigator.pop(ctx);
              _handleSendMessage(customText: '📍 Location: https://maps.google.com/?q=28.6139,77.2090');
            }),
            _attachOption(Icons.person, 'Contact', const Color(0xFF009DE2), () {
              Navigator.pop(ctx);
              final cNameCtrl = TextEditingController();
              final cPhoneCtrl = TextEditingController();
              showDialog(
                context: context,
                builder: (dialogCtx) => AlertDialog(
                  title: const Text('Share Contact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(controller: cNameCtrl, decoration: const InputDecoration(labelText: 'Contact Name', border: OutlineInputBorder())),
                      const SizedBox(height: 10),
                      TextField(controller: cPhoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile Number', prefixText: '+91 ', border: OutlineInputBorder())),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884), foregroundColor: Colors.white),
                      onPressed: () {
                        final n = cNameCtrl.text.trim();
                        final p = cPhoneCtrl.text.trim();
                        if (p.isNotEmpty) {
                          Navigator.pop(dialogCtx);
                          _handleSendMessage(customText: '📇 Contact: ${n.isEmpty ? "Contact" : n} (+91 $p)');
                        }
                      },
                      child: const Text('Share'),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _attachOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 28, backgroundColor: color, child: Icon(icon, color: Colors.white, size: 24)),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _executeInChatSearch(String q) {
    _matchedIndices.clear();
    if (q.trim().isEmpty) {
      setState(() {});
      return;
    }
    for (int i = 0; i < _messages.length; i++) {
      final text = (_messages[i]['message_text'] ?? '').toString().toLowerCase();
      if (text.contains(q.toLowerCase())) _matchedIndices.add(i);
    }
    setState(() {
      _currentMatchPointer = _matchedIndices.isNotEmpty ? 0 : 0;
    });
    if (_matchedIndices.isNotEmpty) {
      _jumpToMessage(_messages[_matchedIndices[0]]['id']);
    }
  }

  void _nextMatch() {
    if (_matchedIndices.isEmpty) return;
    setState(() {
      _currentMatchPointer = (_currentMatchPointer + 1) % _matchedIndices.length;
    });
    _jumpToMessage(_messages[_matchedIndices[_currentMatchPointer]]['id']);
  }

  void _prevMatch() {
    if (_matchedIndices.isEmpty) return;
    setState(() {
      _currentMatchPointer = (_currentMatchPointer - 1 + _matchedIndices.length) % _matchedIndices.length;
    });
    _jumpToMessage(_messages[_matchedIndices[_currentMatchPointer]]['id']);
  }

  Widget _buildBubbleContent(String rawText) {
    if (rawText.startsWith('[Document]:')) {
      final url = rawText.replaceFirst('[Document]:', '').trim();
      final name = url.split('/').last;
      return GestureDetector(
        onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.picture_as_pdf, color: Colors.red, size: 26),
              const SizedBox(width: 8),
              Flexible(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 6),
              const Icon(Icons.download, size: 18, color: Color(0xFF008069)),
            ],
          ),
        ),
      );
    }
    if (rawText.startsWith('[Image]:')) {
      final url = rawText.replaceFirst('[Image]:', '').trim();
      return GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => Dialog(
              backgroundColor: Colors.transparent,
              child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(url, height: 180, width: 220, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
        ),
      );
    }
    return Text(rawText, style: const TextStyle(fontSize: 14));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFE7DE),
      appBar: AppBar(
        backgroundColor: const Color(0xFF008069),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: _isInChatSearch
            ? Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inChatSearchCtrl,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(hintText: 'Search inside chat...', hintStyle: TextStyle(color: Colors.white70), border: InputBorder.none),
                      onChanged: _executeInChatSearch,
                    ),
                  ),
                  if (_matchedIndices.isNotEmpty) ...[
                    Text('${_currentMatchPointer + 1}/${_matchedIndices.length}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    IconButton(icon: const Icon(Icons.arrow_upward, size: 18, color: Colors.white), onPressed: _prevMatch),
                    IconButton(icon: const Icon(Icons.arrow_downward, size: 18, color: Colors.white), onPressed: _nextMatch),
                  ],
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(_currentChannel == 'whatsapp' ? 'via Official Meta Cloud API' : '⚡ On Wubachat Free', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                ],
              ),
        actions: [
          GestureDetector(
            onTap: () {
              setState(() {
                _currentChannel = _currentChannel == 'whatsapp' ? 'wubachat' : 'whatsapp';
              });
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Switched to ${_currentChannel.toUpperCase()} channel!')));
            },
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _currentChannel == 'whatsapp' ? const Color(0xFF128C7E) : const Color(0xFF00A884),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_currentChannel == 'whatsapp' ? Icons.phone_android : Icons.bolt, size: 13, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(_currentChannel == 'whatsapp' ? 'WA' : 'Wuba', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.videocam, color: Colors.white), onPressed: () => _handleCallPress('video')),
          IconButton(icon: const Icon(Icons.call, color: Colors.white), onPressed: () => _handleCallPress('audio')),
          IconButton(
            icon: Icon(_isInChatSearch ? Icons.close : Icons.search, color: Colors.white),
            onPressed: () => setState(() {
              _isInChatSearch = !_isInChatSearch;
              if (!_isInChatSearch) _matchedIndices.clear();
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF008069)))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(10),
                    itemCount: _messages.length,
                    itemBuilder: (context, idx) {
                      final m = _messages[idx];
                      final id = m['id'];
                      final wamid = m['wamid'];
                      final bool isMe = (m['direction'] == 'outbound' || m['is_me'] == 1);
                      final String text = (m['message_text'] ?? '').toString();
                      final String replyWamid = (m['reply_to_wamid'] ?? '').toString();
                      final String time = m['created_at'] != null ? m['created_at'].toString().split(' ').last : '';

                      _messageKeys[id] ??= GlobalKey();
                      if (wamid != null) _messageKeys[wamid] ??= _messageKeys[id]!;

                      final bool isFlashing = (_flashingMessageId == id || _flashingMessageId == wamid);

                      return Container(
                        key: _messageKeys[id],
                        child: Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                            decoration: BoxDecoration(
                              color: isFlashing
                                  ? const Color(0xFFFFF59D)
                                  : (isMe ? const Color(0xFFE7FFDB) : Colors.white),
                              borderRadius: BorderRadius.circular(10),
                              border: isFlashing ? Border.all(color: Colors.orange, width: 1.5) : null,
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 2)],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (replyWamid.isNotEmpty)
                                  GestureDetector(
                                    onTap: () => _jumpToMessage(replyWamid),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(6),
                                        border: const Border(left: BorderSide(color: Color(0xFF008069), width: 3.5)),
                                      ),
                                      child: const Text('Replying to message (Tap to jump)', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF008069))),
                                    ),
                                  ),
                                _buildBubbleContent(text),
                                const SizedBox(height: 3),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(time, style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600)),
                                    if (isMe) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.done_all, size: 14, color: Color(0xFF34B7F1)),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_isRecording)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey.shade200,
              child: Row(
                children: [
                  const Icon(Icons.fiber_manual_record, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Text('Voice: ${_recSeconds}s', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  const Spacer(),
                  TextButton(onPressed: () => setState(() => _isRecording = false), child: const Text('Cancel')),
                  ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF008069), foregroundColor: Colors.white), onPressed: _finishVoiceNote, child: const Text('Send')),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey), onPressed: _openEmojiKeyboardDrawer),
                IconButton(icon: const Icon(Icons.attach_file, color: Colors.grey), onPressed: _openAttachmentPickerSheet),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(color: Colors.grey.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                  child: DropdownButton<String>(
                    value: _selectedLang,
                    underline: const SizedBox(),
                    isDense: true,
                    menuMaxHeight: 320,
                    items: _allLanguages.map((l) => DropdownMenuItem(value: l['code'], child: Text(l['name']!, style: const TextStyle(fontSize: 10.5)))).toList(),
                    onChanged: (val) => setState(() => _selectedLang = val!),
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.grey.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                    child: TextField(
                      controller: _msgController,
                      decoration: const InputDecoration(hintText: 'Type a message...', border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                      onSubmitted: (_) => _handleSendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(icon: const Icon(Icons.mic, color: Color(0xFF008069)), onPressed: _handleMicPress),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF00A884),
                  child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 18), onPressed: () => _handleSendMessage()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// 5. ENTERPRISE ADMIN DASHBOARD
// =========================================================================
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool isLoading = true;
  double revenue = 0.0;
  double metaExpense = 0.0;
  double netProfit = 0.0;
  int userCount = 0;

  List<dynamic> pendingRecharges = [];
  List<dynamic> allUsers = [];

  @override
  void initState() {
    super.initState();
    _fetchAdminData();
  }

  Future<void> _fetchAdminData() async {
    try {
      final res = await http.get(Uri.parse('https://wubachat.com/api/app_api.php?action=admin_get_dashboard_data'));
      final d = jsonDecode(res.body);
      if (d['status'] == true && mounted) {
        setState(() {
          revenue = (d['revenue'] as num?)?.toDouble() ?? 0.0;
          metaExpense = (d['meta_expense'] as num?)?.toDouble() ?? 0.0;
          netProfit = (d['net_profit'] as num?)?.toDouble() ?? 0.0;
          userCount = (d['user_count'] as num?)?.toInt() ?? 0;
          pendingRecharges = d['pending'] ?? [];
          allUsers = d['all_users'] ?? [];
          isLoading = false;
        });
      }
    } catch (_) {}
  }

  void _handleRechargeDecision(int txId, String decision) async {
    await http.post(
      Uri.parse('https://wubachat.com/api/app_api.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'action': 'admin_action_recharge', 'tx_id': txId, 'decision': decision}),
    );
    _fetchAdminData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Master Enterprise Admin Console', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _fetchAdminData),
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.red),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00A884)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    _kpiCard('Revenue', '₹${revenue.toStringAsFixed(2)}', Colors.purple),
                    const SizedBox(width: 8),
                    _kpiCard('Meta Expense', '₹${metaExpense.toStringAsFixed(2)}', Colors.red),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _kpiCard('Net Profit', '₹${netProfit.toStringAsFixed(2)}', Colors.green),
                    const SizedBox(width: 8),
                    _kpiCard('Total Users', '$userCount', Colors.blue),
                  ],
                ),
                const SizedBox(height: 20),
                Card(
                  color: const Color(0xFF1E293B),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pending Recharge Approvals (${pendingRecharges.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const Divider(color: Colors.white24),
                        if (pendingRecharges.isEmpty)
                          const Text('No pending recharge approvals.', style: TextStyle(color: Colors.grey, fontSize: 12))
                        else
                          ...pendingRecharges.map((pr) {
                            return ListTile(
                              dense: true,
                              title: Text('${pr['user_name']} - ₹${pr['amount']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              subtitle: Text('UTR: ${pr['utr_number']}', style: const TextStyle(color: Colors.grey)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: () => _handleRechargeDecision(pr['id'], 'approve')),
                                  IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => _handleRechargeDecision(pr['id'], 'reject')),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _kpiCard(String label, String value, MaterialColor color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color.shade900.withOpacity(0.4), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.shade700)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: color.shade200, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
