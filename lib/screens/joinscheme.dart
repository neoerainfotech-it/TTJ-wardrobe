import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Navigation Screens
import 'welcome.dart';
import 'transactions.dart'; 
import 'redemption.dart';   
import 'profile.dart';      

// WE IMPORT KYC NOW SO WE CAN PASS THE BATON TO THE PAYMENT SCREEN
import 'kyc.dart'; 

class GoldSchemeScreen extends StatefulWidget {
  final bool isFromPayNow;
  
  // NEW: Catching the full shopping cart from the User Photo screen!
  final Map<String, dynamic> schemeData;

  const GoldSchemeScreen({super.key, this.isFromPayNow = false, required this.schemeData});

  @override
  State<GoldSchemeScreen> createState() => _GoldSchemeScreenState();
}

class _GoldSchemeScreenState extends State<GoldSchemeScreen> {
  static const Color brandPurple = Color(0xFF5D1F88);

  double goldRate9K = 0.0;
  String maturityDate = "Calculating...";
  bool _isLoadingRate = true;
  bool _showInitialPaymentStep = false;
  bool _isTargetLocked = false; 
  bool _isSubsequentPayment = false; 

  final TextEditingController _weightController = TextEditingController(text: '1');
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _initialPayController = TextEditingController(text: '1000');

  String _calculatedInitialWeight = "0.000";

  @override
  void initState() {
    super.initState();
    _fetch9KRateAndMaturity();
    _checkIfTargetIsLocked();

    if (widget.isFromPayNow) {
      _showInitialPaymentStep = true;
    }

    _updateInitialWeightCalculation(_initialPayController.text);
  }

  void _updateInitialWeightCalculation(String value) {
    double amount = double.tryParse(value) ?? 0.0;
    if (goldRate9K > 0 && amount > 0) {
      setState(() {
        _calculatedInitialWeight = (amount / goldRate9K).toStringAsFixed(3);
      });
    } else {
      setState(() {
        _calculatedInitialWeight = "0.000";
      });
    }
  }

  Future<void> _checkIfTargetIsLocked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int? userId = prefs.getInt('user_id');
      if (userId == null) return;

