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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() => isLoading = true);

    try {
      final res = await http.post(
        Uri.parse('https://wubachat.com/api/app_auth.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': isLogin ? 'login' : 'register', 'phone': phone, 'password': password, 'role': selectedRole, 'name': name}),
      );
      final data = jsonDecode(res.body);

      if (data['status'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token'] ?? '');
        await prefs.setString('user_id', data['user']['id'].toString());
        await prefs.setString('user_name', data['user']['name'] ?? 'User');
        await prefs.setString('user_phone', data['user']['phone'] ?? phone);
        await prefs.setDouble('balance', (data['user']['balance'] as num?)?.toDouble() ?? 0.0);

        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Auth failed')));
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Image.asset('assets/logo.png', height: 110, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.chat, size: 80, color: Color(0xFF00A884))),
              const SizedBox(height: 25),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => isLogin = true),
                      child: Column(
                        children: [
                          Text('LOGIN', style: TextStyle(fontWeight: FontWeight.bold, color: isLogin ? const Color(0xFF00A884) : Colors.grey)),
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
                          Text('REGISTER', style: TextStyle(fontWeight: FontWeight.bold, color: !isLogin ? const Color(0xFF00A884) : Colors.grey)),
                          const SizedBox(height: 6),
                          Container(height: 2.5, color: !isLogin ? const Color(0xFF00A884) : Colors.transparent),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (!isLogin) ...[
                TextField(controller: nameController, decoration: const InputDecoration(hintText: 'Full Name', border: OutlineInputBorder())),
                const SizedBox(height: 12),
              ],
              TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: 'Mobile Number', prefixText: '+91 ', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => obscurePassword = !obscurePassword)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: isLoading ? null : handleAuth,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884), foregroundColor: Colors.white),
                  child: isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(isLogin ? 'CONTINUE' : 'REGISTER NOW', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// 2. DASHBOARD HOME (DESKTOP SPLIT VIEW, FILTERS, SEARCH, DYNAMIC QR)
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
    _homePollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
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
      final url = 'https://wubachat.com/api/app_api.php?action=get_chats&user_id=$userId&filter=$currentChatFilter&search=${Uri.encodeComponent(searchQuery)}';
      final res = await http.get(Uri.parse(url));
      final data = jsonDecode(res.body);
      if (data['status'] == true && mounted) {
        setState(() {
          chatList = data['chats'] ?? [];
          if (activeChatPhone == null && chatList.isNotEmpty) {
            activeChatPhone = chatList[0]['phone_number'];
            activeChatName = chatList[0]['contact_name'];
          }
        });
      }
    } catch (_) {}
    if (!background && mounted) setState(() => isLoadingChats = false);
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
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
                  if (amt < 100) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimum recharge amount is ₹100')));
                    return;
                  }
                  if (utr.length < 6) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid 12-digit UTR')));
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

  void _openNewChatDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start New Conversation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Contact Name (Optional)')),
            const SizedBox(height: 10),
            TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: '10-digit mobile number', prefixText: '+91 ')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884), foregroundColor: Colors.white),
            onPressed: () {
              final num = phoneController.text.trim();
              final cName = nameController.text.trim();
              if (num.isNotEmpty) {
                Navigator.pop(ctx);
                final displayName = cName.isNotEmpty ? cName : '+91 $num';
                if (MediaQuery.of(context).size.width > 750) {
                  setState(() {
                    activeChatPhone = '91$num';
                    activeChatName = displayName;
                  });
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ChatDetailScreen(name: displayName, phone: '91$num', userId: userId, isEmbedded: false)),
                  );
                }
              }
            },
            child: const Text('Chat'),
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
              IconButton(icon: const Icon(Icons.receipt_long, color: Colors.white), onPressed: _openBillingLogsModal, tooltip: 'Billing Logs'),
              IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: () => fetchLiveChats(background: false), tooltip: 'Refresh'),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (val) {
                  if (val == 'recharge') _openRechargeDialog();
                  if (val == 'billing') _openBillingLogsModal();
                  if (val == 'logout') _logout();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'recharge', child: Text('Add Wallet Balance')),
                  const PopupMenuItem(value: 'billing', child: Text('Billing Logs')),
                  const PopupMenuItem(value: 'logout', child: Text('Logout', style: TextStyle(color: Colors.red))),
                ],
              ),
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
              // TOP RED ALERT NOTICE BANNER
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
          floatingActionButton: isDesktop
              ? null
              : FloatingActionButton(
                  backgroundColor: const Color(0xFF00A884),
                  child: const Icon(Icons.chat, color: Colors.white),
                  onPressed: () => _openNewChatDialog(context),
                ),
        );
      },
    );
  }

  Widget _buildChatsListSection({required bool isDesktop}) {
    return Column(
      children: [
        // SEARCH INPUT BOX
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          child: Container(
            height: 38,
            decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(20)),
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: 'Search contacts, numbers or words...',
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

        // FILTER TABS (ALL, UNREAD, FAVOURITES, IMPORTANT, ARCHIVE)
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
                _filterChip('favourites', 'Favourites'),
                const SizedBox(width: 6),
                _filterChip('important', 'Important'),
                const SizedBox(width: 6),
                _filterChip('archive', 'Archive'),
              ],
            ),
          ),
        ),
        const Divider(height: 1),

        // CONVERSATIONS LIST
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
                                Expanded(child: Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5))),
                              ],
                            ),
                            trailing: unread > 0
                                ? Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(color: Color(0xFF25D366), shape: BoxShape.circle),
                                    child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  )
                                : null,
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
// 3. CHAT ROOM (DUAL ACTION BUTTONS, TEMPLATES, REACTIONS, TRANSLATE)
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

  String? _replyToWamid;
  String? _replyToText;
  String _selectedLang = 'hi-Latn';

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

  Future<void> _sendMessage(String channel) async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final sendingWamid = _replyToWamid;
    _msgController.clear();
    setState(() {
      _replyToWamid = null;
      _replyToText = null;
      _messages.add({
        'id': 0,
        'message_text': text,
        'direction': 'outbound',
        'is_me': 1,
        'status': 'sent',
        'created_at': 'Just now',
      });
    });
    _scrollToBottom();

    try {
      await http.post(
        Uri.parse('https://wubachat.com/api/app_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'send_message', 'user_id': widget.userId, 'recipient': widget.phone, 'message': text, 'sent_via': channel, 'reply_to_wamid': sendingWamid ?? ''}),
      );
      _fetchMessages();
    } catch (_) {}
  }

  void _openSurveyTemplateModal() {
    final claimController = TextEditingController();
    final vehicleController = TextEditingController();
    final linkController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paramount Inspection Alert Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Meta Template (Costs ₹0.50 / 1 Credit)', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 10),
            TextField(controller: claimController, decoration: const InputDecoration(labelText: 'Claim Number', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: vehicleController, decoration: const InputDecoration(labelText: 'Vehicle Number', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: linkController, decoration: const InputDecoration(labelText: 'Inspection Link', border: OutlineInputBorder())),
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

  void _showMessageOptions(Map<String, dynamic> msg) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji Reaction Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['👍', '❤️', '😂', '😮', '😢', '🙏'].map((emoji) {
                  return GestureDetector(
                    onTap: () async {
                      Navigator.pop(ctx);
                      await http.post(
                        Uri.parse('https://wubachat.com/api/app_api.php'),
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode({'action': 'react_message', 'user_id': widget.userId, 'message_id': msg['id'], 'emoji': emoji}),
                      );
                      _fetchMessages();
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
                  );
                }).toList(),
              ),
              const Divider(height: 25),
              ListTile(
                leading: const Icon(Icons.reply, color: Color(0xFF008069)),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _replyToWamid = msg['wamid'] ?? msg['id'].toString();
                    _replyToText = msg['message_text'];
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy, color: Color(0xFF008069)),
                title: const Text('Copy Text'),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
                },
              ),
              ListTile(
                leading: const Icon(Icons.translate, color: Color(0xFF008069)),
                title: const Text('Translate Message'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final res = await http.post(
                    Uri.parse('https://wubachat.com/api/app_api.php'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({'action': 'translate', 'user_id': widget.userId, 'text': msg['message_text'], 'target': 'hi'}),
                  );
                  final d = jsonDecode(res.body);
                  if (mounted) {
                    showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Translation'),
                        content: Text(d['translated_text'] ?? msg['message_text']),
                        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))],
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline, color: Color(0xFF008069)),
                title: const Text('Message Info'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openMessageInfoModal(msg);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Message'),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteMessage(msg);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMessageInfoModal(Map<String, dynamic> msg) {
    final status = (msg['status'] ?? 'sent').toString().toUpperCase();
    final time = msg['created_at']?.toString() ?? 'Just now';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF008069)),
            SizedBox(width: 8),
            Text('Message Info', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(8)),
              child: Text(msg['message_text'] ?? '', style: const TextStyle(fontSize: 13)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(children: [Icon(Icons.done_all, color: Color(0xFF34B7F1), size: 16), SizedBox(width: 6), Text('Read')]),
                Text(status == 'READ' ? time : 'Not read yet', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(children: [Icon(Icons.done_all, color: Colors.grey, size: 16), SizedBox(width: 6), Text('Delivered')]),
                Text(status == 'DELIVERED' || status == 'READ' ? time : 'Pending', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(children: [Icon(Icons.done, color: Colors.grey, size: 16), SizedBox(width: 6), Text('Sent')]),
                Text(time, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  void _confirmDeleteMessage(Map<String, dynamic> msg) {
    final isMe = (msg['direction'] == 'outbound' || msg['is_me'] == 1);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Message?'),
        content: Text(isMe ? 'Do you want to delete this message for everyone or just for you?' : 'Delete this message for yourself?'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await http.post(
                Uri.parse('https://wubachat.com/api/app_api.php'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'action': 'delete_message', 'user_id': widget.userId, 'message_id': msg['id'], 'delete_type': 'me'}),
              );
              _fetchMessages();
            },
            child: const Text('Delete for Me'),
          ),
          if (isMe)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                await http.post(
                  Uri.parse('https://wubachat.com/api/app_api.php'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({'action': 'delete_message', 'user_id': widget.userId, 'message_id': msg['id'], 'delete_type': 'everyone'}),
                );
                _fetchMessages();
              },
              child: const Text('Delete for Everyone'),
            ),
        ],
      ),
    );
  }

  void _openContactDrawer() async {
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
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFF008069),
                child: Text(widget.name.isNotEmpty ? widget.name.substring(0, 1).toUpperCase() : 'U', style: const TextStyle(color: Colors.white, fontSize: 24)),
              ),
              const SizedBox(height: 10),
              Text(widget.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text('+${widget.phone}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 12),
              Text(data['bio'] ?? 'Hey there! I am using WhatsApp.', style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
              const Divider(height: 25),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: Text(data['is_blocked'] == true ? 'Unblock Contact' : 'Block Contact', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await http.post(
                    Uri.parse('https://wubachat.com/api/app_api.php'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({'action': 'toggle_block', 'user_id': widget.userId, 'phone': widget.phone}),
                  );
                },
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFE7DE),
      appBar: AppBar(
        backgroundColor: const Color(0xFF008069),
        leading: widget.isEmbedded ? null : IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: GestureDetector(
          onTap: _openContactDrawer,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.name, style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.bold)),
              const Text('⚡ On Wubachat (Free) • Tap for Info', style: TextStyle(color: Colors.white70, fontSize: 10)),
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
                      final String reaction = m['reaction'] ?? '';
                      final String time = m['created_at'] != null ? m['created_at'].toString().split(' ').last : '';

                      return GestureDetector(
                        onLongPress: () => _showMessageOptions(m),
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
                                    Text(text, style: const TextStyle(fontSize: 14)),
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
                      );
                    },
                  ),
          ),

          // REPLY PREVIEW STRIP
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

          // INPUT & DUAL SEND BUTTON BAR
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                      child: DropdownButton<String>(
                        value: _selectedLang,
                        underline: const SizedBox(),
                        isDense: true,
                        items: const [
                          DropdownMenuItem(value: 'hi-Latn', child: Text('Hinglish', style: TextStyle(fontSize: 11))),
                          DropdownMenuItem(value: 'hi', child: Text('Hindi', style: TextStyle(fontSize: 11))),
                          DropdownMenuItem(value: 'en', child: Text('English', style: TextStyle(fontSize: 11))),
                        ],
                        onChanged: (val) => setState(() => _selectedLang = val!),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.translate, color: Color(0xFF008069), size: 18), onPressed: _translateInputText, tooltip: 'Translate Input'),
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        decoration: const InputDecoration(hintText: 'Type message...', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      icon: const Icon(Icons.send, size: 14),
                      label: const Text('Send Wubachat', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      onPressed: () => _sendMessage('wubachat'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF128C7E), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      icon: const Icon(Icons.send, size: 14),
                      label: const Text('Send WhatsApp', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      onPressed: () => _sendMessage('whatsapp'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
