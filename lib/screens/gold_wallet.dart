import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

// Navigation Imports (Make sure these match your project structure)
import 'welcome.dart';
import 'transactions.dart';
import 'redemption.dart';
import 'profile.dart';
import '../core/localization/language_provider.dart';

class GoldWalletScreen extends StatefulWidget {
  const GoldWalletScreen({super.key});

  @override
  State<GoldWalletScreen> createState() => _GoldWalletScreenState();
}

class _GoldWalletScreenState extends State<GoldWalletScreen> {
  // Brand Colors
  final Color brandPurple = const Color(0xFF5D1F88);
  final Color cardPink = const Color(0xFFF8BBD0);

  // Data Variables
  String totalGold = "0.000";
  String totalInvested = "0.00";
  List<dynamic> transactions = [];
  bool isLoading = true;
  
  // Live Rate Variables
  double _liveGoldRate = 0.0;
  bool _isFetchingRate = true;
  
  // This variable remembers the amount while Razorpay is open!
  double _pendingAmount = 0.0;

  // Razorpay Instance
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _fetchWalletData();
    _fetchLiveGoldRate(); // Fetch the 9k rate for display

    // Initialize Razorpay & Listeners
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  // --- FETCH LIVE 9K RATE ---
  Future<void> _fetchLiveGoldRate() async {
    try {
      final response = await http.get(Uri.parse("https://ttjnextgen.divasprik.in/ttj_api/get_market_rates.php"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Specifically fetching the 9k rate for the wallet
        String rateStr = data['rates']?['gold9']?.toString() ?? "0";
        if (mounted) {
          setState(() {
            _liveGoldRate = double.tryParse(rateStr) ?? 0.0;
            _isFetchingRate = false;
          });
        }
      } else {
        if (mounted) setState(() => _isFetchingRate = false);
      }
    } catch (e) {
      debugPrint("Error fetching gold rate: $e");
      if (mounted) setState(() => _isFetchingRate = false);
    }
  }

  // --- RAZORPAY EVENT HANDLERS ---
  
  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    setState(() => isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final int? userId = prefs.getInt('user_id');

    if (userId == null) return;

    try {
      // Send payment details AND the pending amount to the backend
      final verifyResponse = await http.post(
        Uri.parse("https://ttjnextgen.divasprik.in/ttj_api/verify_wallet_razorpay.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "order_id": response.orderId,
          "razorpay_payment_id": response.paymentId,
          "razorpay_signature": response.signature,
          "user_id": userId,
          "amount": _pendingAmount, 
        }),
      );

      final verifyData = jsonDecode(verifyResponse.body);
      
      if (verifyData['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Payment Verified & Wallet Updated!"), backgroundColor: Colors.green),
        );
        _fetchWalletData(); // Refresh the wallet data
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Verification Failed: ${verifyData['message']}"), backgroundColor: Colors.red),
        );
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Error saving payment: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error saving payment to database"), backgroundColor: Colors.red),
      );
      setState(() => isLoading = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Payment Failed: ${response.message}"), backgroundColor: Colors.red),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("External Wallet Selected: ${response.walletName}"), backgroundColor: Colors.blue),
    );
  }

  // --- AMOUNT DIALOG & OPEN RAZORPAY ---

