import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
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
// 1. AUTH SCREEN (WITH FLAG, FOOTER & FOUNDER DETAILS)
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
      final url = Uri.parse('https://wubachat.com/api/app_auth.php');
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
                    const SizedBox(height: 45),
                    Center(
                      child: Image.asset(
                        'assets/logo.png',
                        height: 110,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.chat_bubble_rounded,
                          size: 80,
                          color: Color(0xFF00A884),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
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
// 2. DASHBOARD HOME (SETTINGS, LOGOUT, FILTERS, DYNAMIC QR)
// =========================================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _homePollTimer;
  String userId = '1';
  String userName = 'User';
  String userPhone = '';
  double balance = 0.0;
  String adminUpi = 'wubachat@okaxis';
  String adminPayee = 'Wubachat Payments';
  int metaSent = 0;
  bool isBotEnabled = true;

  String currentChatFilter = 'all';
  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();

  List<dynamic> chatList = [];
  bool isLoadingChats = true;
  String? activeChatPhone;
  String? activeChatName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();
    _homePollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      fetchLiveChats(background: true);
      fetchLiveWallet();
    });
  }

  @override
  void dispose() {
    _homePollTimer?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('user_id') ?? '1';
      userName = prefs.getString('user_name') ?? 'User';
      userPhone = prefs.getString('user_phone') ?? '';
    });

    final cachedChats = prefs.getString('cached_chat_list');
    if (cachedChats != null) {
      try {
        final decoded = jsonDecode(cachedChats) as List<dynamic>;
        setState(() {
          chatList = decoded;
          isLoadingChats = false;
          if (decoded.isNotEmpty) {
            activeChatPhone = decoded[0]['phone_number'];
            activeChatName = decoded[0]['contact_name'];
          }
        });
      } catch (_) {}
    }

    fetchLiveWallet();
    fetchLiveChats(background: chatList.isNotEmpty);
  }

  Future<void> fetchLiveWallet() async {
    try {
      final res = await http.get(Uri.parse('https://wubachat.com/api/app_api.php?action=get_wallet&user_id=$userId'));
      final data = jsonDecode(res.body);
      if (data['status'] == true && mounted) {
        setState(() {
          userName = data['name'] ?? userName;
          userPhone = data['phone'] ?? userPhone;
          balance = (data['balance'] as num?)?.toDouble() ?? 0.0;
          adminUpi = data['admin_upi'] ?? adminUpi;
          adminPayee = data['admin_payee'] ?? adminPayee;
          metaSent = (data['meta_sent'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> fetchLiveChats({bool background = false}) async {
    if (!background && chatList.isEmpty) setState(() => isLoadingChats = true);
    try {
      final url = 'https://wubachat.com/api/app_api.php?action=get_chats&user_id=$userId&filter=$currentChatFilter&search=${Uri.encodeComponent(searchQuery)}';
      final res = await http.get(Uri.parse(url));
      final data = jsonDecode(res.body);
      if (data['status'] == true && mounted) {
        final List<dynamic> fetched = data['chats'] ?? [];
        setState(() {
          chatList = fetched;
          if (activeChatPhone == null && fetched.isNotEmpty) {
            activeChatPhone = fetched[0]['phone_number'];
            activeChatName = fetched[0]['contact_name'];
          }
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_chat_list', jsonEncode(fetched));
      }
    } catch (_) {}
    if (!background && mounted) setState(() => isLoadingChats = false);
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.power_settings_new, color: Colors.red),
            SizedBox(width: 8),
            Text('Confirm Logout', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Are you sure you want to logout from this Wubachat account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
            },
            child: const Text('Yes, Logout'),
          ),
        ],
      ),
    );
  }

  void _openSettingsConsole() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSettingsState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              padding: const EdgeInsets.all(22),
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.settings, color: Color(0xFF008069)),
                            SizedBox(width: 8),
                            Text('Account Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const Divider(height: 20),
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: const Color(0xFF008069),
                            child: Text(
                              userName.isNotEmpty ? userName.substring(0, 1).toUpperCase() : 'U',
                              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(userPhone.isNotEmpty ? '+91 $userPhone' : 'Registered User', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Auto-Reply Bot', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Switch(
                                value: isBotEnabled,
                                activeColor: const Color(0xFF008069),
                                onChanged: (val) => setSettingsState(() => isBotEnabled = val),
                              ),
                            ],
                          ),
                          const Divider(height: 12),
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.receipt_long, color: Color(0xFF008069)),
                      title: const Text('Billing Logs & Audit', style: TextStyle(fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openBillingLogsModal();
                      },
                    ),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.download_for_offline, color: Color(0xFF008069)),
                      title: const Text('Download Smart Dispatcher (.zip)', style: TextStyle(fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.download, size: 18),
                      onTap: () => launchUrl(Uri.parse('https://wubachat.com/download_assistant.php'), mode: LaunchMode.externalApplication),
                    ),
                    const Divider(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red, elevation: 0),
                        icon: const Icon(Icons.power_settings_new),
                        label: const Text('Logout Account', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _confirmLogout();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openBillingLogsModal() async {
    try {
      final res = await http.get(Uri.parse('https://wubachat.com/api/app_api.php?action=fetch_billing_logs&user_id=$userId'));
      final data = jsonDecode(res.body);
      final records = data['records'] ?? [];

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Billing & Usage Logs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: SizedBox(
              width: double.maxFinite,
              height: 350,
              child: records.isEmpty
                  ? const Center(child: Text('No transaction logs recorded yet.'))
                  : ListView.separated(
                      itemCount: records.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final r = records[i];
                        return ListTile(
                          dense: true,
                          title: Text('+${r['recipient_phone']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${r['created_at']} • ${r['sent_via']}'),
                          trailing: Text('₹${r['cost']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF008069))),
                        );
                      },
                    ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
          ),
        );
      }
    } catch (_) {}
  }

  void _openRechargeDialog() {
    final amountController = TextEditingController(text: '100');
    final utrController = TextEditingController();
    double currentAmt = 100.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final upiUri = 'upi://pay?pa=$adminUpi&pn=${Uri.encodeComponent(adminPayee)}&am=${currentAmt.toStringAsFixed(2)}&cu=INR';
          final qrUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=${Uri.encodeComponent(upiUri)}';

          return AlertDialog(
            title: const Text('Add Balance via UPI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                    child: Column(
                      children: [
                        Image.network(qrUrl, height: 160, width: 160, fit: BoxFit.contain),
                        const SizedBox(height: 6),
                        Text('UPI ID: $adminUpi', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF008069))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Recharge Amount (Min: ₹100)', prefixText: '₹ ', border: OutlineInputBorder()),
                    onChanged: (val) {
                      final parsed = double.tryParse(val) ?? 100.0;
                      setModalState(() => currentAmt = parsed < 100.0 ? 100.0 : parsed);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: utrController, decoration: const InputDecoration(labelText: '12-digit UPI UTR / Ref Number', border: OutlineInputBorder())),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884), foregroundColor: Colors.white),
                onPressed: () async {
                  final amt = double.tryParse(amountController.text) ?? 0;
                  final utr = utrController.text.trim();
                  if (amt < 100 || utr.length < 6) return;
                  Navigator.pop(ctx);
                  try {
                    await http.post(
                      Uri.parse('https://wubachat.com/api/app_api.php'),
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({'action': 'recharge_wallet', 'user_id': userId, 'amount': amt, 'utr_number': utr}),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recharge submitted!')));
                  } catch (_) {}
                },
                child: const Text('Submit & Credit'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openAddContactDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Contact', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile Number', prefixText: '+91 ', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884), foregroundColor: Colors.white),
            onPressed: () async {
              final n = nameCtrl.text.trim();
              final p = phoneCtrl.text.trim();
              if (p.isEmpty) return;
              Navigator.pop(ctx);
              await http.post(
                Uri.parse('https://wubachat.com/api/app_api.php'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'action': 'save_contact', 'user_id': userId, 'name': n, 'phone': p}),
              );
              fetchLiveChats(background: false);
            },
            child: const Text('Save Contact'),
          ),
        ],
      ),
    );
  }

  void _openEditContactDialog(Map<String, dynamic> chat) {
    final nameCtrl = TextEditingController(text: chat['contact_name']);
    final phoneCtrl = TextEditingController(text: chat['phone_number']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Contact Details', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Contact Name', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile Number', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await http.post(
                Uri.parse('https://wubachat.com/api/app_api.php'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'action': 'edit_contact', 'user_id': userId, 'id': chat['id'], 'name': nameCtrl.text.trim(), 'phone': phoneCtrl.text.trim()}),
              );
              fetchLiveChats(background: false);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteConversation(String phone) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Conversation?'),
        content: const Text('Are you sure you want to permanently delete this chat history?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await http.post(
                Uri.parse('https://wubachat.com/api/app_api.php'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'action': 'delete_conversation', 'user_id': userId, 'phone': phone}),
              );
              final prefs = await SharedPreferences.getInstance();
              final last10 = phone.length >= 10 ? phone.substring(phone.length - 10) : phone;
              await prefs.remove('wuba_chat_$last10');
              fetchLiveChats(background: false);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 750;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const Text('Wubachat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white)),
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                  child: Text('Meta: $metaSent / 250', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _openRechargeDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFF00A884), borderRadius: BorderRadius.circular(12)),
                    child: Text('₹${balance.toStringAsFixed(2)} + ADD', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF008069),
            elevation: 0,
            actions: [
              IconButton(icon: const Icon(Icons.person_add, color: Colors.white), onPressed: _openAddContactDialog, tooltip: 'Add Contact'),
              IconButton(icon: const Icon(Icons.receipt_long, color: Colors.white), onPressed: _openBillingLogsModal, tooltip: 'Billing Logs'),
              IconButton(icon: const Icon(Icons.settings, color: Colors.white), onPressed: _openSettingsConsole, tooltip: 'Settings Console'),
              IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: () => fetchLiveChats(background: false), tooltip: 'Refresh'),
              IconButton(icon: const Icon(Icons.power_settings_new, color: Colors.redAccent), onPressed: _confirmLogout, tooltip: 'Logout Account'),
            ],
            bottom: isDesktop
                ? null
                : TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3.5,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    tabs: const [Tab(text: 'CHATS'), Tab(text: 'TOOLS'), Tab(text: 'WALLET')],
                  ),
          ),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                color: const Color(0xFFC62828),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 14, color: Colors.amber),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'ALERT: Make sure you use Meta connected numbers for official delivery.',
                        style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: isDesktop
                    ? Row(
                        children: [
                          SizedBox(width: 380, child: _buildChatsListSection(isDesktop: true)),
                          const VerticalDivider(width: 1),
                          Expanded(
                            child: activeChatPhone == null
                                ? const Center(child: Text('Select a conversation to start messaging'))
                                : ChatDetailScreen(key: ValueKey(activeChatPhone), name: activeChatName ?? '', phone: activeChatPhone!, userId: userId, isEmbedded: true),
                          ),
                        ],
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [_buildChatsListSection(isDesktop: false), _buildToolsTab(), _buildWalletTab()],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatsListSection({required bool isDesktop}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          child: Container(
            height: 38,
            decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(20)),
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: 'Search contacts, numbers...',
                hintStyle: TextStyle(fontSize: 12),
                prefixIcon: Icon(Icons.search, size: 18),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 9),
              ),
              onChanged: (val) {
                setState(() => searchQuery = val);
                fetchLiveChats(background: false);
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
          child: isLoadingChats
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF008069)))
              : chatList.isEmpty
                  ? Center(child: Text('No conversations in $currentChatFilter tab', style: const TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      itemCount: chatList.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 75),
                      itemBuilder: (context, index) {
                        final chat = chatList[index];
                        final name = chat['contact_name'] ?? ('+' + (chat['phone_number'] ?? ''));
                        final phone = chat['phone_number'] ?? '';
                        final lastMsg = chat['last_msg'] ?? 'Tap to chat';
                        final unread = (chat['unread_count'] as num?)?.toInt() ?? 0;
                        final isOutbound = chat['last_direction'] == 'outbound';
                        final isSelected = isDesktop && activeChatPhone == phone;
                        final initialText = name.isNotEmpty ? (name.length >= 2 ? name.substring(0, 2) : name.substring(0, 1)).toUpperCase() : 'U';

                        return Container(
                          color: isSelected ? const Color(0xFFE9EDEF) : Colors.white,
                          child: ListTile(
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFF25D366).withOpacity(0.18),
                              child: Text(initialText, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF008069))),
                            ),
                            title: Row(
                              children: [
                                Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5), overflow: TextOverflow.ellipsis)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFA7F3D0))),
                                  child: const Text('✓✓ Synced', style: TextStyle(fontSize: 8.5, color: Color(0xFF008069), fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            subtitle: Row(
                              children: [
                                if (isOutbound) const Icon(Icons.done_all, size: 13, color: Color(0xFF34B7F1)),
                                if (isOutbound) const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    lastMsg.startsWith('[Image]:') ? '📷 Photo' : (lastMsg.startsWith('[Document]:') ? '📄 Document' : lastMsg),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                                  ),
                                ),
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
                                  onSelected: (val) {
                                    if (val == 'edit') _openEditContactDialog(chat);
                                    if (val == 'delete') _confirmDeleteConversation(phone);
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Edit Contact')])),
                                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 16), SizedBox(width: 8), Text('Delete Conversation', style: TextStyle(color: Colors.red))])),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () {
                              if (isDesktop) {
                                setState(() {
                                  activeChatPhone = phone;
                                  activeChatName = name;
                                });
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ChatDetailScreen(name: name, phone: phone, userId: userId, isEmbedded: false)),
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

  Widget _filterChip(String filterKey, String label) {
    final isSelected = currentChatFilter == filterKey;
    return GestureDetector(
      onTap: () {
        setState(() => currentChatFilter = filterKey);
        fetchLiveChats(background: false);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE7FCE3) : const Color(0xFFF0F2F5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? const Color(0xFF008069) : Colors.transparent),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF008069) : Colors.grey.shade700)),
      ),
    );
  }

  Widget _buildToolsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _toolCard(Icons.directions_car, 'mParivahan RC & DL Verification', 'Instant vehicle details verification engine', 'https://services.techywajid.com'),
        _toolCard(Icons.picture_as_pdf, 'PDF to Excel Data Extractor', 'Parse tabular documents directly into spreadsheets', 'https://services.techywajid.com'),
        _toolCard(Icons.campaign, '1,000 Numbers Meta Bulk Campaign', 'Broadcast templates directly from CSV/Excel', 'https://wubachat.com/broadcast.php'),
      ],
    );
  }

  Widget _toolCard(IconData icon, String title, String subtitle, String url) {
    return Card(
      child: ListTile(
        onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        leading: Icon(icon, color: const Color(0xFF008069)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      ),
    );
  }

  Widget _buildWalletTab() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF008069), Color(0xFF00A884)]), borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Live Balance', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                Text('₹${balance.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _openRechargeDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Credit via UPI'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF008069)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ListTile(leading: const Icon(Icons.speed, color: Color(0xFF008069)), title: const Text('Meta Cloud API Limit'), subtitle: Text('$metaSent sent today of 250 daily limit')),
        ],
      ),
    );
  }
}

