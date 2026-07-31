import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// WE ADDED THIS TO PASS THE FINAL BATON TO THE PAYMENT/KYC SCREEN
import 'kyc.dart';

const Color brandPurple = Color(0xFF5D1F88);

class UserPhotoPage extends StatefulWidget {
  // NEW: Catching all the accumulated data!
  final Map<String, dynamic> schemeData;

  const UserPhotoPage({super.key, required this.schemeData});

  @override
  State<UserPhotoPage> createState() => _UserPhotoPageState();
}

class _UserPhotoPageState extends State<UserPhotoPage> {
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 60, // Balanced for size and quality
      );

      if (pickedFile != null) {
        final int sizeInBytes = await pickedFile.length();

        if (sizeInBytes > 1024 * 1024) {
          _showSnackbar('Photo too large. Max 1MB allowed.');
          return;
        }

        setState(() {
          _selectedImage = pickedFile;
        });
      }
    } catch (e) {
      debugPrint('Image pick error: $e');
      _showSnackbar('Error selecting photo');
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

  void _onSubmit() {
    if (_selectedImage == null) {
      _showSnackbar('Please upload a photo first');
      return;
    }

    // FIXED: NO DATABASE CALL!
    // We pack the final piece (the photo) into our "Shopping Cart" 
    // and pass the whole package to the Final KYC/Payment Screen.
    Map<String, dynamic> finalSchemeData = Map.from(widget.schemeData);
    finalSchemeData['user_photo'] = _selectedImage;

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => KycCompletedPage(schemeData: finalSchemeData),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Identity Verification',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: brandPurple,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          children: [
            const Text(
              "Upload Your Photo",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: brandPurple),
            ),
            const SizedBox(height: 10),
            const Text(
              "Please ensure your face is clearly visible",
              style: TextStyle(color: Colors.grey),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: brandPurple, width: 2),
                  image: _selectedImage != null
                      ? DecorationImage(
                          image: kIsWeb
                              ? NetworkImage(_selectedImage!.path)
                              : FileImage(File(_selectedImage!.path)) as ImageProvider,
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _selectedImage == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 50, color: brandPurple),
                          SizedBox(height: 8),
                          Text(
                            "Tap to upload (Max 1MB)",
                            style: TextStyle(color: brandPurple, fontSize: 12),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _onSubmit,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
                backgroundColor: brandPurple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'NEXT: REVIEW & PAY',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}