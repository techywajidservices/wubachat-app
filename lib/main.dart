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
// 2. DASHBOARD HOME (SPLIT DESKTOP VIEW, PERSISTENT CACHE, CONTACT ACTIONS)
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
    });

    // 0ms Persistent Cache load for chat list
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
        // Save to SharedPreferences for permanent auto-sync
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_chat_list', jsonEncode(fetched));
      }
    } catch (_) {}
    if (!background && mounted) setState(() => isLoadingChats = false);
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
              IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: () => fetchLiveChats(background: false), tooltip: 'Refresh'),
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
// 3. CHAT ROOM (PARSED MEDIA, COMPACT TOGGLE, MULTI-SELECT, SWIPE-REPLY)
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

  // Selected Channel: 'whatsapp' or 'wubachat'
  String _selectedChannel = 'whatsapp';

  // Multi-Select Mode States
  bool _isSelectMode = false;
  final Set<int> _selectedMessageIds = {};

  String? _replyToWamid;
  String? _replyToText;

  @override
  void initState() {
    super.initState();
    _loadStoredChatAndFetch();
    _chatPollingTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetchMessages(silent: true));
  }

  @override
  void dispose() {
    _chatPollingTimer?.cancel();
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
        // Save to Phone Persistent Storage
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

  // --- VALIDATED SEND DECISION ENGINE ---
  Future<void> _handleSendDecision() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    if (_selectedChannel == 'whatsapp') {
      // 1. Fetch user balance & Meta status
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
      // 2. Wubachat User Check
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

    _executeSendMessage(text);
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

  Future<void> _executeSendMessage(String text) async {
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
          'reply_to_wamid': sendingWamid ?? ''
        }),
      );
      _fetchMessages(silent: true);
    } catch (_) {}
  }

  // --- MULTI-MESSAGE DELETE & FORWARD ---
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

  // --- PARAMOUNT SURVEY TEMPLATE MODAL ---
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

  // --- PARSED MEDIA RENDERER (IMAGES & DOCS INSTEAD OF RAW TEXT) ---
  Widget _buildParsedBubbleContent(String rawText) {
    if (rawText.startsWith('[Image]:')) {
      final url = rawText.replaceFirst('[Image]:', '').trim();
      return GestureDetector(
        onTap: () {
          // Open Lightbox
          showDialog(
            context: context,
            builder: (_) => Dialog(
              backgroundColor: Colors.transparent,
              child: Stack(
                children: [
                  Center(child: Image.network(url, fit: BoxFit.contain)),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
            height: 180,
            width: 240,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Row(children: [Icon(Icons.broken_image), Text(' Image Error')]),
          ),
        ),
      );
    } else if (rawText.startsWith('[Document]:')) {
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

  @override
  Widget build(BuildContext context) {
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
                IconButton(icon: const Icon(Icons.assignment, color: Colors.white), onPressed: _openSurveyTemplateModal, tooltip: 'Send Survey Template'),
                IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: () => _fetchMessages(silent: false)),
              ],
            ),
      body: Column(
        children: [
          // MESSAGES LIST
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF008069)))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final m = _messages[index];
                      final id = (m['id'] as num?)?.toInt() ?? index;
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
                          return false; // Quote immediately, do not remove
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
                                        _buildParsedBubbleContent(text),
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

          // ACTIVE QUOTE REPLY STRIP
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

          // COMPACT BOTTOM INPUT BAR (CHANNEL TOGGLE + SINGLE COMPACT SEND)
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Row(
              children: [
                // COMPACT TOGGLE PILL
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_selectedChannel == 'whatsapp' ? Icons.phone_android : Icons.bolt, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          _selectedChannel == 'whatsapp' ? 'WhatsApp' : 'Wubachat',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(22)),
                    child: TextField(
                      controller: _msgController,
                      decoration: const InputDecoration(hintText: 'Type a message...', border: InputBorder.none),
                      onSubmitted: (_) => _handleSendDecision(),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // SINGLE WHATSAPP-STYLE CIRCULAR SEND ICON
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF00A884),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: _handleSendDecision,
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
