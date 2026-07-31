import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// WE ADDED THIS TO PASS THE BATON TO THE NEXT SCREEN (User Photo)
import 'user_photo.dart';

const Color primaryPurple = Color(0xFF5D1F88);

class BankDetailsPage extends StatefulWidget {
  // NEW: Catching the data from the PAN Card screen!
  final Map<String, dynamic> schemeData;

  const BankDetailsPage({super.key, required this.schemeData});

  @override
  State<BankDetailsPage> createState() => _BankDetailsPageState();
}

class _BankDetailsPageState extends State<BankDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _confirmAccountController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _ifscController = TextEditingController();
  String? _selectedAccountType;
  bool _isSubmitting = false;

  void _onSubmit() {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      // FIXED: NO DATABASE CALL!
      // We pack the new Bank info into our "Shopping Cart" and pass it forward to User Photo.
      Map<String, dynamic> updatedSchemeData = Map.from(widget.schemeData);
      updatedSchemeData['account_number'] = _accountNumberController.text.trim();
      updatedSchemeData['bank_name'] = _bankNameController.text.trim();
      updatedSchemeData['ifsc_code'] = _ifscController.text.toUpperCase().trim();
      updatedSchemeData['account_type'] = _selectedAccountType;

      setState(() => _isSubmitting = false);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserPhotoPage(schemeData: updatedSchemeData),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Bank Details',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryPurple,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Bank Account Info",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryPurple)),
              const SizedBox(height: 8),
              const Text("Please enter your bank account details for verification.",
                  style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 25),

              _buildTextField(_accountNumberController, 'Account Number', '18 Digits',
                  TextInputType.number, [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(18)]),

              const SizedBox(height: 15),
              _buildTextField(_confirmAccountController, 'Confirm Account Number', 'Repeat Account Number',
                  TextInputType.number, [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(18)],
                  isConfirm: true),

              const SizedBox(height: 15),
              _buildTextField(_bankNameController, 'Bank Name', 'e.g. HDFC Bank',
                  TextInputType.text, [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))]),

              const SizedBox(height: 15),
              // IFSC Field - Now auto-uppercase + accepts lowercase input
              _buildTextField(_ifscController, 'IFSC Code', 'ABCD0123456',
                  TextInputType.text,
                  [
                    LengthLimitingTextInputFormatter(11),
                    UpperCaseTextFormatter(), // Custom formatter to convert to uppercase
                  ],
                  isIFSC: true),

              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                initialValue: _selectedAccountType,
                decoration: _inputDecoration('Account Type'),
                items: ['Savings', 'Current'].map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                onChanged: (v) => setState(() => _selectedAccountType = v),
                validator: (v) => (v == null) ? 'Please select account type' : null,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPurple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('NEXT: UPLOAD PHOTO',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint, TextInputType type,
      List<TextInputFormatter> formatters, {bool isConfirm = false, bool isIFSC = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      inputFormatters: formatters,
      decoration: _inputDecoration(label).copyWith(hintText: hint),
      validator: (v) {
        if (v == null || v.isEmpty) return 'This field is required';
        if (isConfirm && v != _accountNumberController.text) return 'Account numbers do not match';
        if (isIFSC) {
          final upper = v.toUpperCase();
          if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(upper)) {
            return 'Invalid IFSC format (e.g., SBIN0001234)';
          }
        }
        return null;
      },
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: primaryPurple),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: primaryPurple, width: 2), borderRadius: BorderRadius.circular(10)),
    );
  }
}

// Custom TextInputFormatter to convert input to uppercase in real-time
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}