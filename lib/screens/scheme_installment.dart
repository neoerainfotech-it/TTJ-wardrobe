import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class SchemeInstallmentScreen extends StatefulWidget {
  const SchemeInstallmentScreen({super.key});

  @override
  State<SchemeInstallmentScreen> createState() => _SchemeInstallmentScreenState();
}

class _SchemeInstallmentScreenState extends State<SchemeInstallmentScreen> {
  static const String _baseUrl = "https://ttjnextgen.divasprik.in/ttj_api/";
  
  final Color brandPurple = const Color(0xFF5D1F88);
  final Color goldYellow = const Color(0xFFFFD700);

  final TextEditingController _amountController = TextEditingController();
  late Razorpay _razorpay;

  bool _isLoading = true;
  bool _isProcessingPayment = false;
  
  Map<String, dynamic>? _enrollmentData;
  List<dynamic> _paymentHistory = [];
  int? _userId;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _fetchData();
  }

  @override
  void dispose() {
    _razorpay.clear();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('user_id');

    if (_userId == null) return;

    try {
      final resStatus = await http.get(Uri.parse("${_baseUrl}get_enrollment_status.php?user_id=$_userId"));
      final resHistory = await http.get(Uri.parse("${_baseUrl}get_scheme_history.php?user_id=$_userId"));

      if (resStatus.statusCode == 200 && resHistory.statusCode == 200) {
        final dataStatus = jsonDecode(resStatus.body);
        final dataHistory = jsonDecode(resHistory.body);
        
        if (mounted) {
          setState(() {
            _enrollmentData = dataStatus;
            _paymentHistory = dataHistory['data'] ?? [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Fetch error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- RAZORPAY PAYMENT LOGIC ---
  Future<void> _startPayment() async {
    double amount = double.tryParse(_amountController.text) ?? 0;
    if (amount < 100) {
      _showMessage("Minimum payment is ₹100", Colors.orange);
      return;
    }

    setState(() => _isProcessingPayment = true);

    try {
      final orderRes = await http.post(
        Uri.parse("${_baseUrl}create_join_razorpay.php"),
        body: jsonEncode({
          "user_id": _userId,
          "amount": amount,
          "target_amount": 0, 
          "grams": 0 
        }),
      );

      final orderData = jsonDecode(orderRes.body);
      if (orderData['status'] == 'success') {
        var options = {
          'key': "rzp_live_sQWAO2cxYeejCd", 
          'amount': orderData['amount'],
          'name': 'TTJ Next Gen Jewels',
          'description': 'Scheme Installment Payment',
          'order_id': orderData['order_id'],
          'prefill': {'contact': '', 'email': ''},
          'theme': {'color': '#5D1F88'}
        };
        _razorpay.open(options);
      } else {
        _showMessage("Error creating order", Colors.red);
        setState(() => _isProcessingPayment = false);
      }
    } catch (e) {
      _showMessage("Network error. Try again.", Colors.red);
      setState(() => _isProcessingPayment = false);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      final res = await http.post(
        Uri.parse("${_baseUrl}verify_join_razorpay.php"),
        body: jsonEncode({
          "user_id": _userId,
          "order_id": response.orderId,
          "razorpay_payment_id": response.paymentId
        }),
      );

      final result = jsonDecode(res.body);
      if (result['status'] == 'success') {
        _showMessage("Payment Successful! Gold added to your scheme.", Colors.green);
        _amountController.clear();
        setState(() => _isLoading = true);
        _fetchData();
      } else {
        _showMessage(result['message'] ?? "Error saving payment.", Colors.red);
      }
    } catch (e) {
      _showMessage("Failed to update database.", Colors.red);
    } finally {
      setState(() => _isProcessingPayment = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _showMessage("Payment Failed or Cancelled", Colors.red);
    setState(() => _isProcessingPayment = false);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    setState(() => _isProcessingPayment = false);
  }

  void _showMessage(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(backgroundColor: brandPurple, title: const Text("Pay Installment")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    String totalPaid = _enrollmentData?['total_amount_paid']?.toString() ?? "0.00";
    
    // 🚀 Strips unit letters from API and keeps only numeric value
    String rawGold = _enrollmentData?['total_gold_saved']?.toString() ?? "0.000";
    String goldEarned = rawGold.replaceAll(RegExp(r'[^\d.]'), '').trim();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: brandPurple,
        foregroundColor: Colors.white,
        title: Text("Pay Installment", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SCHEME SUMMARY CARD ---
            Card(
              elevation: 4,
              color: brandPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Total Amount Paid", style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text("₹$totalPaid", style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text("Total Gold Saved", style: TextStyle(color: Colors.white70, fontSize: 12)),
                        // 🚀 Changed unit label to 'gm'
                        Text("$goldEarned gm", style: GoogleFonts.inter(color: goldYellow, fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // --- PAYMENT ENTRY SECTION ---
            Text("Enter Payment Amount", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: brandPurple)),
            const SizedBox(height: 10),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.currency_rupee),
                hintText: "Enter amount (Min ₹100)",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: brandPurple, width: 2), borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),

            // --- PAY NOW BUTTON ---
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandPurple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isProcessingPayment ? null : _startPayment,
                child: _isProcessingPayment
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text("PROCEED TO PAY", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 40),

            // --- REAL HISTORY SECTION ---
            Text("Payment History", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 10),
            
            _paymentHistory.isEmpty 
              ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No payments found yet.")))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _paymentHistory.length,
                  itemBuilder: (context, index) {
                    final item = _paymentHistory[index];
                    
                    // 🚀 Replaces 'gg', 'g', 'gram', 'grams', or 'garms' in the API history text with 'gm'
                    String detailsText = item['details']
                        ?.toString()
                        .replaceAll(RegExp(r'\b(gg|g|gram|grams|garms)\b', caseSensitive: false), 'gm') ?? '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.account_balance_wallet, color: Colors.green, size: 20),
                        ),
                        title: Text(
                          item['amount'].toString(), 
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: brandPurple),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(detailsText, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                            const SizedBox(height: 2),
                            Text(item['date'].toString(), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        trailing: const Icon(Icons.check_circle, color: Colors.green, size: 18),
                      ),
                    );
                  },
                ),
          ],
        ),
      ),
    );
  }
}