import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; 
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; 

// WE ADDED THIS TO PASS THE BATON TO THE NEXT SCREEN (Bank Details)
import 'bank_details.dart';

const Color primaryPurple = Color(0xFF673AB7);
const Color lightGreyBackground = Color(0xFFF8F9FA);

class PanInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String filtered = newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    
    if (filtered.length > 10) {
      filtered = filtered.substring(0, 10);
    }

    return TextEditingValue(
      text: filtered,
      selection: TextSelection.collapsed(offset: filtered.length),
    );
  }
}

class PanCardStep extends StatefulWidget {
  // NEW: Catching the data from the Aadhar screen!
  final Map<String, dynamic> schemeData;

  const PanCardStep({super.key, required this.schemeData});

  @override
  State<PanCardStep> createState() => _PanCardStepState();
}

class _PanCardStepState extends State<PanCardStep> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _panController = TextEditingController();

  PlatformFile? _uploadDocFile; 
  bool _isUploading = false;

  // OCR Verification Logic for PAN
  Future<bool> _verifyPanDocument(PlatformFile file, String enteredPan) async {
    if (kIsWeb) return true;
    if (file.path == null) return file.extension?.toLowerCase() == 'pdf'; 
    
    final inputImage = InputImage.fromFilePath(file.path!);
    final recognizer = TextRecognizer();

    try {
      final recognized = await recognizer.processImage(inputImage);
      String upperEntered = enteredPan.toUpperCase().trim();
      
      String allDetectedText = "";
      for (var block in recognized.blocks) {
        for (var line in block.lines) {
          allDetectedText += line.text.toUpperCase();
        }
      }
      
      await recognizer.close();
      return allDetectedText.contains(upperEntered);
    } catch (e) {
      await recognizer.close();
      return file.extension?.toLowerCase() == 'pdf'; 
    }
  }

  String? _validatePan(String? value) {
    if (value == null || value.isEmpty) return 'Please enter PAN number';
    final clean = value.replaceAll(' ', '');
    final regExp = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
    if (!regExp.hasMatch(clean)) {
      return 'Invalid PAN format (e.g., ABCDE1234F)';
    }
    return null;
  }

  // Selection logic updated to use FilePicker
  Future<void> _selectFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (result != null && result.files.isNotEmpty) {
        PlatformFile file = result.files.first;

        if (file.size > 2 * 1024 * 1024) {
          _showSnackbar('File too large. Max 2MB allowed.');
          return;
        }

        setState(() => _uploadDocFile = file);
      }
    } catch (e) {
      _showSnackbar('Failed to pick file');
    }
  }

  void _showSnackbar(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_uploadDocFile == null) {
      _showSnackbar('Please upload PAN document image or PDF');
      return;
    }

    setState(() => _isUploading = true);

    // Run OCR check only for images
    bool isMatch = await _verifyPanDocument(_uploadDocFile!, _panController.text);
    if (!isMatch) {
      _showSnackbar('PAN number not detected in the image. Please upload a clearer photo.');
      setState(() => _isUploading = false);
      return;
    }

    // FIXED: NO DATABASE CALL! 
    // We pack the new PAN info into our "Shopping Cart" and pass it forward to Bank Details.
    Map<String, dynamic> updatedSchemeData = Map.from(widget.schemeData);
    updatedSchemeData['pan_number'] = _panController.text;
    updatedSchemeData['pan_file'] = _uploadDocFile;

    setState(() => _isUploading = false);

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BankDetailsPage(schemeData: updatedSchemeData),
        ),
      );
    }
  }

  @override
  void dispose() {
    _panController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGreyBackground,
      appBar: AppBar(
        title: const Text("KYC Verification", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: primaryPurple,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
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
                    const Text("PAN Card", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryPurple)),
                    const SizedBox(height: 8),
                    const Text("Please enter your PAN and upload document (PDF or Image)", style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const Divider(height: 40),  

                    TextFormField(
                      controller: _panController,
                      keyboardType: TextInputType.text,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(10),
                        PanInputFormatter(),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'PAN Number',
                        hintText: 'ABCDE1234F',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validatePan,
                    ),
                    const SizedBox(height: 20),

                    _uploadBox('Upload Image(Max 2MB)', _uploadDocFile),

                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : _onSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryPurple,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isUploading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('NEXT: ADD BANK DETAILS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _uploadBox(String label, PlatformFile? file) {
    return Stack(
      children: [
        InkWell(
          onTap: _selectFile,
          child: Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: file == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_upload_outlined, color: primaryPurple, size: 40),
                      Text(label, style: const TextStyle(color: Colors.grey)),
                    ],
                  )
                : file.extension?.toLowerCase() == 'pdf'
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.picture_as_pdf, color: Colors.red, size: 50),
                        Text(file.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      ],
                    )
                  : kIsWeb
                    ? Image.memory(file.bytes!, fit: BoxFit.contain)
                    : Image.file(File(file.path!), fit: BoxFit.contain),
          ),
        ),
        if (file != null)
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => setState(() {
                _uploadDocFile = null;
              }),
              child: const CircleAvatar(radius: 12, backgroundColor: Colors.red, child: Icon(Icons.close, color: Colors.white, size: 16)),
            ),
          ),
      ],
    );
  }
}