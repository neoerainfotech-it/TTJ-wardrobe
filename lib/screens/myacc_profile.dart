import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart'; // REQUIRED FOR CROSS-PLATFORM IMAGE PICKING

// Core Settings & Localization Imports
import '../core/app_settings.dart'; // <-- RE-ADDED SETTINGS CONFIG LINK
import '../core/localization/language_provider.dart';

// Navigation Imports
import 'welcome.dart';
import 'profile.dart';
import 'redemption.dart';
import 'gold_wallet.dart';
import 'transactions.dart';

class MyAccProfileScreen extends StatefulWidget {
  const MyAccProfileScreen({super.key});

  @override
  State<MyAccProfileScreen> createState() => _MyAccProfileScreenState();
}

class _MyAccProfileScreenState extends State<MyAccProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // CROSS-PLATFORM IMAGE VARIABLES
  String? _localPhotoBase64; 
  String? _profileImageUrl; 
  bool _isUploadingImage = false;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();

  String? _selectedGender;
  int? _loggedInUserId;
  bool _isLoading = true;

  static const Color brandPurple = Color(0xFF5D1F88);

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();

    _loggedInUserId = prefs.getInt('user_id');

    if (_loggedInUserId == null) {
      setState(() => _isLoading = false);
      if (mounted) {
        final lang = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.translate("Session Expired"))),
        );
      }
      return;
    }

    setState(() {
      _firstNameController.text = prefs.getString('first_name') ?? "";
      _lastNameController.text = prefs.getString('last_name') ?? "";
      _phoneController.text = prefs.getString('phone') ?? prefs.getString('mobile') ?? "";
      _dobController.text = prefs.getString('dob') ?? "";
      _profileImageUrl = prefs.getString('profile_photo');

      String? gender = prefs.getString('gender');
      if (gender != null && ["Male", "Female", "Others"].contains(gender)) {
        _selectedGender = gender;
      }

      // Load Local Base64 Image (Cross-Platform)
      _localPhotoBase64 = prefs.getString('local_profile_base64');
    });

    await _fetchFromServer();
  }

  Future<void> _fetchFromServer() async {
    try {
      final response = await http.post(
        Uri.parse('https://ttjnextgen.divasprik.in/ttj_api/get_profile.php'),
        body: {'user_id': _loggedInUserId.toString()},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _firstNameController.text = data['first_name'] ?? _firstNameController.text;
            _lastNameController.text = data['last_name'] ?? _lastNameController.text;
            _phoneController.text = data['phone'] ?? data['mobile'] ?? _phoneController.text;
            _dobController.text = data['dob'] ?? _dobController.text;
            _selectedGender = data['gender']?.isNotEmpty == true ? data['gender'] : _selectedGender;
            _profileImageUrl = data['profile_photo']?.isNotEmpty == true ? data['profile_photo'] : _profileImageUrl;
            _isLoading = false;
          });

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('first_name', _firstNameController.text);
          await prefs.setString('last_name', _lastNameController.text);
          await prefs.setString('phone', _phoneController.text);
          await prefs.setString('dob', _dobController.text);
          if (_selectedGender != null) await prefs.setString('gender', _selectedGender!);
          if (_profileImageUrl != null) await prefs.setString('profile_photo', _profileImageUrl!);
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _validateAndSave(LanguageProvider lang) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.translate("Select Gender"))),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://ttjnextgen.divasprik.in/ttj_api/update_profile.php'),
      );

      request.fields.addAll({
        'user_id': _loggedInUserId.toString(),
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'mobile': _phoneController.text.trim(),
        'gender': _selectedGender!,
        'dob': _dobController.text.trim(),
      });

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      var data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('first_name', _firstNameController.text.trim());
        await prefs.setString('last_name', _lastNameController.text.trim());
        await prefs.setString('phone', _phoneController.text.trim());
        await prefs.setString('gender', _selectedGender!);
        await prefs.setString('dob', _dobController.text.trim());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.green, content: Text(lang.translate("Profile Updated Success"))),
          );
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? "Update failed")));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showImageSourceActionSheet(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Update Profile Picture', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAndSaveImageLocally(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAndSaveImageLocally(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndSaveImageLocally(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 50, maxWidth: 500, maxHeight: 500);

    if (image == null) return; 

    setState(() => _isUploadingImage = true); 

    try {
      Uint8List imageBytes = await image.readAsBytes();
      String base64String = base64Encode(imageBytes);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_profile_base64', base64String);

      setState(() {
        _localPhotoBase64 = base64String;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving image: $e"), backgroundColor: Colors.red));
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  ImageProvider _getProfileImage() {
    if (_localPhotoBase64 != null && _localPhotoBase64!.isNotEmpty) {
      try {
        Uint8List bytes = base64Decode(_localPhotoBase64!);
        return MemoryImage(bytes);
      } catch (e) {
        debugPrint("Error decoding Base64: $e");
      }
    }
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      String imageUrl = _profileImageUrl!;
      if (!imageUrl.startsWith('http')) {
        imageUrl = 'https://ttjnextgen.divasprik.in/ttj_api/$imageUrl'; 
      }
      return NetworkImage('$imageUrl?v=${DateTime.now().millisecondsSinceEpoch}');
    }
    return const NetworkImage('https://avatar.iran.liara.run/public/girl');
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: brandPurple),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _dobController.text =
            "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          lang.translate("Edit Profile"),
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: brandPurple))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 55,
                            backgroundColor: const Color(0xFFF3E5F5),
                            backgroundImage: _getProfileImage(),
                          ),
                          if (_isUploadingImage)
                            const Positioned.fill(
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                            ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _showImageSourceActionSheet(context),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: brandPurple,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    _buildField(lang.translate("First Name"), _firstNameController, lang.translate("Enter First Name"), lang),
                    const SizedBox(height: 20),
                    _buildField(lang.translate("Last Name"), _lastNameController, lang.translate("Enter Last Name"), lang),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(lang.translate("Phone Number"), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      decoration: const InputDecoration(
                        counterText: "",
                        prefixText: "+91 ",
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                      ),
                      validator: (v) => v?.length != 10 ? lang.translate("Enter Valid Number") : null,
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(lang.translate("Gender"), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      items: ["Male", "Female", "Others"]
                          .map((e) => DropdownMenuItem(value: e, child: Text(lang.translate(e))))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedGender = val),
                      validator: (v) => v == null ? lang.translate("Required") : null,
                      decoration: const InputDecoration(
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(lang.translate("Date of Birth"), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    TextFormField(
                      controller: _dobController,
                      readOnly: true,
                      onTap: () => _selectDate(context),
                      decoration: InputDecoration(
                        suffixIcon: const Icon(Icons.calendar_month, color: brandPurple),
                        hintText: lang.translate("Select Date"),
                      ),
                      validator: (v) => v?.isEmpty ?? true ? lang.translate("Required") : null,
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () => _validateAndSave(lang),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandPurple,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                lang.translate("Save Changes"),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildField(String label, TextEditingController controller, String hint, LanguageProvider lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
          ),
          validator: (v) => v?.trim().isEmpty ?? true ? lang.translate("Required") : null,
        ),
      ],
    );
  }

  // --- REFACTORED DYNAMIC NAVIGATION BAR ---
  Widget _buildBottomNav() {
    return Container(
      height: 70,
      color: brandPurple,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.home_outlined, color: Colors.white70),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const WelcomeScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.compare_arrows, color: Colors.white70),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const TransactionsScreen()),
            ),
          ),

          // Dynamic Gold Wallet Visibility Check
          if (appSettings.showGoldWallet)
            IconButton(
              icon: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white70),
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const GoldWalletScreen()),
              ),
            ),

          // Dynamic Redemption Visibility Check
          if (appSettings.showRedemption)
            IconButton(
              icon: const Icon(Icons.card_giftcard, color: Colors.white70),
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const RedemptionPage()),
              ),
            ),

          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () {}, // Already on this page
          ),
        ],
      ),
    );
  }
}