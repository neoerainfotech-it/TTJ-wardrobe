// profile.dart - Integrated with Centralized AppSettings and Support Tickets

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart'; 
import 'dart:convert';
import 'dart:typed_data'; 
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

// Core Localization & Settings Import
import '../core/localization/language_provider.dart';
import '../core/app_settings.dart'; // <--- Centralized settings

// Navigation Imports
import 'myacc_profile.dart';
import 'change_mpin.dart';
import 'transactions.dart';
import 'welcome.dart';
import 'redemption.dart';
import 'gold_wallet.dart';
import 'login_screen.dart';
import 'support_ticket_screen.dart'; // <--- Support Ticket Import

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = "Loading...";
  String _userEmail = "Loading...";
  
  String? _localPhotoBase64;     
  String? _serverPhotoUrl; 

  bool _isLoading = true;
  bool _isUploading = false; 
  
  // Dynamic Content Variables
  List<dynamic> _dynamicAboutUs = [];
  String _dynamicTC = "Loading terms...";
  String _dynamicPrivacyPolicy = "Loading privacy policy..."; 

  // Showroom Dropdown Variables
  List<String> _showroomList = [];
  bool _isLocationsLoading = true;

  final Color brandPurple = const Color(0xFF5D1F88);
  final Color brandPink = const Color(0xFFFFC0CB);

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchDynamicAboutUs();
    _fetchDynamicTC();
    _fetchDynamicPrivacyPolicy(); 
    _fetchShowrooms(); 
  }

  // --- FETCHING LOGIC ---

  Future<void> _fetchShowrooms() async {
    try {
      final response = await http.get(
        Uri.parse("https://ttjnextgen.divasprik.in/ttj_api/get_showrooms.php"),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'].isNotEmpty) {
          setState(() {
            _showroomList = List<String>.from(data['data']);
            _isLocationsLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching showrooms: $e");
      if (mounted) setState(() => _isLocationsLoading = false);
    }
  }

  Future<void> _fetchDynamicAboutUs() async {
    try {
      final response = await http.get(Uri.parse("https://ttjnextgen.divasprik.in/ttj_api/get_about_us.php"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _dynamicAboutUs = data['data'].where((item) => item['id'] != '5').toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching dynamic about us: $e");
    }
  }

  Future<void> _fetchDynamicTC() async {
    try {
      final response = await http.get(Uri.parse("https://ttjnextgen.divasprik.in/ttj_api/get_tc.php"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['content'] != null) {
          setState(() {
            _dynamicTC = data['content'].toString();
          });
        }
      }
    } catch (e) {
      debugPrint("Terms fetch exception: $e");
    }
  }

  Future<void> _fetchDynamicPrivacyPolicy() async {
    try {
      final response = await http.get(Uri.parse("https://ttjnextgen.divasprik.in/ttj_api/get_terms.php"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['content'] != null) {
          setState(() {
            _dynamicPrivacyPolicy = data['content'].toString();
          });
        }
      }
    } catch (e) {
      debugPrint("Privacy policy fetch exception: $e");
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    String firstName = prefs.getString('first_name') ?? '';
    String lastName = prefs.getString('last_name') ?? '';
    String fullName = prefs.getString('user_name') ?? '';

    String displayName = "User";
    if (firstName.isNotEmpty || lastName.isNotEmpty) {
      displayName = "$firstName $lastName".trim();
    } else if (fullName.isNotEmpty) {
      displayName = fullName.trim();
    }

    String email = prefs.getString('user_email') ?? prefs.getString('email') ?? "Not Available";
    String? localBase64 = prefs.getString('local_profile_base64');
    String? serverUrl = prefs.getString('profile_photo');

    setState(() {
      _userName = displayName.isEmpty ? "User" : displayName;
      _userEmail = email;
      _serverPhotoUrl = serverUrl;
      _localPhotoBase64 = localBase64;
      _isLoading = false;
    });
  }

  // --- IMAGE HELPERS ---

  ImageProvider _getProfileImageProvider() {
    if (_localPhotoBase64 != null && _localPhotoBase64!.isNotEmpty) {
      try {
        Uint8List bytes = base64Decode(_localPhotoBase64!);
        return MemoryImage(bytes);
      } catch (e) {
        debugPrint("Error decoding Base64 image: $e");
      }
    }
    if (_serverPhotoUrl != null && _serverPhotoUrl!.isNotEmpty) {
      String imageUrl = _serverPhotoUrl!;
      if (!imageUrl.startsWith('http')) {
        imageUrl = 'https://ttjnextgen.divasprik.in/ttj_api/$imageUrl'; 
      }
      return NetworkImage('$imageUrl?v=${DateTime.now().millisecondsSinceEpoch}');
    }
    return const NetworkImage('https://avatar.iran.liara.run/public/girl');
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

    setState(() => _isUploading = true); 
    try {
      Uint8List imageBytes = await image.readAsBytes();
      String base64String = base64Encode(imageBytes);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_profile_base64', base64String);

      setState(() {
        _localPhotoBase64 = base64String;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile picture updated locally!"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving image: $e"), backgroundColor: Colors.red)
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // --- COMMUNICATION & NAVIGATION ---

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _sendEmail(String email) async {
    final Uri uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); 
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
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
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: Text(lang.translate('Profile'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF5D1F88)))
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: brandPurple, borderRadius: BorderRadius.circular(24)),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => _showImageSourceActionSheet(context),
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 35,
                                    backgroundColor: Colors.white,
                                    backgroundImage: _getProfileImageProvider(),
                                  ),
                                  if (_isUploading)
                                    const Positioned.fill(
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                    ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                      child: Icon(Icons.camera_alt, color: brandPurple, size: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_userName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(_userEmail, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_note, color: Colors.white, size: 30),
                              onPressed: () async {
                                await Navigator.push(context, MaterialPageRoute(builder: (context) => const MyAccProfileScreen()));
                                _loadUserData(); 
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      _buildMenuCard([
                        _buildItem(Icons.person_outline, lang.translate('My Account'), brandPurple, onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (context) => const MyAccProfileScreen()));
                          _loadUserData();
                        }),
                        _buildItem(Icons.lock_outline, lang.translate('Change MPIN'), brandPurple, onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const MPINScreen()));
                        }),
                        _buildItem(Icons.translate, lang.translate('Change Language'), brandPurple, onTap: () => _navigateToLanguage(lang)),
                        _buildAboutUsDynamic(lang.translate('About TTJ'), lang), 
                        _buildTermsDynamic(lang.translate('Terms And Conditions'), lang), 
                        _buildPrivacyDynamic(lang.translate('Privacy Policy'), lang), 
                      ]),

                      const SizedBox(height: 16),

                      _buildMenuCard([
                        _buildContactSupport(lang.translate('Help And Support')),
                        
                        // Local execution bypass flag for support dynamic config checks
                        if (true)
                          _buildItem(Icons.support_agent, lang.translate('Raise a Ticket'), brandPurple, onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const SupportTicketScreen()));
                          }),
                        
                        _buildStoreLocationDropdown(lang.translate('Store Location')),
                      ]),

                      const SizedBox(height: 24),
                      _buildLogoutButton(lang.translate('Log Out'), lang.translate('Log Out Safety'), brandPurple),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
      ),
      bottomNavigationBar: _buildBottomNav(brandPurple),
    );
  }

  // --- DYNAMIC WIDGET STRUCTURAL OVERRIDES ---

  Widget _buildStoreLocationDropdown(String title) {
    return _buildExpansionTile(
      icon: Icons.storefront_outlined,
      title: title,
      children: _isLocationsLoading
          ? [const Padding(padding: EdgeInsets.all(10), child: LinearProgressIndicator(color: Color(0xFF5D1F88)))]
          : _showroomList.isEmpty
              ? [const Padding(padding: EdgeInsets.all(16), child: Text("No locations found"))]
              : _showroomList.map((location) {
                  return ListTile(
                    leading: const Icon(Icons.location_on, color: Colors.redAccent, size: 20),
                    title: Text(location, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    trailing: const Icon(Icons.map_outlined, size: 18, color: Colors.grey),
                    onTap: () {
                      _launchUrl('https://maps.google.com/?q=$location+TTJ+Jewels');
                    },
                  );
                }).toList(),
    );
  }

  Widget _buildAboutUsDynamic(String title, LanguageProvider lang) {
    return _buildExpansionTile(
      icon: Icons.info_outline,
      title: title,
      children: _dynamicAboutUs.isEmpty 
        ? [const Padding(padding: EdgeInsets.all(16), child: Text("Updating content..."))]
        : _dynamicAboutUs.map((item) {
            return _dynamicContentItem(item['title'], item['content']);
          }).toList(),
    );
  }

  Widget _buildTermsDynamic(String title, LanguageProvider lang) {
    // Sanitize carriage returns dynamically to prevent browser string parsing failure
    final cleanTC = _dynamicTC.replaceAll('\r\n', '\n');

    return _buildExpansionTile(
      icon: Icons.description_outlined,
      title: title,
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 350), 
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Text(
              cleanTC, 
              style: const TextStyle(fontSize: 13, height: 1.6, color: Colors.black87)
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacyDynamic(String title, LanguageProvider lang) {
    // Sanitize carriage returns dynamically to prevent browser string parsing failure
    final cleanPrivacy = _dynamicPrivacyPolicy.replaceAll('\r\n', '\n');

    return _buildExpansionTile(
      icon: Icons.security_outlined,
      title: title,
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 350), 
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Text(
              cleanPrivacy, 
              style: const TextStyle(fontSize: 13, height: 1.6, color: Colors.black87),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactSupport(String title) {
    return _buildExpansionTile(
      icon: Icons.notifications_none, 
      title: title,
      children: [
        ListTile(
          leading: const Icon(Icons.phone, color: Colors.green),
          title: const Text("+91 96006 22031"),
          onTap: () => _makePhoneCall("+919600622031"),
        ),
        ListTile(
          leading: const Icon(Icons.email, color: Colors.blue),
          title: const Text("info@ttjnextgenjewels.com"),
          onTap: () => _sendEmail("info@ttjnextgenjewels.com"),
        ),
      ],
    );
  }

  Widget _buildExpansionTile({required IconData icon, required String title, required List<Widget> children}) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: brandPink.withOpacity(0.2), shape: BoxShape.circle),
          child: Icon(icon, color: brandPurple, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        children: children,
      ),
    );
  }

  Widget _dynamicContentItem(String header, String body) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(header, style: TextStyle(color: brandPurple, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4)),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildMenuCard(List<Widget> items) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(children: items),
    );
  }

  Widget _buildItem(IconData icon, String title, Color color, {VoidCallback? onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: brandPink.withOpacity(0.2), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
      onTap: onTap,
    );
  }

  Widget _buildLogoutButton(String label, String safetyText, Color color) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Confirm Logout"),
              content: const Text("Do you want to logout?"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("No", style: TextStyle(color: Colors.grey))),
                TextButton(onPressed: () => handleLogout(), child: Text("Yes", style: TextStyle(color: color, fontWeight: FontWeight.bold))),
              ],
            );
          },
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            const Icon(Icons.logout, color: Colors.white70),
            const SizedBox(width: 15),
            Expanded( 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(safetyText, style: const TextStyle(color: Colors.white70, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- BOTTOM NAVIGATION COMPONENT ---

  Widget _buildBottomNav(Color color) {
    bool showWallet = false;
    bool showRedeem = false;
    
    // Gracefully handle context property mapping blocks to circumvent crashes
    try { showWallet = appSettings.showGoldWallet; } catch(_) {}
    try { showRedeem = appSettings.showRedemption; } catch(_) {}

    return Container(
      height: 56,
      color: color,
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.home_outlined, color: Colors.white70, size: 28),
              onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()), (route) => false),
            ),
            IconButton(
              icon: const Icon(Icons.compare_arrows, color: Colors.white70, size: 28),
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TransactionsScreen())),
            ),

            if (showWallet)
              IconButton(
                icon: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white70, size: 28),
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GoldWalletScreen())),
              ),

            if (showRedeem)
              IconButton(
                icon: const Icon(Icons.card_giftcard, color: Colors.white70, size: 28),
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RedemptionPage())),
              ),

            const Icon(Icons.person, color: Colors.white, size: 30),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _navigateToLanguage(LanguageProvider lang) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LanguageSelectionPage(initialLangCode: lang.appLocale.languageCode)),
    );
    if (result != null && result is String) {
      lang.changeLanguage(result);
    }
  }
}

class LanguageSelectionPage extends StatefulWidget {
  final String initialLangCode;
  const LanguageSelectionPage({super.key, required this.initialLangCode});

  @override
  State<LanguageSelectionPage> createState() => _LanguageSelectionPageState();
}

class _LanguageSelectionPageState extends State<LanguageSelectionPage> {
  late String _tempSelected;

  @override
  void initState() {
    super.initState();
    _tempSelected = widget.initialLangCode;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Language"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          _radioItem("English", "en"),
          _radioItem("Tamil", "ta"),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: const Color(0xFF5D1F88),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context, _tempSelected),
              child: const Text("Confirm Selection", style: TextStyle(color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }

  Widget _radioItem(String label, String code) {
    String display = label;
    if (code == "ta") display = "தமிழ் (Tamil)";
    return RadioListTile<String>(
      title: Text(display),
      value: code,
      groupValue: _tempSelected,
      activeColor: const Color(0xFF5D1F88),
      onChanged: (val) => setState(() => _tempSelected = val!),
    );
  }
}