import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// Global In-Memory Cache for 0ms Instant Loading & Theme Controller
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
// 2. AUTH SCREEN (USER + ADMIN BY EMAIL/PHONE, BRANDED FOOTER)
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

  String currentFilter = 'all';
  String searchQuery = '';
  final TextEditingController searchCtrl = TextEditingController();

  List<dynamic> allChats = [];
  bool isLoading = true;

  bool isChatMultiSelect = false;
  final Set<String> selectedChatPhones = {};
  List<dynamic> callLogs = [];

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
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailScreen(name: chat['contact_name'], phone: chat['phone_number'], userId: userId, defaultChannel: selectedChannel)));
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
            height: MediaQuery.of(context).size.height * 0.85,
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
                      );
                    },
                  ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        ),
      );
    }
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
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5), overflow: TextOverflow.ellipsis),
                            subtitle: Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                            trailing: unread > 0
                                ? Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(color: Color(0xFF25D366), shape: BoxShape.circle),
                                    child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  )
                                : null,
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
                                  MaterialPageRoute(builder: (_) => ChatDetailScreen(name: name, phone: phone, userId: userId, defaultChannel: selectedChannel)),
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
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF008069), Color(0xFF00A884)]), borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Live Balance', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text('₹${balance.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          ],
        ),
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
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailScreen(name: '+$p', phone: p, userId: userId, defaultChannel: selectedChannel)));
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
// 4. CHAT ROOM (QUOTED JUMP WITH FLASH HIGHLIGHT, EMOJI, ATTACHMENT, TEMPLATES)
// =========================================================================
class ChatDetailScreen extends StatefulWidget {
  final String name;
  final String phone;
  final String userId;
  final String defaultChannel;

  const ChatDetailScreen({super.key, required this.name, required this.phone, required this.userId, required this.defaultChannel});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _pollingTimer;
  List<dynamic> _messages = [];
  bool _isLoading = true;

  final Map<dynamic, GlobalKey> _messageKeys = {};
  dynamic _flashingMessageId;

  bool _isInChatSearch = false;
  final TextEditingController _inChatSearchCtrl = TextEditingController();

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
    {'code': 'as', 'name': 'Assamese (অসমীয়া)'},
    {'code': 'ne', 'name': 'Nepali (नेपाली)'},
    {'code': 'es', 'name': 'Spanish (Español)'},
    {'code': 'fr', 'name': 'French (Français)'},
    {'code': 'de', 'name': 'German (Deutsch)'},
    {'code': 'ru', 'name': 'Russian (Русский)'},
    {'code': 'zh-CN', 'name': 'Chinese (Simplified)'},
    {'code': 'ja', 'name': 'Japanese (日本語)'},
    {'code': 'ko', 'name': 'Korean (한국어)'},
    {'code': 'tr', 'name': 'Turkish (Türkçe)'},
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
        'sent_via': widget.defaultChannel,
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
                        child: Center(child: Text(list[i], style: const TextStyle(fontSize: 24))),
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
              _handleSendMessage(customText: '[Document]: https://wubachat.com/uploads/Inspection_Report.pdf');
            }),
            _attachOption(Icons.camera_alt, 'Camera', const Color(0xFFD3396D), () {
              Navigator.pop(ctx);
              _handleSendMessage(customText: '[Image]: https://placehold.co/600x400/008069/ffffff?text=Vehicle+Inspection+Snap');
            }),
            _attachOption(Icons.image, 'Gallery', const Color(0xFFAC44CF), () {
              Navigator.pop(ctx);
              _handleSendMessage(customText: '[Image]: https://placehold.co/600x400/00A884/ffffff?text=Claim_Damage_Photo');
            }),
            _attachOption(Icons.location_on, 'Location', const Color(0xFF1FA855), () {
              Navigator.pop(ctx);
              _handleSendMessage(customText: '📍 Location: https://maps.google.com/?q=28.6139,77.2090');
            }),
            _attachOption(Icons.person, 'Contact', const Color(0xFF009DE2), () {
              Navigator.pop(ctx);
              _handleSendMessage(customText: '📇 Contact: Er. Wajid Ali (+91 8909034515)');
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

  void _translateInputText() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    try {
      final res = await http.post(
        Uri.parse('https://wubachat.com/api/app_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'translate', 'user_id': widget.userId, 'text': text, 'target': _selectedLang}),
      );
      final d = jsonDecode(res.body);
      if (d['status'] == true && d['translated_text'] != null) {
        _msgController.text = d['translated_text'];
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF008069),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: _isInChatSearch
            ? TextField(
                controller: _inChatSearchCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(hintText: 'Search inside chat...', hintStyle: TextStyle(color: Colors.white70), border: InputBorder.none),
                onChanged: (val) => setState(() {}),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(widget.defaultChannel == 'whatsapp' ? 'via Official Meta Cloud API' : '⚡ On Wubachat Free', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_isInChatSearch ? Icons.close : Icons.search, color: Colors.white),
            onPressed: () => setState(() => _isInChatSearch = !_isInChatSearch),
          ),
          IconButton(icon: const Icon(Icons.assignment, color: Colors.white), onPressed: () => _showTemplateSelectorModal()),
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
                                  ? const Color(0xFFFFF59D) // FLASH HIGHLIGHT
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
                                Text(text, style: const TextStyle(fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_replyToWamid != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              color: Colors.grey.shade200,
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 16, color: Color(0xFF008069)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Replying: ${_replyToText ?? ""}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                  IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(() => _replyToWamid = null)),
                ],
              ),
            ),
          // SPACIOUS NATIVE WHATSAPP INPUT BAR (NEVER CUT OFF)
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
                IconButton(icon: const Icon(Icons.translate, color: Color(0xFF008069), size: 18), onPressed: _translateInputText),
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
// 5. ENTERPRISE ADMIN DASHBOARD (COMPLETE WITH AUDITOR & CONTROLS)
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

  void _inspectUserChats(int targetUid, String targetName) async {
    final res = await http.get(Uri.parse('https://wubachat.com/api/app_api.php?action=admin_inspect_user_chats&target_user_id=$targetUid'));
    final d = jsonDecode(res.body);
    final chats = d['chats'] ?? [];

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Auditing: $targetName'),
          content: SizedBox(
            width: double.maxFinite,
            height: 380,
            child: chats.isEmpty
                ? const Center(child: Text('No messages recorded for this user.'))
                : ListView.builder(
                    itemCount: chats.length,
                    itemBuilder: (_, i) {
                      final c = chats[i];
                      final isOut = c['direction'] == 'outbound';
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: isOut ? Colors.teal.shade50 : Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                        child: Text('${c['message_text']}\n[${c['created_at']}]', style: const TextStyle(fontSize: 12)),
                      );
                    },
                  ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        ),
      );
    }
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
                const SizedBox(height: 16),
                Card(
                  color: const Color(0xFF1E293B),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('User Directory & Live Chat Auditing', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const Divider(color: Colors.white24),
                        ...allUsers.take(20).map((u) {
                          return ListTile(
                            dense: true,
                            title: Text('${u['name']} (+${u['phone']})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            subtitle: Text('Bal: ₹${u['wallet_balance']}', style: const TextStyle(color: Color(0xFF00A884))),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white),
                              child: const Text('Inspect', style: TextStyle(fontSize: 10)),
                              onPressed: () => _inspectUserChats(u['id'], u['name']),
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