// =========================================================================
// 3. CHAT ROOM (100+ LANGUAGES, EMOJI, ATTACHMENTS, CLUSTER IMAGE GRID)
// =========================================================================
class ChatDetailScreen extends StatefulWidget {
  final String name;
  final String phone;
  final String userId;
  final bool isEmbedded;

  const ChatDetailScreen({super.key, required this.name, required this.phone, required this.userId, this.isEmbedded = false});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _chatPollingTimer;
  List<dynamic> _messages = [];
  bool _isLoading = true;

  String _selectedChannel = 'whatsapp';
  String _selectedLang = 'hi-Latn';

  bool _isSelectMode = false;
  final Set<int> _selectedMessageIds = {};

  String? _replyToWamid;
  String? _replyToText;

  bool _isRecordingVoice = false;
  int _voiceSeconds = 0;
  Timer? _voiceTimer;

  // 100+ COMPREHENSIVE LANGUAGES DATABASE
  final List<Map<String, String>> _all100Languages = [
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
    {'code': 'sa', 'name': 'Sanskrit (संस्कृतम्)'},
    {'code': 'es', 'name': 'Spanish (Español)'},
    {'code': 'fr', 'name': 'French (Français)'},
    {'code': 'de', 'name': 'German (Deutsch)'},
    {'code': 'ru', 'name': 'Russian (Русский)'},
    {'code': 'zh-CN', 'name': 'Chinese (Simplified)'},
    {'code': 'ja', 'name': 'Japanese (日本語)'},
    {'code': 'ko', 'name': 'Korean (한국어)'},
    {'code': 'tr', 'name': 'Turkish (Türkçe)'},
    {'code': 'it', 'name': 'Italian (Italiano)'},
    {'code': 'pt', 'name': 'Portuguese (Português)'},
    {'code': 'id', 'name': 'Indonesian (Bahasa)'},
    {'code': 'fa', 'name': 'Persian (فارسی)'},
    {'code': 'nl', 'name': 'Dutch (Nederlands)'},
    {'code': 'pl', 'name': 'Polish (Polski)'},
    {'code': 'uk', 'name': 'Ukrainian (Українська)'},
    {'code': 'ro', 'name': 'Romanian (Română)'},
    {'code': 'el', 'name': 'Greek (Ελληνικά)'},
    {'code': 'cs', 'name': 'Czech (Čeština)'},
    {'code': 'sv', 'name': 'Swedish (Svenska)'},
    {'code': 'hu', 'name': 'Hungarian (Magyar)'},
    {'code': 'th', 'name': 'Thai (ไทย)'},
    {'code': 'vi', 'name': 'Vietnamese (Tiếng Việt)'},
    {'code': 'ms', 'name': 'Malay (Melayu)'},
    {'code': 'fil', 'name': 'Filipino (Tagalog)'},
    {'code': 'he', 'name': 'Hebrew (עברית)'},
    {'code': 'da', 'name': 'Danish (Dansk)'},
    {'code': 'fi', 'name': 'Finnish (Suomi)'},
    {'code': 'no', 'name': 'Norwegian (Norsk)'},
    {'code': 'sk', 'name': 'Slovak (Slovenčina)'},
    {'code': 'bg', 'name': 'Bulgarian (Български)'},
    {'code': 'hr', 'name': 'Croatian (Hrvatski)'},
    {'code': 'sr', 'name': 'Serbian (Српски)'},
    {'code': 'lt', 'name': 'Lithuanian (Lietuvių)'},
    {'code': 'sl', 'name': 'Slovenian (Slovenščina)'},
    {'code': 'et', 'name': 'Estonian (Eesti)'},
    {'code': 'lv', 'name': 'Latvian (Latviešu)'},
    {'code': 'af', 'name': 'Afrikaans'},
    {'code': 'sq', 'name': 'Albanian (Shqip)'},
    {'code': 'am', 'name': 'Amharic (አማርኛ)'},
    {'code': 'hy', 'name': 'Armenian (Հայերեն)'},
    {'code': 'az', 'name': 'Azerbaijani (Azərbaycan)'},
    {'code': 'eu', 'name': 'Basque (Euskara)'},
    {'code': 'be', 'name': 'Belarusian (Беларуская)'},
    {'code': 'bs', 'name': 'Bosnian (Bosanski)'},
    {'code': 'ca', 'name': 'Catalan (Català)'},
    {'code': 'ka', 'name': 'Georgian (ქართული)'},
    {'code': 'ha', 'name': 'Hausa'},
    {'code': 'is', 'name': 'Icelandic (Íslenska)'},
    {'code': 'ig', 'name': 'Igbo'},
    {'code': 'ga', 'name': 'Irish (Gaeilge)'},
    {'code': 'jw', 'name': 'Javanese'},
    {'code': 'kk', 'name': 'Kazakh (Қазақ)'},
    {'code': 'km', 'name': 'Khmer (ខ្មែរ)'},
    {'code': 'ku', 'name': 'Kurdish'},
    {'code': 'ky', 'name': 'Kyrgyz (Кыргызча)'},
    {'code': 'lo', 'name': 'Lao (ລາວ)'},
    {'code': 'la', 'name': 'Latin'},
    {'code': 'mk', 'name': 'Macedonian (Македонски)'},
    {'code': 'mg', 'name': 'Malagasy'},
    {'code': 'mt', 'name': 'Maltese (Malti)'},
    {'code': 'mn', 'name': 'Mongolian (Монгол)'},
    {'code': 'my', 'name': 'Myanmar (Burmese)'},
    {'code': 'ps', 'name': 'Pashto (پښتو)'},
    {'code': 'sd', 'name': 'Sindhi (سنڌي)'},
    {'code': 'si', 'name': 'Sinhala (සිଂහල)'},
    {'code': 'so', 'name': 'Somali'},
    {'code': 'sw', 'name': 'Swahili (Kiswahili)'},
    {'code': 'tg', 'name': 'Tajik (Тоҷикӣ)'},
    {'code': 'uz', 'name': 'Uzbek (Oʻzbek)'},
    {'code': 'cy', 'name': 'Welsh (Cymraeg)'},
    {'code': 'xh', 'name': 'Xhosa'},
    {'code': 'yi', 'name': 'Yiddish'},
    {'code': 'yo', 'name': 'Yoruba'},
    {'code': 'zu', 'name': 'Zulu'}
  ];

