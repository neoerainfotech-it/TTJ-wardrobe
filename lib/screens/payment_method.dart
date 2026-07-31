import 'package:flutter/material.dart';
//import 'add_card.dart';  
//import 'bank_selection';      // Ensure this file exists
 // Ensure this file exists

class PaymentMethodScreen extends StatefulWidget {
  const PaymentMethodScreen({super.key});

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  final TextEditingController _upiController = TextEditingController();
  bool _isVerifyEnabled = false;

  // Strict UPI Validation: alphanumeric + @ + bank handle
  void _validateUpi(String value) {
    // Regex for valid UPI: standard characters + @ + bank (e.g., name@bank)
    final bool isValid = RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$').hasMatch(value);
    setState(() {
      _isVerifyEnabled = isValid;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Payment Method",
                style: TextStyle(
                  color: Color(0xFF673AB7),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                "Select Payment Method",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 20),

              // 1. Debit/Credit Card -> Redirects to AddCardScreen
              //_buildPaymentOption(
               // Icons.credit_card, 
               // "Debit / Credit Card", 
                //() => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddCardScreen()))
             // ),
              
              // 2. Net Banking -> Redirects to BankSelectionScreen
              //_buildPaymentOption(
              //  Icons.account_balance, 
                //"Net Banking", 
                //() => Navigator.push(context, MaterialPageRoute(builder: (context) => const BankSelectionScreen()))
             // ),
              
        
              // 3. UPI Section
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ExpansionTile(
                  initiallyExpanded: true,
                  leading: const Icon(Icons.currency_rupee, color: Color(0xFF1976D2)),
                  title: const Text("UPI", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Choose App", style: TextStyle(fontSize: 12, color: Colors.black54)),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildAppIcon("GPay", "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c7/Google_Pay_Logo_%282020%29.svg/512px-Google_Pay_Logo_%282020%29.svg.png"),
                              _buildAppIcon("Paytm", "https://upload.wikimedia.org/wikipedia/commons/thumb/2/24/Paytm_Logo_%28standalone%29.svg/512px-Paytm_Logo_%28standalone%29.svg.png"),
                              _buildAppIcon("PhonePe", "https://upload.wikimedia.org/wikipedia/commons/thumb/7/71/PhonePe_Logo.svg/512px-PhonePe_Logo.svg.png"),
                              _buildAppIcon("Amazon", "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a9/Amazon_logo.svg/1024px-Amazon_logo.svg.png"),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text("Enter UPI ID", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _upiController,
                                  onChanged: _validateUpi,
                                  decoration: InputDecoration(
                                    hintText: "Enter UPI ID (e.g. name@bank)",
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: _isVerifyEnabled ? () {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("UPI ID Verified!")));
                                } : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isVerifyEnabled ? const Color(0xFF673AB7) : Colors.grey.shade300,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text("Verify"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const CustomBottomNavBar(), // Using the new Footer
    );
  }

  Widget _buildPaymentOption(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF1976D2)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF0D47A1))),
        trailing: const Icon(Icons.keyboard_arrow_down),
        onTap: onTap,
      ),
    );
  }

  Widget _buildAppIcon(String name, String url) {
    return GestureDetector(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Opening $name..."))),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Image.network(url, height: 25, width: 40, fit: BoxFit.contain),
      ),
    );
  }
}

// Updated Bottom Nav (No TTJ circle, adds Wallet icon)
class CustomBottomNavBar extends StatelessWidget {
  const CustomBottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: const BoxDecoration(
        color: Color(0xFF673AB7),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Icon(Icons.home_outlined, color: Colors.white, size: 28),
          Icon(Icons.swap_horiz, color: Colors.white, size: 28),
          Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 28),
          Icon(Icons.card_giftcard, color: Colors.white, size: 28),
          Icon(Icons.person_outline, color: Colors.white, size: 28),
        ],
      ),
    );
  }
}