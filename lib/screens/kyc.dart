import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

import 'welcome.dart'; 

class KycCompletedPage extends StatefulWidget {
  final Map<String, dynamic> schemeData;

  const KycCompletedPage({super.key, required this.schemeData});

  @override
  State<KycCompletedPage> createState() => _KycCompletedPageState();
}

class _KycCompletedPageState extends State<KycCompletedPage> {
  late Razorpay _razorpay;
  bool _isProcessing = false;
  String _loadingText = "Processing...";

  final TextEditingController _gramsController = TextEditingController();
  double _currentGrams = 0.0;

  double _liveGoldRate = 0.0;
  bool _isFetchingRate = true;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    
    // Listeners for mobile app
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse response) {});

    if (widget.schemeData['grams'] != null && widget.schemeData['grams'].toString().isNotEmpty) {
      _gramsController.text = widget.schemeData['grams'].toString();
      _currentGrams = double.tryParse(_gramsController.text) ?? 0.0;
    }

    _fetchLiveGoldRate();
  }

  @override
  void dispose() {
    _razorpay.clear();
    _gramsController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveGoldRate() async {
    try {
      final response = await http.get(Uri.parse("https://ttjnextgen.divasprik.in/ttj_api/get_market_rates.php"));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // 9k gold rate active
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

  void _showMessage(String msg, {bool isError = true}) {
    Fluttertoast.showToast(
      msg: msg,
      backgroundColor: isError ? Colors.red : Colors.green,
      toastLength: Toast.LENGTH_LONG,
    );
  }

  Future<void> _startPaymentFlow() async {
    if (_currentGrams <= 0) {
      _showMessage("Please enter your Target Weight in grams.");
      return;
    }

    if (_isFetchingRate || _liveGoldRate <= 0) {
      _showMessage("Please wait for the live gold rate to load.");
      return;
    }

    setState(() {
      _isProcessing = true;
      _loadingText = "Initiating Payment...";
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final int userId = prefs.getInt('user_id') ?? 0;
      final String userEmail = prefs.getString('user_email') ?? "customer@example.com";

      final int paymentAmount = int.tryParse(widget.schemeData['initial_payment']?.toString() ?? '1000') ?? 1000;
      final int dynamicTargetAmount = (_currentGrams * _liveGoldRate).toInt();

      final response = await http.post(
        Uri.parse("https://ttjnextgen.divasprik.in/ttj_api/create_join_razorpay.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "amount": paymentAmount,
          "grams": _currentGrams, 
          "target_amount": dynamicTargetAmount,
          "applied_gold_rate": _liveGoldRate, 
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        _openCheckout(data['order_id'], data['amount'], userEmail);
      } else {
        _showMessage("Order failed: ${data['message']}");
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      _showMessage("Network error while creating payment");
      setState(() => _isProcessing = false);
    }
  }

  void _openCheckout(String orderId, dynamic amountInPaise, String email) {
    int finalAmount = 0;
    try {
      if (amountInPaise is num) {
        finalAmount = amountInPaise.toInt();
      } else if (amountInPaise is String) {
        finalAmount = double.parse(amountInPaise).toInt();
      }
    } catch (e) {
      _showMessage("Invalid amount format received");
      setState(() => _isProcessing = false);
      return;
    }

    // Cleaned up Mobile-Only Logic
    var options = {
      'key': 'rzp_live_sQWAO2cxYeejCd',
      'amount': finalAmount,
      'name': 'TTJ Nextgen Jewels',
      'order_id': orderId,
      'description': 'Scheme Initial Payment & KYC',
      'prefill': {'contact': '9876543210', 'email': email},
      'theme': {'color': '#5D1F88'},
      'timeout': 60,
      'send_sms_hash': true,
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint("Razorpay Opening Error: $e");
      setState(() => _isProcessing = false);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    setState(() {
      _isProcessing = true;
      _loadingText = "Payment Verified! Saving details... Please do not close the app.";
    });

    final prefs = await SharedPreferences.getInstance();
    final int userId = prefs.getInt('user_id') ?? 0;

    try {
      final verifyResponse = await http.post(
        Uri.parse("https://ttjnextgen.divasprik.in/ttj_api/verify_join_razorpay.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "order_id": response.orderId,
          "razorpay_payment_id": response.paymentId,
          "razorpay_signature": response.signature,
          "user_id": userId,
        }),
      );

      final verifyData = jsonDecode(verifyResponse.body);
      
      if (verifyData['status'] == 'success') {
        await Future.wait([
          _uploadBankDetails(userId),
          _uploadKycDocument(userId, 'aadhar_file', widget.schemeData['aadhar_file']),
          _uploadKycDocument(userId, 'pancard_file', widget.schemeData['pan_file']),
          _uploadKycDocument(userId, 'profile_photo', widget.schemeData['user_photo']),
        ]);

        _showMessage("Enrollment Completed Successfully!", isError: false);

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false
        );
      } else {
        _showMessage("Verification failed: ${verifyData['message']}");
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      _showMessage("Error saving data: $e");
      setState(() => _isProcessing = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) async {
    _showMessage("Payment Failed/Cancelled. Deleting draft...", isError: true);
    setState(() => _isProcessing = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final int userId = prefs.getInt('user_id') ?? 0;

      // Tell the server to delete the 'Pending' row since payment failed
      await http.post(
        Uri.parse("https://ttjnextgen.divasprik.in/ttj_api/delete_pending_enrollment.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": userId}),
      );
    } catch (e) {
      debugPrint("Failed to delete pending row: $e");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _uploadBankDetails(int userId) async {
    try {
      await http.post(
        Uri.parse("https://ttjnextgen.divasprik.in/ttj_api/save_bank_details.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "account_number": widget.schemeData['account_number'],
          "bank_name": widget.schemeData['bank_name'],
          "ifsc_code": widget.schemeData['ifsc_code'],
          "account_type": widget.schemeData['account_type'],
        }),
      );
    } catch (e) {
      debugPrint("Bank Upload Error: $e");
    }
  }

  Future<void> _uploadKycDocument(int userId, String fieldName, dynamic fileObj) async {
    if (fileObj == null) return;
    try {
      var request = http.MultipartRequest('POST', Uri.parse("https://ttjnextgen.divasprik.in/ttj_api/upload_kyc_document.php"));
      request.fields['user_id'] = userId.toString();
      http.MultipartFile multipartFile;

      if (fileObj is PlatformFile) {
        if (kIsWeb) {
          multipartFile = http.MultipartFile.fromBytes(fieldName, fileObj.bytes!, filename: fileObj.name);
        } else {
          multipartFile = await http.MultipartFile.fromPath(fieldName, fileObj.path!, filename: fileObj.name);
        }
      } 
      else if (fileObj is XFile) {
        if (kIsWeb) {
          final bytes = await fileObj.readAsBytes();
          multipartFile = http.MultipartFile.fromBytes(fieldName, bytes, filename: 'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
        } else {
          multipartFile = await http.MultipartFile.fromPath(fieldName, fileObj.path, filename: fileObj.name);
        }
      } else {
        return; 
      }

      request.files.add(multipartFile);
      await request.send();
    } catch (e) {
      debugPrint("File Upload Error ($fieldName): $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final int paymentAmount = int.tryParse(widget.schemeData['initial_payment']?.toString() ?? '1000') ?? 1000;
    
    final double totalEstimatedValue = _currentGrams * _liveGoldRate;

    String displayGoldRate;
    if (_isFetchingRate) {
      displayGoldRate = "Fetching Live Rate...";
    } else if (_liveGoldRate > 0) {
      displayGoldRate = "₹${_liveGoldRate.toStringAsFixed(2)}/g";
    } else {
      displayGoldRate = "Rate unavailable";
    }

    String displayTotalValue;
    if (_isFetchingRate) {
      displayTotalValue = "Calculating...";
    } else if (_currentGrams <= 0) {
      displayTotalValue = "Enter weight to calculate";
    } else if (_liveGoldRate > 0) {
      displayTotalValue = "₹${totalEstimatedValue.toStringAsFixed(2)}*";
    } else {
      displayTotalValue = "N/A";
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Final Review & Pay", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF5D1F88),
        elevation: 0,
      ),
      body: _isProcessing
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF5D1F88)),
                    const SizedBox(height: 25),
                    Text(
                      _loadingText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF5D1F88)),
                    ),
                  ],
                ),
              ),
            )
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.receipt_long, color: Color(0xFF5D1F88), size: 80),
                    const SizedBox(height: 15),
                    const Text('READY TO ENROLL',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF5D1F88))),
                    const SizedBox(height: 10),
                    const Text(
                      'Enter your target weight and review your scheme details.',
                      textAlign: TextAlign.center, 
                      style: TextStyle(color: Colors.grey, fontSize: 14)
                    ),
                    const SizedBox(height: 25),
                    
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Target Weight:", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
                              SizedBox(
                                width: 110,
                                child: TextFormField(
                                  controller: _gramsController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF5D1F88)),
                                  decoration: InputDecoration(
                                    hintText: "e.g. 10",
                                    hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5), fontSize: 16),
                                    suffixText: "g",
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(color: Color(0xFF5D1F88), width: 2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      _currentGrams = double.tryParse(value) ?? 0.0;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 25),
                          
                          _buildSummaryRow(
                            "Today's 9k Gold Rate:", 
                            displayGoldRate, 
                            color: _isFetchingRate ? Colors.grey : Colors.orange.shade800
                          ),
                          const SizedBox(height: 10),
                          
                          _buildSummaryRow("Total Estimated Value:", displayTotalValue, isBold: true),
                          const Divider(height: 25),
                          
                          _buildSummaryRow("KYC Documents:", "Ready to Upload", color: Colors.green),
                          const Divider(height: 25, color: Color(0xFF5D1F88), thickness: 1),
                          
                          _buildSummaryRow("Initial Pay Now:", "₹$paymentAmount", isBold: true, color: const Color(0xFF5D1F88), valueSize: 22),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 15),
                    
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200)
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange.shade800, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              "*The Total Estimated Value is based on today's rate. Your balance weight will be purchased at the actual live daily gold rate at the time of your future installments.",
                              style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _isFetchingRate ? null : _startPaymentFlow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5D1F88),
                        disabledBackgroundColor: Colors.grey.shade400,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('PAY ₹$paymentAmount & FINISH',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? color, double valueSize = 16}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        Text(value, style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.w600, 
          fontSize: valueSize,
          color: color ?? Colors.black87
        )),
      ],
    );
  }
}