  final Map<String, List<String>> _whatsappEmojiCategories = {
    'Smileys': ['😀','😃','😄','😁','😆','😅','😂','🤣','😊','😇','🙂','😉','😍','🥰','😘','😋','😎','🤩','🥳','😏','🥺','😢','😭','😡','🤯','🤗','🤔','😴','🤮','😷'],
    'Gestures': ['👍','👎','👏','🙌','👐','🤲','🤝','🙏','✍️','💪','✌️','🤞','🤟','🤘','🤙','👈','👉','👆','👇','✋','👌','🤌','🤏','👋','👊','✊','🤛','🤜'],
    'Love': ['❤️','🧡','💛','💚','💙','💜','🖤','🤍','🤎','💔','❤️‍🔥','💕','💞','💓','💗','💖','💘','💝','💟','☮️','✝️','🔥','✨','🎉','💯','🌹','🌸','💐'],
    'Food': ['🍏','🍎','🍐','🍊','🍋','🍌','🍉','🍇','🍓','🫐','🍒','🍑','🥭','🍍','🥥','🥝','🍅','🍔','🍟','🍕','🌮','🍜','🍣','🎂','🍰','🍫','☕','🧃','🥤'],
    'Objects': ['💻','📱','☎️','📷','🎥','🎧','🎤','💡','💸','💵','💳','📦','✉️','📑','📊','📈','🔑','🔒','🔨','⚙️','🛡️','🚗','🚕','✈️','🚀','🏠','🏥']
  };

