import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'pancard_upload.dart'; // WE ARE PASSING THE BATON HERE NEXT

const Color primaryPurple = Color(0xFF673AB7);
const Color lightGreyBackground = Color(0xFFF8F9FA);

class AadharInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.replaceAll(RegExp(r'\s'), '');
    if (text.length > 12) text = text.substring(0, 12);
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i + 1) % 4 == 0 && (i + 1) != text.length) buffer.write(' ');
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

class AadharUploadPage extends StatefulWidget {
  // NEW: Catching the data from the previous screen!
  final Map<String, dynamic> schemeData;

  const AadharUploadPage({super.key, required this.schemeData});

  @override
  State<AadharUploadPage> createState() => _AadharUploadPageState();
}

class _AadharUploadPageState extends State<AadharUploadPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _aadharController = TextEditingController();

  PlatformFile? _aadharFile;
  bool _isConsentChecked = false;
  bool _isUploading = false;

  bool _isInvalidPattern(String input) {
    if (input.isEmpty) return false;
    return input.split('').every((char) => char == input[0]);
  }

  Future<bool> _verifyAadharDocument(PlatformFile file, String number) async {
    if (kIsWeb) return true;
    if (file.path == null) return false;

    final inputImage = InputImage.fromFilePath(file.path!);
    final recognizer = TextRecognizer();

    try {
      final recognized = await recognizer.processImage(inputImage);
      String cleanNumber = number.replaceAll(RegExp(r'\s+'), '');
      String digits = '';
      for (var block in recognized.blocks) {
        for (var line in block.lines) {
          digits += line.text.replaceAll(RegExp(r'[^0-9]'), '');
        }
      }
      await recognizer.close();
      return digits.contains(cleanNumber);
    } catch (e) {
      await recognizer.close();
      return file.extension?.toLowerCase() == 'pdf';
    }
  }

  void _showSnackbar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _validateAndSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_aadharFile == null) {
      _showSnackbar('Please upload your Aadhar document');
      return;
    }

    if (!_isConsentChecked) {
      _showSnackbar('Please give consent');
      return;
    }

    setState(() => _isUploading = true);

    bool ocrOk = await _verifyAadharDocument(_aadharFile!, _aadharController.text);
    if (!ocrOk) {
      _showSnackbar('Aadhar number not detected in image. Try a clearer photo.');
      setState(() => _isUploading = false);
      return;
    }

    // FIXED: NO DATABASE CALL! 
    // We just pack the new Aadhar info into our "Shopping Cart" and pass it forward.
    Map<String, dynamic> updatedSchemeData = Map.from(widget.schemeData);
updatedSchemeData['aadhar_number'] = _aadharController.text;
updatedSchemeData['aadhar_file'] = _aadharFile;

Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => PanCardStep(schemeData: updatedSchemeData))
);  
  }

  Future<void> _pickDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (result != null && result.files.isNotEmpty) {
        PlatformFile file = result.files.first;

        if (file.size > 1024 * 1024) {
          _showSnackbar('File too large. Max 1MB allowed.');
          return;
        }

        setState(() => _aadharFile = file);
      }
    } catch (e) {
      _showSnackbar('Failed to pick file');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGreyBackground,
      appBar: AppBar(
        centerTitle: true,
        title: const Text("KYC Verification", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: primaryPurple,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Form(
            key: _formKey,
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Aadhar Card Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryPurple)),
                    const SizedBox(height: 8),
                    const Text("Upload a clear image (PNG/JPG/PDF) of your Aadhar.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const Divider(height: 30),

                    _buildLabel("Aadhar Card Number"),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _aadharController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, AadharInputFormatter()],
                      decoration: const InputDecoration(hintText: '1234 5678 9012', border: OutlineInputBorder()),
                      validator: (value) {
                        String num = value?.replaceAll(' ', '') ?? '';
                        if (num.isEmpty) return 'Required';
                        if (num.length != 12) return 'Must be 12 digits';
                        if (_isInvalidPattern(num)) return 'Invalid pattern';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    _buildLabel("Upload Aadhar Document"),
                    const SizedBox(height: 8),
                    _uploadBox(_aadharFile, _pickDocument, "Upload Document (Max 1MB)"),

                    const SizedBox(height: 10),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("I consent to share documents", style: TextStyle(fontSize: 13)),
                      value: _isConsentChecked,
                      onChanged: (v) => setState(() => _isConsentChecked = v!),
                      activeColor: primaryPurple,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : _validateAndSubmit,
                        style: ElevatedButton.styleFrom(backgroundColor: primaryPurple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        child: _isUploading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('NEXT: UPLOAD PAN CARD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
        children: const [TextSpan(text: ' *', style: TextStyle(color: Colors.red))],
      ),
    );
  }

  Widget _uploadBox(PlatformFile? file, VoidCallback onTap, String hint) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 110,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          border: Border.all(color: file == null ? Colors.grey[300]! : primaryPurple),
          borderRadius: BorderRadius.circular(12),
        ),
        child: file == null
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.cloud_upload_outlined, color: primaryPurple, size: 35),
                Text(hint, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ])
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(file.extension?.toLowerCase() == 'pdf' ? Icons.picture_as_pdf : Icons.image, color: Colors.green),
                const SizedBox(width: 10),
                Flexible(child: Text(file.name, overflow: TextOverflow.ellipsis)),
                const Icon(Icons.check_circle, color: Colors.green),
              ]),
      ),
    );
  }
}