  void _showAmountDialog() {
    TextEditingController amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Add Money", style: TextStyle(color: brandPurple, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: "Enter amount in ₹",
            prefixIcon: const Icon(Icons.currency_rupee),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: brandPurple)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: brandPurple),
            onPressed: () {
              final amountText = amountController.text.trim();
              if (amountText.isNotEmpty) {
                final double amount = double.tryParse(amountText) ?? 0.0;
                
                // Validation Check - Minimum 100
                if (amount < 100) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Minimum amount is ₹100"), backgroundColor: Colors.red),
                  );
                  return;
                }

                // Validation Check - Multiples of 100
                if (amount % 100 != 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Amount must be in multiples of ₹100 (e.g., 200, 300)"), backgroundColor: Colors.red),
                  );
                  return;
                }

                Navigator.pop(context); 
                setState(() { _pendingAmount = amount; }); 
                _openRazorpay(amount); 
              }
            },
            child: const Text("Proceed", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _openRazorpay(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    final int? userId = prefs.getInt('user_id');

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User ID not found. Please login again.")),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator(color: brandPurple)),
    );

    try {
      final response = await http.post(
        Uri.parse("https://ttjnextgen.divasprik.in/ttj_api/create_order.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'amount': (amount * 100).toInt(), 
          'user_id': userId
        }),
      );

      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == 'success') {
          final String orderId = data['order_id'];

          var options = {
            'key': 'rzp_live_sQWAO2cxYeejCd', 
            'amount': (amount * 100).toInt(),
            'name': 'TTJ Next Gen Jewels',
            'description': 'Gold Wallet Top-Up',
            'order_id': orderId, 
            'theme': {'color': '#5D1F88'}
          };

          _razorpay.open(options);

        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Server Error: ${data['message']}"), backgroundColor: Colors.red),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to connect to server"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); 
      debugPrint('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Something went wrong opening Razorpay"), backgroundColor: Colors.red),
      );
    }
  }

  // --- FETCH WALLET DATA API ---

  Future<void> _fetchWalletData() async {
    final prefs = await SharedPreferences.getInstance();
    final int? userId = prefs.getInt('user_id');

    if (userId == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse("https://ttjnextgen.divasprik.in/ttj_api/get_wallet_data.php?user_id=$userId"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            totalGold = data['gold_balance'].toString();
            totalInvested = data['total_invested']?.toString() ?? "0.00";
            transactions = data['transactions']; 
            isLoading = false;
          });
        }
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching wallet data: $e");
      setState(() => isLoading = false);
    }
  }

  // --- UI BUILDER ---

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (context) => const WelcomeScreen())
          ),
        ),
        title: Text(
          lang.translate('gold_wallet_title') ?? "Gold Wallet", 
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: () {
              setState(() => isLoading = true);
              _fetchWalletData();
              _fetchLiveGoldRate();
            },
          )
        ],
      ),
      body: isLoading 
          ? Center(child: CircularProgressIndicator(color: brandPurple)) 
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. TOP CARDS
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          lang.translate('total_added') ?? "Total Added", 
                          "₹ $totalInvested", 
                          Icons.account_balance_wallet, 
                          Colors.purple.shade700
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildStatCard(
                          lang.translate('total_gold') ?? "Total Gold", 
                          "$totalGold g", 
                          Icons.monetization_on, 
                          Colors.amber
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // LIVE RATE DISPLAY
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade200)
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Today's 9k Gold Rate:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                        _isFetchingRate 
                          ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text("₹${_liveGoldRate.toStringAsFixed(2)}/g", style: TextStyle(fontWeight: FontWeight.bold, color: brandPurple, fontSize: 16)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. ADD MONEY BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 80,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cardPink,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        _showAmountDialog(); 
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline, color: brandPurple, size: 24),
                          const SizedBox(width: 10),
                          Text(
                            lang.translate('top_up_wallet') ?? "Top Up Wallet", 
                            style: TextStyle(color: brandPurple, fontSize: 18, fontWeight: FontWeight.bold)
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 3. RECENT TRANSACTIONS
                  Text(
                    lang.translate('recent_transactions') ?? "Recent Transactions", 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)
                  ),
                  const SizedBox(height: 15),

                  transactions.isEmpty
                      ? Container(
                          height: 200,
                          alignment: Alignment.center,
                          child: Text(
                            lang.translate('no_transactions') ?? "No transactions yet", 
                            style: const TextStyle(color: Colors.grey, fontSize: 16)
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: transactions.length,
                          itemBuilder: (context, index) {
                            final t = transactions[index];
                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: brandPurple.withOpacity(0.1),
                                  child: Icon(Icons.arrow_downward, color: brandPurple),
                                ),
                                title: Text(
                                  "${lang.translate('bought') ?? "Bought"} ${t['grams']} g", 
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                                ),
                                subtitle: Text(
                                  t['created_at'] ?? "", 
                                  style: const TextStyle(fontSize: 12, color: Colors.grey)
                                ),
                                trailing: Text(
                                  "+ ₹${t['amount']}",
                                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
      
      // 4. BOTTOM NAVIGATION BAR
      bottomNavigationBar: Container(
        height: 56,
        color: brandPurple,
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _navButton(Icons.home_outlined, () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()))),
              _navButton(Icons.swap_horiz, () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TransactionsScreen()))),
              _navButton(Icons.account_balance_wallet, () {}, isActive: true),
              _navButton(Icons.card_giftcard, () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RedemptionPage()))),
              _navButton(Icons.person_outline, () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ProfileScreen()))),
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildStatCard(String title, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      height: 100,
      decoration: BoxDecoration(
        color: cardPink,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: TextStyle(color: brandPurple, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 6),
              Text(value, style: TextStyle(color: brandPurple, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navButton(IconData icon, VoidCallback onPressed, {bool isActive = false}) {
    return IconButton(
      icon: Icon(icon, color: isActive ? Colors.white : Colors.white70, size: 28),
      onPressed: onPressed,
    );
  }
}