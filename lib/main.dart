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
// 1. AUTH SCREEN
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
                    const SizedBox(height: 25),
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
                    child: const Text('https://wubachat.com', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black87)),
                  ),
                  const SizedBox(height: 5),
                  const Text('Founder : Humera Ameer', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0B4636))),
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
// 2. DASHBOARD (LIVE CHAT FILTERS & DYNAMIC QR WALLET)
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
  double balance = 0.0;
  String adminUpi = 'wubachat@okaxis';
  String adminPayee = 'Wubachat Payments';
  int metaSent = 0;

  String currentChatFilter = 'all'; // all, unread, important, archive
  List<dynamic> chatList = [];
  bool isLoadingChats = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();
    _homePollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      fetchLiveChats(background: true);
      fetchLiveWallet();
    });
  }

  @override
  void dispose() {
    _homePollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('user_id') ?? '1';
      userName = prefs.getString('user_name') ?? 'User';
    });
    fetchLiveWallet();
    fetchLiveChats(background: false);
  }

  Future<void> fetchLiveWallet() async {
    try {
      final res = await http.get(Uri.parse('https://wubachat.com/api/app_api.php?action=get_wallet&user_id=$userId'));
      final data = jsonDecode(res.body);
      if (data['status'] == true && mounted) {
        setState(() {
          userName = data['name'] ?? userName;
          balance = (data['balance'] as num?)?.toDouble() ?? 0.0;
          adminUpi = data['admin_upi'] ?? adminUpi;
          adminPayee = data['admin_payee'] ?? adminPayee;
          metaSent = (data['meta_sent'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> fetchLiveChats({bool background = false}) async {
    if (!background) setState(() => isLoadingChats = true);
    try {
      final res = await http.get(
        Uri.parse('https://wubachat.com/api/app_api.php?action=get_chats&user_id=$userId&filter=$currentChatFilter'),
      );
      final data = jsonDecode(res.body);
      if (data['status'] == true && mounted) {
        setState(() {
          chatList = data['chats'] ?? [];
        });
      }
    } catch (_) {}
    if (!background && mounted) setState(() => isLoadingChats = false);
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

  // --- DYNAMIC AMOUNT-LINKED QR RECHARGE DIALOG ---
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
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
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
                    decoration: const InputDecoration(
                      labelText: 'Recharge Amount (Min: ₹100)',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      final parsed = double.tryParse(val) ?? 100.0;
                      setModalState(() {
                        currentAmt = parsed < 100.0 ? 100.0 : parsed;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: utrController,
                    decoration: const InputDecoration(
                      labelText: '12-digit UPI UTR / Ref Number',
                      border: OutlineInputBorder(),
                    ),
                  ),
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
                  if (amt < 100) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimum recharge amount is ₹100')));
                    return;
                  }
                  if (utr.length < 6) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid 12-digit UTR')));
                    return;
                  }
                  Navigator.pop(ctx);
                  try {
                    final res = await http.post(
                      Uri.parse('https://wubachat.com/api/app_api.php'),
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({'action': 'recharge_wallet', 'user_id': userId, 'amount': amt, 'utr_number': utr}),
                    );
                    final d = jsonDecode(res.body);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(d['message'] ?? 'Submitted!')));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Wubachat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Colors.white)),
            Text('Meta Limit: $metaSent / 250 Today', style: const TextStyle(fontSize: 10.5, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF008069),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: () => fetchLiveChats(background: false)),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (val) {
              if (val == 'recharge') _openRechargeDialog();
              if (val == 'logout') _logout();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'recharge', child: Text('Add Wallet Balance')),
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
          tabs: const [Tab(text: 'CHATS'), Tab(text: 'TOOLS'), Tab(text: 'WALLET')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildChatsTab(), _buildToolsTab(), _buildWalletTab()],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00A884),
        child: const Icon(Icons.chat, color: Colors.white),
        onPressed: () => _openNewChatDialog(context),
      ),
    );
  }

  Widget _buildChatsTab() {
    return Column(
      children: [
        // --- CHAT FILTER BUTTONS ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          color: Colors.grey.shade50,
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
        Expanded(
          child: isLoadingChats
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF008069)))
              : chatList.isEmpty
                  ? Center(child: Text('No conversations in $currentChatFilter tab', style: const TextStyle(color: Colors.grey)))
                  : RefreshIndicator(
                      onRefresh: () async {
                        await fetchLiveChats(background: false);
                      },
                      child: ListView.separated(
                        itemCount: chatList.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 75),
                        itemBuilder: (context, index) {
                          final chat = chatList[index];
                          final name = chat['contact_name'] ?? ('+' + (chat['phone_number'] ?? ''));
                          final phone = chat['phone_number'] ?? '';
                          final lastMsg = chat['last_msg'] ?? 'Tap to chat';
                          final unread = (chat['unread_count'] as num?)?.toInt() ?? 0;
                          final lastStatus = chat['last_status'] ?? 'sent';
                          final isOutbound = chat['last_direction'] == 'outbound';

                          return ListTile(
                            leading: CircleAvatar(
                              radius: 25,
                              backgroundColor: const Color(0xFF25D366).withOpacity(0.18),
                              child: Text(name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF008069))),
                            ),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            subtitle: Row(
                              children: [
                                if (isOutbound) ...[
                                  _renderTick(lastStatus, 14),
                                  const SizedBox(width: 4),
                                ],
                                Expanded(child: Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
                              ],
                            ),
                            trailing: unread > 0
                                ? Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(color: Color(0xFF25D366), shape: BoxShape.circle),
                                    child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                  )
                                : null,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => ChatDetailScreen(name: name, phone: phone, userId: userId)),
                              );
                              fetchLiveChats(background: true);
                            },
                          );
                        },
                      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE7FCE3) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? const Color(0xFF008069) : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF008069) : Colors.grey.shade700)),
      ),
    );
  }

  Widget _renderTick(String status, double size) {
    if (status == 'read') return Icon(Icons.done_all, size: size, color: const Color(0xFF34B7F1));
    if (status == 'delivered') return Icon(Icons.done_all, size: size, color: Colors.grey);
    return Icon(Icons.done, size: size, color: Colors.grey);
  }

  Widget _buildToolsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Modular Business & Utility Tools', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 10),
        _toolCard(Icons.directions_car, 'mParivahan RC & DL Verification', 'Instant vehicle details verification engine', 'https://services.techywajid.com'),
        _toolCard(Icons.picture_as_pdf, 'PDF to Excel Data Extractor', 'Parse tabular documents directly into spreadsheets', 'https://services.techywajid.com'),
        _toolCard(Icons.campaign, 'Official WhatsApp Bulk Campaign', '1,000 Numbers Meta Blast Gateway', 'https://wubachat.com/broadcast.php'),
      ],
    );
  }

  Widget _toolCard(IconData icon, String title, String subtitle, String url) {
    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        leading: Icon(icon, color: const Color(0xFF008069)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
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
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF008069), Color(0xFF00A884)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Live Wallet Balance', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                Text('₹${balance.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: _openRechargeDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Credit (UPI QR)'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF008069)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          ListTile(leading: const Icon(Icons.account_circle, color: Color(0xFF008069)), title: Text(userName), subtitle: const Text('Logged Account')),
          const Divider(),
          ListTile(leading: const Icon(Icons.speed, color: Color(0xFF008069)), title: const Text('Daily Meta Limit'), subtitle: Text('$metaSent sent today of 250 quota')),
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
        content: TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: 'Enter 10-digit number', prefixText: '+91 ')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884)),
            onPressed: () {
              final num = phoneController.text.trim();
              if (num.isNotEmpty) {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (context) => ChatDetailScreen(name: '+91 $num', phone: '91$num', userId: userId)));
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
// 3. CHAT ROOM (TEMPLATE ENGINE, CONTACT DRAWER, STATUS TICKS)
// =========================================================================
class ChatDetailScreen extends StatefulWidget {
  final String name;
  final String phone;
  final String userId;