      final response = await http.get(
        Uri.parse("https://ttjnextgen.divasprik.in/ttj_api/get_enrollment_status.php?user_id=$userId")
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          String schemeStatus = data['scheme_status'] ?? "";
          var paidValue = data['total_amount_paid'];
          double totalPaid = (paidValue is num) ? paidValue.toDouble() : double.tryParse(paidValue.toString()) ?? 0.0;

          if (totalPaid > 0 && (schemeStatus == "Active" || schemeStatus == "Pending")) {
            setState(() {
              _isTargetLocked = true;
              _isSubsequentPayment = true; 
              _weightController.text = data['target_weight']?.toString() ?? "1";
              _amountController.text = data['target_amount']?.toString() ?? "0";
              _showInitialPaymentStep = true;
              _initialPayController.text = "100"; 
              _updateInitialWeightCalculation("100");
            });
          } else {
            setState(() {
              _isTargetLocked = false;
              _isSubsequentPayment = false;
              _showInitialPaymentStep = false;
              _weightController.text = "1";
              _initialPayController.text = "1000";
              _updateInitialWeightCalculation("1000");
              _updateAmountFromWeight();
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error checking target lock: $e");
    }
  }

  Future<void> _fetch9KRateAndMaturity() async {
    try {
      final response = await http.get(
        Uri.parse('https://ttjnextgen.divasprik.in/ttj_api/get_9k_rate.php'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['rate_9k'] != null) {
          setState(() {
            goldRate9K = (data['rate_9k'] as num).toDouble();
            _isLoadingRate = false;
          });
          if (!_isTargetLocked) _updateAmountFromWeight();
          _updateInitialWeightCalculation(_initialPayController.text);
        }
      }
    } catch (e) {
      setState(() {
        goldRate9K = 5273.25;
        _isLoadingRate = false;
      });
      if (!_isTargetLocked) _updateAmountFromWeight();
      _updateInitialWeightCalculation(_initialPayController.text);
    }

    final now = DateTime.now();
    final maturity = now.add(const Duration(days: 330));
    setState(() {
      maturityDate = DateFormat('dd-MMM-yyyy').format(maturity);
    });
  }

  @override
  void dispose() {
    _weightController.dispose();
    _amountController.dispose();
    _initialPayController.dispose();
    super.dispose();
  }

  void _updateAmountFromWeight() {
    if (_isTargetLocked) return;
    int weight = int.tryParse(_weightController.text) ?? 1;

    if (weight > 500) {
      weight = 500;
      _weightController.text = "500";
      Fluttertoast.showToast(msg: "Maximum limit is 500 grams");
    }

    final int amount = (weight * goldRate9K).round();
    _amountController.text = amount.toString();
  }

  void _updateWeightFromAmount() {
    if (_isTargetLocked) return;
    final int amount = int.tryParse(_amountController.text) ?? 0;
    if (amount == 0) return;
    int weight = (amount / goldRate9K).round();

    if (weight > 500) {
      weight = 500;
      Fluttertoast.showToast(msg: "Maximum limit is 500 grams");
    }

    if (weight >= 1) {
      _weightController.text = weight.toString();
      if (weight == 500) {
        _amountController.text = (500 * goldRate9K).round().toString();
      }
    }
  }

  void _incrementWeight() {
    if (_isTargetLocked) return;
    final int weight = int.tryParse(_weightController.text) ?? 1;
    if (weight < 500) {
      _weightController.text = (weight + 1).toString();
      _updateAmountFromWeight();
    } else {
      Fluttertoast.showToast(msg: "Maximum limit is 500 grams");
    }
  }

  void _decrementWeight() {
    if (_isTargetLocked) return;
    final int weight = int.tryParse(_weightController.text) ?? 1;
    if (weight > 1) {
      _weightController.text = (weight - 1).toString();
      _updateAmountFromWeight();
    }
  }

  void _goToNextStep() {
    final int? paymentAmount = int.tryParse(_initialPayController.text);
    int minRequired = _isSubsequentPayment ? 100 : 1000;

    if (paymentAmount == null || paymentAmount < minRequired) {
      Fluttertoast.showToast(msg: "Minimum payment must be at least ₹$minRequired");
      return;
    }

    // Pack the final Target info into the cart that already contains all the KYC!
    Map<String, dynamic> finalCart = Map.from(widget.schemeData);
    finalCart["grams"] = int.tryParse(_weightController.text) ?? 1;
    finalCart["target_amount"] = int.tryParse(_amountController.text) ?? 0;
    finalCart["initial_payment"] = paymentAmount;

    // Pass the fully loaded cart to the Review & Pay Screen!
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KycCompletedPage(schemeData: finalCart),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text(_showInitialPaymentStep ? (_isSubsequentPayment ? "Payment" : "Initial Payment") : "Set Target",
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoadingRate
          ? const Center(child: CircularProgressIndicator(color: brandPurple))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                children: [
                  _buildRateCard(),
                  const SizedBox(height: 30),
                  if (!_showInitialPaymentStep) ...[
                    Row(
                      children: [
                        Expanded(child: _buildWeightCard()),
                        const SizedBox(width: 15),
                        Expanded(child: _buildAmountCard()),
                      ],
                    ),
                    const SizedBox(height: 40),
                    Text("Date of Maturity: $maturityDate", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: brandPurple)),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: () => setState(() => _showInitialPaymentStep = true),
                        style: ElevatedButton.styleFrom(backgroundColor: brandPurple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                        child: const Text("Join Scheme", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ] else ...[
                    _buildInitialPayCard(),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _goToNextStep,
                        style: ElevatedButton.styleFrom(backgroundColor: brandPurple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                        // CHANGED BUTTON TEXT HERE
                        child: const Text("Next: Review & Pay", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    if (!_isTargetLocked)
                      TextButton(onPressed: () => setState(() => _showInitialPaymentStep = false), child: const Text("Edit Target", style: TextStyle(color: Colors.grey)))
                  ],
                ],
              ),
            ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildInitialPayCard() {
    return Card(
      color: const Color(0xFFE8F5E9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(_isSubsequentPayment ? "Enter Your Amount" : "Enter Initial Payment", 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
            const SizedBox(height: 10),
            Text(_isSubsequentPayment ? "Min payment: ₹100" : "Min payment: ₹1000", 
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            TextField(
              controller: _initialPayController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              onChanged: (v) => _updateInitialWeightCalculation(v),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: brandPurple),
              decoration: const InputDecoration(prefixText: "₹", border: InputBorder.none),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "Estimated Weight: $_calculatedInitialWeight gram",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRateCard() {
    return Card(
      elevation: 5, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          SizedBox(height: 50, width: 50, child: Image.asset('assets/gold_coin.jpeg', fit: BoxFit.contain)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text("Gold Rate 9KT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: brandPurple)),
              Text("LIVE RATE", style: TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
            const SizedBox(height: 10),
            Text("₹ ${goldRate9K.toInt()} / gram", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: brandPurple)),
          ]))
        ]),
      ),
    );
  }

  Widget _buildWeightCard() {
    return Card(
      color: const Color(0xFFFCE4EC), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Weight", style: TextStyle(fontWeight: FontWeight.bold, color: brandPurple)),
        const SizedBox(height: 12),
        Row(children: [
          const Text("gram", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: brandPurple)),
          const SizedBox(width: 12),
          Expanded(child: TextField(
            controller: _weightController,
            keyboardType: TextInputType.number,
            enabled: !_isTargetLocked,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(border: InputBorder.none),
            onChanged: (v) => _updateAmountFromWeight(),
          )),
          if (!_isTargetLocked)
            Column(children: [
              InkWell(onTap: _incrementWeight, child: const Icon(Icons.add_box, color: brandPurple, size: 30)),
              const SizedBox(height: 8),
              InkWell(onTap: _decrementWeight, child: const Icon(Icons.indeterminate_check_box, color: brandPurple, size: 30)),
            ])
        ])
      ])),
    );
  }

  Widget _buildAmountCard() {
    return Card(
      color: const Color(0xFFFCE4EC), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Amount", style: TextStyle(fontWeight: FontWeight.bold, color: brandPurple)),
        const SizedBox(height: 12),
        Row(children: [
          const Text("₹", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: brandPurple)),
          const SizedBox(width: 12),
          Expanded(child: TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            enabled: !_isTargetLocked,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(border: InputBorder.none),
            onChanged: (v) => _updateWeightFromAmount(),
          )),
        ])
      ])),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 60,
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
    );
  }

  Widget _navButton(IconData icon, VoidCallback onPressed, {bool isActive = false}) {
    return IconButton(
      icon: Icon(icon, color: isActive ? Colors.white : Colors.white70, size: 28),
      onPressed: onPressed,
    );
  }
}