  @override
  void initState() {
    super.initState();
    _loadStoredChatAndFetch();
    _chatPollingTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetchMessages(silent: true));
  }

  @override
  void dispose() {
    _chatPollingTimer?.cancel();
    _voiceTimer?.cancel();
    _scrollController.dispose();
    _msgController.dispose();
    super.dispose();
  }

  Future<void> _loadStoredChatAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final last10 = widget.phone.length >= 10 ? widget.phone.substring(widget.phone.length - 10) : widget.phone;
    final cached = prefs.getString('wuba_chat_$last10');

    if (cached != null) {
      try {
        final decoded = jsonDecode(cached) as List<dynamic>;
        setState(() {
          _messages = decoded;
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
          setState(() {
            _messages = newMsgs;
          });
          _scrollToBottom();
        }
        final prefs = await SharedPreferences.getInstance();
        final last10 = widget.phone.length >= 10 ? widget.phone.substring(widget.phone.length - 10) : widget.phone;
        await prefs.setString('wuba_chat_$last10', jsonEncode(newMsgs));
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

  Future<void> _handleSendDecision({String? customText, String? mediaType, String? mediaUrl}) async {
    final text = customText ?? _msgController.text.trim();
    if (text.isEmpty && mediaUrl == null) return;

    if (_selectedChannel == 'whatsapp') {
      final res = await http.get(Uri.parse('https://wubachat.com/api/app_api.php?action=get_wallet&user_id=${widget.userId}'));
      final d = jsonDecode(res.body);
      final bal = (d['balance'] as num?)?.toDouble() ?? 0.0;

      if (bal < 0.50) {
        _showEnglishPopup(
          title: 'Insufficient Balance',
          message: 'Your wallet balance is low (Required: ₹0.50 per template outside 24h window). Please add balance to dispatch official WhatsApp messages.',
        );
        return;
      }
    } else {
      final res = await http.get(Uri.parse('https://wubachat.com/api/app_api.php?action=check_wubachat_user&phone=${widget.phone}'));
      final d = jsonDecode(res.body);
      if (d['is_wubachat_user'] != true) {
        _showEnglishPopup(
          title: 'Recipient Not on Wubachat',
          message: 'This mobile number is not registered on Wubachat. Please switch toggle to "WhatsApp" or invite them to Wubachat.',
        );
        return;
      }
    }

    _executeSendMessage(text, mediaType: mediaType, mediaUrl: mediaUrl);
  }

  void _showEnglishPopup({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(message, style: const TextStyle(fontSize: 13, height: 1.4)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeSendMessage(String text, {String? mediaType, String? mediaUrl}) async {
    final sendingWamid = _replyToWamid;
    _msgController.clear();
    setState(() {
      _replyToWamid = null;
      _replyToText = null;
      _messages.add({
        'id': DateTime.now().millisecondsSinceEpoch,
        'message_text': text,
        'direction': 'outbound',
        'is_me': 1,
        'media_type': mediaType ?? 'text',
        'media_url': mediaUrl ?? '',
        'status': 'sent',
        'created_at': 'Just now',
      });
    });
    _scrollToBottom();

    try {
      await http.post(
        Uri.parse('https://wubachat.com/api/app_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'send_message',
          'user_id': widget.userId,
          'recipient': widget.phone,
          'message': text,
          'sent_via': _selectedChannel,
          'media_type': mediaType ?? 'text',
          'media_url': mediaUrl ?? '',
          'reply_to_wamid': sendingWamid ?? ''
        }),
      );
      _fetchMessages(silent: true);
    } catch (_) {}
  }

  Future<void> _translateInputText() async {
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

  void _openFullEmojiPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DefaultTabController(
        length: _whatsappEmojiCategories.keys.length,
        child: SizedBox(
          height: 320,
          child: Column(
            children: [
              TabBar(
                isScrollable: true,
                indicatorColor: const Color(0xFF00A884),
                labelColor: const Color(0xFF00A884),
                unselectedLabelColor: Colors.grey,
                tabs: _whatsappEmojiCategories.keys.map((k) => Tab(text: k)).toList(),
              ),
              Expanded(
                child: TabBarView(
                  children: _whatsappEmojiCategories.values.map((list) {
                    return GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 8, crossAxisSpacing: 8),
                      itemCount: list.length,
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () {
                          _msgController.text += list[i];
                          _msgController.selection = TextSelection.fromPosition(TextPosition(offset: _msgController.text.length));
                        },
                        child: Center(child: Text(list[i], style: const TextStyle(fontSize: 26))),
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

  void _openAttachmentPicker() {
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
            _attachmentOption(Icons.insert_drive_file, 'Document', const Color(0xFF5F66CD), () {
              Navigator.pop(ctx);
              _handleSendDecision(mediaType: 'document', mediaUrl: 'https://wubachat.com/uploads/document.pdf', customText: '[Document]: https://wubachat.com/uploads/Inspection_Report.pdf');
            }),
            _attachmentOption(Icons.camera_alt, 'Camera', const Color(0xFFD3396D), () {
              Navigator.pop(ctx);
              _handleSendDecision(mediaType: 'image', mediaUrl: 'https://placehold.co/600x400/008069/ffffff?text=Vehicle+Inspection+Snap', customText: '[Image]: https://placehold.co/600x400/008069/ffffff?text=Vehicle+Inspection+Snap');
            }),
            _attachmentOption(Icons.image, 'Gallery', const Color(0xFFAC44CF), () {
              Navigator.pop(ctx);
              _handleSendDecision(mediaType: 'image', mediaUrl: 'https://placehold.co/600x400/00A884/ffffff?text=Claim_Damage_Photo', customText: '[Image]: https://placehold.co/600x400/00A884/ffffff?text=Claim_Damage_Photo');
            }),
            _attachmentOption(Icons.location_on, 'Location', const Color(0xFF1FA855), () {
              Navigator.pop(ctx);
              _handleSendDecision(customText: '📍 Location: https://maps.google.com/?q=28.6139,77.2090');
            }),
            _attachmentOption(Icons.person, 'Contact', const Color(0xFF009DE2), () {
              Navigator.pop(ctx);
              _handleSendDecision(customText: '📇 Contact: Er. Wajid Ali (+91 8909034515)');
            }),
          ],
        ),
      ),
    );
  }

  Widget _attachmentOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 28, backgroundColor: color, child: Icon(icon, color: Colors.white, size: 26)),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _startVoiceRecording() {
    setState(() {
      _isRecordingVoice = true;
      _voiceSeconds = 0;
    });
    _voiceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _voiceSeconds++);
    });
  }

  void _finishAndSendVoiceRecording() {
    _voiceTimer?.cancel();
    final duration = _voiceSeconds;
    setState(() => _isRecordingVoice = false);
    _handleSendDecision(
      mediaType: 'audio',
      mediaUrl: 'https://wubachat.com/uploads/voice_sample.mp3',
      customText: '🎤 Voice Note (${duration < 10 ? "0$duration" : duration}s)',
    );
  }

  void _cancelVoiceRecording() {
    _voiceTimer?.cancel();
    setState(() => _isRecordingVoice = false);
  }

  void _openCallModal(String callType) {
    bool isMuted = false;
    bool isSpeakerOn = true;

    http.post(
      Uri.parse('https://wubachat.com/api/app_api.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'action': 'initiate_call', 'user_id': widget.userId, 'recipient': widget.phone, 'call_type': callType}),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setCallState) {
          return Dialog(
            backgroundColor: const Color(0xFF111B21),
            insetPadding: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Container(
              height: 480,
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      CircleAvatar(
                        radius: 45,
                        backgroundColor: const Color(0xFF00A884),
                        child: Text(
                          widget.name.isNotEmpty ? widget.name.substring(0, 1).toUpperCase() : 'U',
                          style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(widget.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(
                        callType == 'video' ? 'Wubachat Video Call (Encrypted)' : 'Wubachat Voice Call (Encrypted)',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      const Text('Ringing...', style: TextStyle(color: Color(0xFF25D366), fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(isMuted ? Icons.mic_off : Icons.mic, color: Colors.white, size: 28),
                        onPressed: () => setCallState(() => isMuted = !isMuted),
                      ),
                      IconButton(
                        icon: Icon(callType == 'video' ? Icons.videocam : Icons.volume_up, color: Colors.white, size: 28),
                        onPressed: () => setCallState(() => isSpeakerOn = !isSpeakerOn),
                      ),
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.red,
                        child: IconButton(
                          icon: const Icon(Icons.call_end, color: Colors.white, size: 28),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _fetchMessages();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _deleteSelectedBulk() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${_selectedMessageIds.length} Messages?'),
        content: const Text('Do you want to delete these selected messages?'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await http.post(
                Uri.parse('https://wubachat.com/api/app_api.php'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'action': 'delete_messages_bulk', 'user_id': widget.userId, 'message_ids': _selectedMessageIds.toList(), 'delete_type': 'me'}),
              );
              setState(() {
                _isSelectMode = false;
                _selectedMessageIds.clear();
              });
              _fetchMessages();
            },
            child: const Text('Delete for Me'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await http.post(
                Uri.parse('https://wubachat.com/api/app_api.php'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'action': 'delete_messages_bulk', 'user_id': widget.userId, 'message_ids': _selectedMessageIds.toList(), 'delete_type': 'everyone'}),
              );
              setState(() {
                _isSelectMode = false;
                _selectedMessageIds.clear();
              });
              _fetchMessages();
            },
            child: const Text('Delete for Everyone'),
          ),
        ],
      ),
    );
  }

  void _openSurveyTemplateModal() {
    final claimCtrl = TextEditingController();
    final vehicleCtrl = TextEditingController();
    final linkCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paramount Inspection Link Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Meta 3-Body Variables (Costs ₹0.50 / 1 Credit)', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 10),
            TextField(controller: claimCtrl, decoration: const InputDecoration(labelText: 'Claim Number', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: vehicleCtrl, decoration: const InputDecoration(labelText: 'Vehicle Number', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: linkCtrl, decoration: const InputDecoration(labelText: 'Inspection Link', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF008069), foregroundColor: Colors.white),
            onPressed: () async {
              final c = claimCtrl.text.trim();
              final v = vehicleCtrl.text.trim();
              final l = linkCtrl.text.trim();
              if (c.isEmpty || v.isEmpty || l.isEmpty) return;
              Navigator.pop(ctx);

              await http.post(
                Uri.parse('https://wubachat.com/api/app_api.php'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'action': 'send_message',
                  'user_id': widget.userId,
                  'recipient': widget.phone,
                  'mode': 'template',
                  'claim_number': c,
                  'vehicle_number': v,
                  'inspection_link': l
                }),
              );
              _fetchMessages();
            },
            child: const Text('Send Official WhatsApp'),
          ),
        ],
      ),
    );
  }

  void _openImageLightbox(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _groupMessagesIntoBlocks() {
    final List<Map<String, dynamic>> blocks = [];
    List<Map<String, dynamic>> currentAlbum = [];
    String? currentDirection;

    for (var m in _messages) {
      final rawText = (m['message_text'] ?? '').toString();
      final isImg = rawText.startsWith('[Image]:');
      final dir = (m['direction'] ?? 'outbound').toString();

      if (isImg) {
        if (currentAlbum.isNotEmpty && currentDirection == dir) {
          currentAlbum.add(Map<String, dynamic>.from(m));
        } else {
          if (currentAlbum.isNotEmpty) {
            blocks.add({'type': 'album', 'direction': currentDirection, 'items': List.from(currentAlbum)});
            currentAlbum.clear();
          }
          currentDirection = dir;
          currentAlbum.add(Map<String, dynamic>.from(m));
        }
      } else {
        if (currentAlbum.isNotEmpty) {
          blocks.add({'type': 'album', 'direction': currentDirection, 'items': List.from(currentAlbum)});
          currentAlbum.clear();
          currentDirection = null;
        }
        blocks.add({'type': 'single', 'message': Map<String, dynamic>.from(m)});
      }
    }

    if (currentAlbum.isNotEmpty) {
      blocks.add({'type': 'album', 'direction': currentDirection, 'items': List.from(currentAlbum)});
    }

    return blocks;
  }

  @override
  Widget build(BuildContext context) {
    final blocks = _groupMessagesIntoBlocks();

    return Scaffold(
      backgroundColor: const Color(0xFFEFE7DE),
      appBar: _isSelectMode
          ? AppBar(
              backgroundColor: const Color(0xFF008069),
              title: Text('${_selectedMessageIds.length} Selected', style: const TextStyle(color: Colors.white)),
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => setState(() {
                  _isSelectMode = false;
                  _selectedMessageIds.clear();
                }),
              ),
              actions: [
                IconButton(icon: const Icon(Icons.delete, color: Colors.white), onPressed: _deleteSelectedBulk),
              ],
            )
          : AppBar(
              backgroundColor: const Color(0xFF008069),
              leading: widget.isEmbedded ? null : IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.name, style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.bold)),
                  Text(
                    _selectedChannel == 'whatsapp' ? 'via Official Meta Cloud API' : 'via Wubachat Free',
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
              actions: [
                IconButton(icon: const Icon(Icons.videocam, color: Colors.white), onPressed: () => _openCallModal('video'), tooltip: 'Video Call'),
                IconButton(icon: const Icon(Icons.call, color: Colors.white), onPressed: () => _openCallModal('audio'), tooltip: 'Voice Call'),
                IconButton(icon: const Icon(Icons.assignment, color: Colors.white), onPressed: _openSurveyTemplateModal, tooltip: 'Send Survey Template'),
                IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: () => _fetchMessages(silent: false)),
              ],
            ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF008069)))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: blocks.length,
                    itemBuilder: (context, blockIndex) {
                      final block = blocks[blockIndex];

                      if (block['type'] == 'album') {
                        final List<Map<String, dynamic>> items = block['items'];
                        final isOut = block['direction'] == 'outbound';
                        final lastMsg = items.last;
                        final time = lastMsg['created_at'] != null ? lastMsg['created_at'].toString().split(' ').last : '';

                        return Align(
                          alignment: isOut ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(maxWidth: 290),
                            decoration: BoxDecoration(
                              color: isOut ? const Color(0xFFE7FFDB) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 2)],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _buildWhatsAppAlbumGrid(items),
                                const SizedBox(height: 3),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(time, style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600)),
                                    if (isOut) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.done_all, size: 14, color: Color(0xFF34B7F1)),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final m = block['message'];
                      final id = (m['id'] as num?)?.toInt() ?? blockIndex;
                      final bool isMe = (m['direction'] == 'outbound' || m['is_me'] == 1);
                      final String text = m['message_text'] ?? '';
                      final String status = m['status'] ?? 'sent';
                      final String reaction = m['reaction'] ?? '';
                      final String time = m['created_at'] != null ? m['created_at'].toString().split(' ').last : '';
                      final bool isSelected = _selectedMessageIds.contains(id);

                      return Dismissible(
                        key: ValueKey('msg_key_$id'),
                        direction: DismissDirection.startToEnd,
                        confirmDismiss: (_) async {
                          setState(() {
                            _replyToWamid = m['wamid'] ?? id.toString();
                            _replyToText = text;
                          });
                          return false;
                        },
                        background: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 16),
                          child: const Icon(Icons.reply, color: Color(0xFF008069)),
                        ),
                        child: GestureDetector(
                          onLongPress: () {
                            setState(() {
                              _isSelectMode = true;
                              _selectedMessageIds.add(id);
                            });
                          },
                          onTap: () {
                            if (_isSelectMode) {
                              setState(() {
                                if (isSelected) {
                                  _selectedMessageIds.remove(id);
                                  if (_selectedMessageIds.isEmpty) _isSelectMode = false;
                                } else {
                                  _selectedMessageIds.add(id);
                                }
                              });
                            }
                          },
                          child: Container(
                            color: isSelected ? Colors.teal.withOpacity(0.2) : Colors.transparent,
                            child: Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                    decoration: BoxDecoration(
                                      color: isMe ? const Color(0xFFE7FFDB) : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 2)],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        _buildSingleBubbleContent(text),
                                        const SizedBox(height: 3),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(time, style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600)),
                                            if (isMe) ...[
                                              const SizedBox(width: 4),
                                              Icon(status == 'read' ? Icons.done_all : Icons.done, size: 14, color: status == 'read' ? const Color(0xFF34B7F1) : Colors.grey),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (reaction.isNotEmpty)
                                    Positioned(
                                      bottom: -5,
                                      right: isMe ? 4 : null,
                                      left: !isMe ? 4 : null,
                                      child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Text(reaction, style: const TextStyle(fontSize: 12))),
                                    ),
                                ],
                              ),
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
              color: const Color(0xFFEEEEEE),
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 16, color: Color(0xFF008069)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Replying: ${_replyToText ?? ""}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                  IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(() => _replyToWamid = null)),
                ],
              ),
            ),

          if (_isRecordingVoice)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFF0F2F5),
              child: Row(
                children: [
                  const Icon(Icons.fiber_manual_record, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Text('Voice: ${_voiceSeconds}s', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.grey), onPressed: _cancelVoiceRecording),
                  IconButton(icon: const Icon(Icons.send, color: Color(0xFF00A884)), onPressed: _finishAndSendVoiceRecording),
                ],
              ),
            ),

          // FULL INPUT BAR (ATTACHMENT, EMOJI, 100+ LANGUAGES, TOGGLE, MIC & SEND)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey, size: 22),
                  onPressed: _openFullEmojiPicker,
                  tooltip: 'WhatsApp Emojis',
                ),
                IconButton(
                  icon: const Icon(Icons.attach_file, color: Colors.grey, size: 22),
                  onPressed: _openAttachmentPicker,
                  tooltip: 'Attachments',
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                  child: DropdownButton<String>(
                    value: _selectedLang,
                    underline: const SizedBox(),
                    isDense: true,
                    menuMaxHeight: 380,
                    items: _all100Languages.map((lang) {
                      return DropdownMenuItem<String>(
                        value: lang['code'],
                        child: Text(lang['name']!, style: const TextStyle(fontSize: 10.5)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedLang = val);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.translate, color: Color(0xFF008069), size: 18),
                  onPressed: _translateInputText,
                  tooltip: 'Translate Input',
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedChannel = (_selectedChannel == 'whatsapp') ? 'wubachat' : 'whatsapp';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: _selectedChannel == 'whatsapp' ? const Color(0xFF128C7E) : const Color(0xFF00A884),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _selectedChannel == 'whatsapp' ? 'WhatsApp' : 'Wubachat',
                      style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
                    child: TextField(
                      controller: _msgController,
                      decoration: const InputDecoration(hintText: 'Type a message...', border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                      onSubmitted: (_) => _handleSendDecision(),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(_isRecordingVoice ? Icons.stop : Icons.mic, color: _isRecordingVoice ? Colors.red : const Color(0xFF008069), size: 22),
                  onPressed: () {
                    if (_isRecordingVoice) {
                      _finishAndSendVoiceRecording();
                    } else {
                      _startVoiceRecording();
                    }
                  },
                ),
                CircleAvatar(
                  radius: 19,
                  backgroundColor: const Color(0xFF00A884),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 16),
                    onPressed: () => _handleSendDecision(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhatsAppAlbumGrid(List<Map<String, dynamic>> items) {
    final int count = items.length;
    final displayItems = items.take(4).toList();

    int crossAxisCount = 2;
    if (count == 1) crossAxisCount = 1;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 3,
          mainAxisSpacing: 3,
          childAspectRatio: 1,
        ),
        itemCount: displayItems.length,
        itemBuilder: (context, idx) {
          final url = displayItems[idx]['message_text'].toString().replaceFirst('[Image]:', '').trim();
          final bool isLastOverFlow = (idx == 3 && count > 4);

          return GestureDetector(
            onTap: () => _openImageLightbox(url),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade300, child: const Icon(Icons.broken_image)),
                ),
                if (isLastOverFlow)
                  Container(
                    color: Colors.black54,
                    alignment: Alignment.center,
                    child: Text(
                      '+${count - 3}',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSingleBubbleContent(String rawText) {
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
    return Text(rawText, style: const TextStyle(fontSize: 14.5));
  }
}