  const ChatDetailScreen({super.key, required this.name, required this.phone, required this.userId});

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

  @override
  void initState() {
    super.initState();
    _fetchMessages(initial: true);
    _chatPollingTimer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchMessages(initial: false));
  }

  @override
  void dispose() {
    _chatPollingTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages({bool initial = false}) async {
    try {
      final res = await http.get(Uri.parse('https://wubachat.com/api/app_api.php?action=get_messages&user_id=${widget.userId}&phone=${widget.phone}'));
      final data = jsonDecode(res.body);
      if (data['status'] == true && mounted) {
        final List<dynamic> newMsgs = data['messages'] ?? [];
        if (newMsgs.length != _messages.length || initial) {
          setState(() => _messages = newMsgs);
          _scrollToBottom();
        }
      }
    } catch (_) {}
    if (initial && mounted) setState(() => _isLoading = false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();

    setState(() {
      _messages.add({'message_text': text, 'direction': 'outbound', 'is_me': 1, 'status': 'sent', 'created_at': 'Just now'});
    });
    _scrollToBottom();

    try {
      await http.post(
        Uri.parse('https://wubachat.com/api/app_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'send_message', 'user_id': widget.userId, 'recipient': widget.phone, 'message': text, 'sent_via': _selectedChannel}),
      );
    } catch (_) {}
  }

  // --- PARAMOUNT SURVEY TEMPLATE MODAL (3 Body Variables) ---
  void _openSurveyTemplateModal() {
    final claimController = TextEditingController();
    final vehicleController = TextEditingController();
    final linkController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paramount Survey Alert Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Outside 24-hr session. Official template costs ₹0.50 (1 Credit).', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 10),
            TextField(controller: claimController, decoration: const InputDecoration(labelText: '1. Claim Number', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: vehicleController, decoration: const InputDecoration(labelText: '2. Vehicle Number', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: linkController, decoration: const InputDecoration(labelText: '3. Inspection Link', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF008069), foregroundColor: Colors.white),
            onPressed: () async {
              final c = claimController.text.trim();
              final v = vehicleController.text.trim();
              final l = linkController.text.trim();
              if (c.isEmpty || v.isEmpty || l.isEmpty) return;
              Navigator.pop(ctx);

              try {
                final res = await http.post(
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
                final d = jsonDecode(res.body);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(d['message'] ?? 'Dispatched')));
                _fetchMessages();
              } catch (_) {}
            },
            child: const Text('Send WhatsApp'),
          ),
        ],
      ),
    );
  }

  // --- CONTACT INFO & MEDIA DRAWER ---
  void _openContactDrawer() async {
    try {
      final res = await http.get(Uri.parse('https://wubachat.com/api/app_api.php?action=get_contact_info&user_id=${widget.userId}&phone=${widget.phone}'));
      final data = jsonDecode(res.body);

      if (mounted) {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (ctx) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(radius: 30, backgroundColor: const Color(0xFF008069), child: Text(widget.name.substring(0, 1), style: const TextStyle(color: Colors.white, fontSize: 24))),
                const SizedBox(height: 10),
                Text(widget.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text('+${widget.phone}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 12),
                Text(data['bio'] ?? 'Hey there! I am using WhatsApp.', style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
                const Divider(height: 25),
                ListTile(
                  leading: const Icon(Icons.ban, color: Colors.red),
                  title: Text(data['is_blocked'] == true ? 'Unblock Contact' : 'Block Contact', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await http.post(
                      Uri.parse('https://wubachat.com/api/app_api.php'),
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({'action': 'toggle_block', 'user_id': widget.userId, 'phone': widget.phone}),
                    );
                    _openContactDrawer();
                  },
                ),
              ],
            ),
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFE7DE),
      appBar: AppBar(
        backgroundColor: const Color(0xFF008069),
        title: GestureDetector(
          onTap: _openContactDrawer,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const Text('Tap for Contact Info', style: TextStyle(color: Colors.white70, fontSize: 10)),
            ],
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.assignment, color: Colors.white), onPressed: _openSurveyTemplateModal, tooltip: 'Send Survey Template'),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: () => _fetchMessages(initial: false)),
        ],
      ),
      body: Column(
        children: [
          // CHANNEL TOGGLE
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            color: const Color(0xFFDCF8C6),
            child: Row(
              children: [
                const Text('Channel: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0B4636))),
                const Spacer(),
                ChoiceChip(label: const Text('WhatsApp (Meta)'), selected: _selectedChannel == 'whatsapp', onSelected: (_) => setState(() => _selectedChannel = 'whatsapp')),
                const SizedBox(width: 6),
                ChoiceChip(label: const Text('Wubachat Free'), selected: _selectedChannel == 'wubachat', onSelected: (_) => setState(() => _selectedChannel = 'wubachat')),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF008069)))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final m = _messages[index];
                      final bool isMe = (m['direction'] == 'outbound' || m['is_me'] == 1);
                      final String text = m['message_text'] ?? '';
                      final String status = m['status'] ?? 'sent';
                      final String time = m['created_at'] != null ? m['created_at'].toString().split(' ').last : '';

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
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
                              Text(text, style: const TextStyle(fontSize: 14.5)),
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
                    child: TextField(controller: _msgController, decoration: const InputDecoration(hintText: 'Message', border: InputBorder.none)),
                  ),
                ),
                const SizedBox(width: 6),
                CircleAvatar(
                  backgroundColor: const Color(0xFF00A884),
                  child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 18), onPressed: _sendMessage),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
