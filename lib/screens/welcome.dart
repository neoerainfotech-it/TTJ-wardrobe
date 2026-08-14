// welcome.dart - Fully Responsive Version with Dynamic Scaling, FCM Topic Sync, Scrollable Scheme Cards, Date Formatting, and Always-Active Payment

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Internal Screen Imports
import 'profile.dart';
import 'transactions.dart';
import 'redemption.dart';
import 'gold_wallet.dart';
import 'scheme_details.dart';
import 'scheme_joining.dart';
import 'login_screen.dart';
import 'scheme_installment.dart';
import '../core/localization/language_provider.dart';
import '../core/app_settings.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with WidgetsBindingObserver {
  static const String _baseUrl = "https://ttjnextgen.divasprik.in/ttj_api/";
  static const String _imageRootUrl = "https://ttjnextgen.divasprik.in/";

  final Color brandPurple = const Color(0xFF5D1F88);
  final Color brandPink = const Color(0xFFFFC0CB);
  final Color schemeCardColor = const Color(0xFFAD283E);
  final Color goldYellow = const Color(0xFFFFD700);

  // Controllers
  final PageController _promoController = PageController();
  final PageController _schemeController = PageController();
  final PageController _jewelryController = PageController();

  // State Variables
  int _promoCurrentPage = 0;
  int _schemeCurrentPage = 0;
  int _jewelryCurrentPage = 0;

  Timer? _rateTimer;
  Timer? _promoTimer;
  Timer? _schemeTimer;
  Timer? _jewelryTimer;

  String goldRate = "Loading...";
  String gold9Rate = "Loading...";

  List<dynamic> _schemes = [];
  List<dynamic> _promos = [];
  List<String> _jewelryImages = [];
  List<dynamic> _showrooms = [];

  bool _isLoadingSchemes = true;
  bool _isLoadingPromos = true;
  bool _isLoadingJewelry = true;
  bool _isLoadingShowrooms = true;
  bool _isCheckingEnrollment = false;

  Map<String, dynamic>? _enrollmentData;
  String _kycStepStatus = "new";

  DateTime? _backgroundTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _loadInitialData();

    _rateTimer =
        Timer.periodic(const Duration(seconds: 30), (t) => fetchMarketRates());

    _promoTimer = Timer.periodic(const Duration(seconds: 5), (t) {
      if (_promoController.hasClients && _promos.isNotEmpty) {
        _promoCurrentPage = (_promoCurrentPage + 1) % _promos.length;
        _promoController.animateToPage(_promoCurrentPage,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut);
      }
    });

    _schemeTimer = Timer.periodic(const Duration(seconds: 4), (t) {
      if (_schemeController.hasClients && _schemes.isNotEmpty) {
        _schemeCurrentPage = (_schemeCurrentPage + 1) % _schemes.length;
        _schemeController.animateToPage(_schemeCurrentPage,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut);
      }
    });

    _jewelryTimer = Timer.periodic(const Duration(seconds: 3), (t) {
      if (_jewelryController.hasClients && _jewelryImages.isNotEmpty) {
        _jewelryCurrentPage = (_jewelryCurrentPage + 1) % _jewelryImages.length;
        _jewelryController.animateToPage(_jewelryCurrentPage,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rateTimer?.cancel();
    _promoTimer?.cancel();
    _schemeTimer?.cancel();
    _jewelryTimer?.cancel();
    _promoController.dispose();
    _schemeController.dispose();
    _jewelryController.dispose();
    super.dispose();
  }

  // Helper to standardize gold weight strings into 'X gm'
  String _formatGoldUnit(String? raw, {String fallback = "0.000"}) {
    if (raw == null) return "$fallback gm";
    String cleaned = raw.replaceAll(RegExp(r'[^\d.]'), '').trim();
    return cleaned.isEmpty ? "$fallback gm" : "$cleaned gm";
  }

  // 🟢 AUTOMATIC FCM TOPIC SYNC FUNCTION
  Future<void> _syncUserFcmTopics(bool isRegisteredInScheme) async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      await messaging.subscribeToTopic('all_users');

      if (isRegisteredInScheme) {
        await messaging.subscribeToTopic('scheme_users');
        await messaging.unsubscribeFromTopic('non_scheme_users');
        debugPrint("FCM WELCOME SYNC: Joined 'scheme_users' & Left 'non_scheme_users'");
      } else {
        await messaging.subscribeToTopic('non_scheme_users');
        await messaging.unsubscribeFromTopic('scheme_users');
        debugPrint("FCM WELCOME SYNC: Joined 'non_scheme_users' & Left 'scheme_users'");
      }
    } catch (e) {
      debugPrint("FCM Topic Sync Error in WelcomeScreen: $e");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgroundTime = DateTime.now();
      debugPrint("App went to background at $_backgroundTime");
    } else if (state == AppLifecycleState.resumed) {
      if (_backgroundTime != null) {
        final difference = DateTime.now().difference(_backgroundTime!);
        if (difference.inMinutes >= 5) {
          debugPrint("Session Expired! Gone for ${difference.inMinutes} mins.");
          await _forceLogout(
              "Session expired due to inactivity. Please log in again.");
        } else {
          debugPrint(
              "Welcome back! You were gone for ${difference.inSeconds} seconds.");
        }
        _backgroundTime = null;
      }
    } else if (state == AppLifecycleState.detached) {
      debugPrint("App killed! Wiping session data instantly.");
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
    }
  }

  Future<void> _forceLogout(String message) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(message),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4)),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      fetchMarketRates(),
      fetchSchemes(),
      fetchPromotions(),
      fetchJewelryDesigns(),
      _fetchUserEnrollment(),
      _fetchKycStepStatus(),
      fetchShowrooms(),
    ]);
  }

  Future<void> fetchShowrooms() async {
    try {
      final r = await http.get(Uri.parse('${_baseUrl}get_map_locations.php'));
      if (r.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _showrooms = json.decode(r.body);
          _isLoadingShowrooms = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingShowrooms = false);
      }
    } catch (e) {
      debugPrint("Error fetching showrooms: $e");
      if (mounted) setState(() => _isLoadingShowrooms = false);
    }
  }

  Future<void> _fetchKycStepStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final int? userId = prefs.getInt('user_id');
    if (userId == null) return;

    try {
      final response = await http
          .post(
            Uri.parse("${_baseUrl}check_enrollment_step.php"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"user_id": userId}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body.trim());
        if (mounted) {
          setState(() {
            _kycStepStatus = json['step_status'] ?? "new";
          });
        }
      }
    } catch (e) {
      debugPrint("Background step fetch failed: $e");
    }
  }

  Future<void> _fetchUserEnrollment() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int? userId = prefs.getInt('user_id');

      if (userId == null) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false);
        }
        return;
      }

      final response = await http
          .get(
              Uri.parse("${_baseUrl}get_enrollment_status.php?user_id=$userId"))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          if (!mounted) return;
          setState(() {
            _enrollmentData = data;
          });

          String schemeStatus = data['scheme_status']?.toString() ?? "Active";
          bool isActiveScheme = (schemeStatus.toLowerCase() == 'active');
          await _syncUserFcmTopics(isActiveScheme);

        } else {
          if (!mounted) return;
          setState(() {
            _enrollmentData = null;
          });
          await _syncUserFcmTopics(false);
        }
      } else {
        await _syncUserFcmTopics(false);
      }
    } catch (e) {
      debugPrint("Error fetching enrollment: $e");
      bool storedSchemeStatus = (await SharedPreferences.getInstance())
              .getBool('has_active_scheme') ??
          false;
      await _syncUserFcmTopics(storedSchemeStatus);
    }
  }

  Future<void> fetchMarketRates() async {
    try {
      final r = await http.get(Uri.parse('${_baseUrl}get_market_rates.php'));
      if (r.statusCode == 200) {
        final d = json.decode(r.body);
        if (!mounted) return;
        setState(() {
          goldRate = d['rates']['gold24']?.toString() ?? "13588.00";
          gold9Rate = d['rates']['gold9']?.toString() ?? "240.00";
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        goldRate = "13588.00";
        gold9Rate = "240.00";
      });
    }
  }

  Future<void> fetchSchemes() async {
    try {
      final r = await http.get(Uri.parse('${_baseUrl}get_schemes.php'));
      if (r.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _schemes = json.decode(r.body);
          _isLoadingSchemes = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingSchemes = false);
    }
  }

  Future<void> fetchPromotions() async {
    try {
      final r =
          await http.get(Uri.parse('${_baseUrl}get_promotions.php?type=api'));
      if (r.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _promos = json.decode(r.body);
          _isLoadingPromos = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingPromos = false);
    }
  }

  Future<void> fetchJewelryDesigns() async {
    try {
      final response =
          await http.get(Uri.parse('${_baseUrl}get_jewelry_designs.php'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(response.body);
        if (jsonData['success'] == true) {
          final List<dynamic> designs = jsonData['data'];
          final List<String> images = [];

          for (var design in designs) {
            String mainImg = design['main_image_path'] ?? '';
            if (mainImg.isNotEmpty) images.add(_buildImageUrl(mainImg));
            String img2 = design['image2_path'] ?? '';
            if (img2.isNotEmpty) images.add(_buildImageUrl(img2));
            String img3 = design['image3_path'] ?? '';
            if (img3.isNotEmpty) images.add(_buildImageUrl(img3));
          }

          if (!mounted) return;
          setState(() {
            _jewelryImages = images;
            _isLoadingJewelry = false;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingJewelry = false);
    }
  }

  String _buildImageUrl(String img) {
    img = img.replaceAll('\\', '/').trim();
    img = img.replaceAll(RegExp(r'^assets/', caseSensitive: false), 'ASSETS/');
    if (img.isEmpty) {
      return '${_imageRootUrl}ASSETS/image/placeholder.jpeg';
    }
    if (img.startsWith('http')) {
      return img;
    }
    return '$_imageRootUrl$img';
  }

  Future<void> _handleJoinNowValidation(LanguageProvider lang) async {
    if (_kycStepStatus == "kyc_done" || _kycStepStatus == "enrolled") {
      _showMessage(
          "You have already fully enrolled in the scheme.", Colors.orange);
      return;
    }

    if (_isCheckingEnrollment) return;
    setState(() => _isCheckingEnrollment = true);

    final prefs = await SharedPreferences.getInstance();
    final int? userId = prefs.getInt('user_id');

    if (userId == null) {
      _showMessage(lang.translate('error_session'), Colors.red);
      setState(() => _isCheckingEnrollment = false);
      return;
    }

    try {
      final response = await http
          .post(
            Uri.parse("${_baseUrl}check_enrollment_step.php"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"user_id": userId}),
          )
          .timeout(const Duration(seconds: 15));

      final json = jsonDecode(response.body.trim());

      if (response.statusCode == 200) {
        String status = json['step_status'] ?? "new";

        setState(() {
          _kycStepStatus = status;
        });

        switch (status) {
          case "kyc_done":
          case "enrolled":
          case "already_enrolled":
            _showMessage(lang.translate('error_enrolled'), Colors.orange);
            break;
          default:
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SchemeJoiningPage()));
            break;
        }
      }
    } catch (e) {
      _showMessage(lang.translate('error_internet'), Colors.red);
    } finally {
      if (mounted) setState(() => _isCheckingEnrollment = false);
    }
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 4)),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch the link: $url')));
      }
    }
  }

  Widget _buildUserSchemesSection(LanguageProvider lang) {
    String currentStatus =
        _enrollmentData?['scheme_status']?.toString() ?? "Active";
    List<String> hiddenStatuses = ["Completed", "Cancelled", "Blocked"];

    if (hiddenStatuses.contains(currentStatus)) {
      return const SizedBox.shrink();
    }

    // 🚀 Formatted with 'gm' unit
    String pendingGrams = _formatGoldUnit(_enrollmentData?['pending_grams']?.toString());
    String targetWeight = _formatGoldUnit(_enrollmentData?['target_weight']?.toString());
    String totalGold = _formatGoldUnit(_enrollmentData?['total_gold_saved']?.toString());

    String rawMaturity = _enrollmentData?['maturity_date'] ?? "TBD";
    String maturity = rawMaturity;
    if (rawMaturity != "TBD" && rawMaturity.contains("-")) {
      List<String> parts = rawMaturity.split("-");
      if (parts.length == 3) {
        maturity = "${parts[2]}-${parts[1]}-${parts[0]}"; 
      }
    }

    int daysRemaining = _enrollmentData?['days_remaining'] ?? 0;
    String expiryStatus = _enrollmentData?['expiry_status'] ?? "active";

    double progressPercent = double.tryParse(
            _enrollmentData?['target_achieved_percent']?.toString() ?? "0") ??
        0;
    double progressValue = (progressPercent / 100).clamp(0.0, 1.0);

    double screenWidth = MediaQuery.of(context).size.width;
    double circleSize = screenWidth * 0.28;
    if (circleSize > 120) circleSize = 120;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                lang.translate('your_schemes'),
                style: GoogleFonts.inter(
                    color: const Color.fromARGB(255, 94, 58, 201),
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    _loadInitialData();
                    _showMessage("Refreshing data...", brandPurple);
                  },
                  icon: Icon(Icons.refresh, size: 16, color: brandPurple),
                  label: Text(lang.translate('refresh'),
                      style:
                          GoogleFonts.inter(color: brandPurple, fontSize: 12)),
                  style: TextButton.styleFrom(
                      backgroundColor: brandPurple.withOpacity(0.1),
                      padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TransactionsScreen())),
                  style: TextButton.styleFrom(
                      backgroundColor: brandPurple.withOpacity(0.1),
                      padding: const EdgeInsets.symmetric(horizontal: 8)),
                  child: Text(lang.translate('recent'),
                      style:
                          GoogleFonts.inter(color: brandPurple, fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [brandPurple, brandPurple.withOpacity(0.8)]),
              borderRadius: BorderRadius.circular(15),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "ID: ${_enrollmentData?['display_user_id'] ?? 'TTJSCH220'}",
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              lang.translate('gold_plan').toUpperCase(),
                              style: GoogleFonts.inter(
                                  color: goldYellow,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                              color: goldYellow,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2))
                              ]),
                          child: Text("9KT GOLD",
                              style: GoogleFonts.inter(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(width: 10),
                        Text(lang.translate('status_active'),
                            style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(width: 4),
                        const Icon(Icons.circle,
                            color: Colors.greenAccent, size: 10),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildUserMetric("Pending Balance", pendingGrams),
                    _buildUserMetric("Target Weight", targetWeight),
                  ],
                ),
                const Divider(color: Colors.white24, height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: circleSize,
                      height: circleSize,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: goldYellow, shape: BoxShape.circle),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                lang.translate('total_gold_saved'),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                    color: Colors.black,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                totalGold,
                                style: GoogleFonts.inter(
                                    color: Colors.black,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(lang.translate('date_maturity'),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            Text(maturity,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: expiryStatus == "expired"
                                    ? Colors.red
                                    : (expiryStatus == "expiring_soon"
                                        ? Colors.orange
                                        : Colors.greenAccent.withOpacity(0.5)),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                expiryStatus == "expired"
                                    ? "EXPIRED"
                                    : "$daysRemaining Days More",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(lang.translate('target_achieved'),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                  value: progressValue,
                                  backgroundColor: Colors.white24,
                                  color: Colors.greenAccent,
                                  minHeight: 6),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("${progressPercent.toInt()}%",
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SchemeInstallmentScreen()
                        )
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: brandPurple,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      lang.translate('Pay Now'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildLiveRateCard(String title, String price, IconData icon,
      Color iconColor, LanguageProvider lang) {
    return Expanded(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 214, 167, 184),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 30,
                    width: 30,
                    decoration: const BoxDecoration(
                        color: Color.fromARGB(255, 214, 167, 184),
                        shape: BoxShape.circle),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/gold_coin.jpeg',
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) =>
                            Icon(icon, color: iconColor, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(title,
                        style: GoogleFonts.inter(
                            color: Colors.black87,
                            fontWeight: FontWeight.w700,
                            fontSize: 11),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(price,
                  style: GoogleFonts.inter(
                      color: brandPurple,
                      fontWeight: FontWeight.w900,
                      fontSize: 15)),
              Text(lang.translate('per_gram'),
                  style: GoogleFonts.inter(
                      color: const Color.fromARGB(255, 94, 58, 201),
                      fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSchemesCarousel(LanguageProvider lang) {
    if (_isLoadingSchemes)
      return const Center(child: CircularProgressIndicator());
    if (_schemes.isEmpty)
      return const Center(child: Text("No schemes available"));

    return Column(
      children: [
        Container(
          height: MediaQuery.of(context).size.height * 0.45,
          constraints: const BoxConstraints(
              minHeight: 380, maxHeight: 480),
          child: PageView.builder(
            controller: _schemeController,
            itemCount: _schemes.length,
            onPageChanged: (page) => setState(() => _schemeCurrentPage = page),
            itemBuilder: (_, index) {
              final plan = _schemes[index];
              final themeColor = (plan['border_color'] != null &&
                      plan['border_color'].toString().isNotEmpty)
                  ? Color(int.parse(
                      plan['border_color'].toString().replaceAll('#', '0xFF')))
                  : schemeCardColor;

              bool isFullyEnrolled = (_kycStepStatus == "kyc_done" ||
                  _kycStepStatus == "enrolled");

              return Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                child: Container(
                  decoration: BoxDecoration(
                      color: themeColor,
                      borderRadius: BorderRadius.circular(15)),
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding:
                              const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                          child: Column(
                            children: [
                              Image.asset('assets/ttj_logo.jpeg',
                                  height: 40,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Icon(
                                      Icons.stars,
                                      color: goldYellow,
                                      size: 30)),
                              const SizedBox(height: 8),
                              Text(
                                  plan['plan_name']?.toString().toUpperCase() ??
                                      "GOLD PLAN",
                                  style: GoogleFonts.inter(
                                      color: goldYellow,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2)),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (plan['note_content'] != null &&
                                            plan['note_content']
                                                .toString()
                                                .isNotEmpty)
                                          Container(
                                            margin: const EdgeInsets.only(
                                                bottom: 12),
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                            child: Text(
                                              plan['note_content'],
                                              style: GoogleFonts.inter(
                                                  color: goldYellow,
                                                  fontSize: 11,
                                                  fontStyle: FontStyle.italic,
                                                  fontWeight: FontWeight.w600,
                                                  height: 1.4),
                                            ),
                                          ),
                                        _infoRow(Icons.access_time,
                                            "Duration: ${plan['duration'] ?? 'N/A'}"),
                                        _infoRow(Icons.star,
                                            "Advantages: ${plan['benefit'] ?? 'N/A'}"),
                                        _infoRow(Icons.info,
                                            "Penalty: ${plan['penalty'] ?? 'N/A'}"),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: Image.asset(
                                          'assets/gold_coin.jpeg',
                                          height: 95,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.monetization_on,
                                                  color: Colors.amber,
                                                  size: 65)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        height: 50, 
                        decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(15),
                                bottomRight: Radius.circular(15))),
                        child: Row(
                          children: [
                            Expanded(
                                child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SchemeDetailsScreen(
                                      planName:
                                          plan['plan_name'] ?? "Gold Plan",
                                      description: plan['description'] ??
                                          "No details provided.",
                                      colorHex:
                                          plan['border_color'] ?? "#AD283E",
                                    ),
                                  ),
                                );
                              },
                              child: Text("KNOW MORE",
                                  style: GoogleFonts.inter(
                                      color: brandPurple,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14)),
                            )),
                            VerticalDivider(
                                width: 1,
                                color: Colors.grey.shade300,
                                indent: 10,
                                endIndent: 10),
                            Expanded(
                                child: TextButton(
                              onPressed: isFullyEnrolled
                                  ? null
                                  : () => _handleJoinNowValidation(lang),
                              child: _isCheckingEnrollment
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                          color: Colors.purple, strokeWidth: 2))
                                  : Text(
                                      isFullyEnrolled ? "ENROLLED" : "JOIN NOW",
                                      style: GoogleFonts.inter(
                                          color: isFullyEnrolled
                                              ? Colors.grey
                                              : brandPurple,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14),
                                    ),
                            )),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        if (_schemes.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                _schemes.length,
                (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _schemeCurrentPage == i
                              ? brandPurple
                              : Colors.grey.shade300),
                    )),
          ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: goldYellow),
            const SizedBox(width: 10),
            Expanded(
                child: Text(text,
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.35))),
          ],
        ),
      );

  Widget _buildPromoCarousel() {
    if (_isLoadingPromos)
      return const SizedBox(
          height: 350, child: Center(child: CircularProgressIndicator()));
    if (_promos.isEmpty)
      return const SizedBox(
          height: 350, child: Center(child: Text("No promotions available")));

    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: AspectRatio(
        aspectRatio: 1,
        child: PageView.builder(
          controller: _promoController,
          itemCount: _promos.length,
          onPageChanged: (value) => setState(() => _promoCurrentPage = value),
          itemBuilder: (context, index) {
            final String rawPath = _promos[index]['image_path'] ?? _promos[index]['full_image_url'] ?? "";
            final String resolvedPromoUrl = _buildImageUrl(rawPath);

            return CachedNetworkImage(
              imageUrl: resolvedPromoUrl,
              fit: BoxFit.contain,
              placeholder: (c, u) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (c, e, s) => Container(
                color: Colors.grey[200],
                child: const Icon(Icons.image_not_supported),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildJewelryCarousel() {
    if (_isLoadingJewelry)
      return const SizedBox(
          height: 350, child: Center(child: CircularProgressIndicator()));
    if (_jewelryImages.isEmpty)
      return const SizedBox(
          height: 350,
          child: Center(
              child: Icon(Icons.image_not_supported,
                  size: 100, color: Colors.grey)));

    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: AspectRatio(
        aspectRatio: 1,
        child: PageView.builder(
          controller: _jewelryController,
          itemCount: _jewelryImages.length,
          onPageChanged: (value) => setState(() => _jewelryCurrentPage = value),
          itemBuilder: (context, index) {
            return CachedNetworkImage(
              imageUrl: _jewelryImages[index],
              fit: BoxFit.contain,
              placeholder: (c, u) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (c, u, e) => Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.image_not_supported)),
            );
          },
        ),
      ),
    );
  }

  Widget _buildShowroomCard(LanguageProvider lang) {
    if (_isLoadingShowrooms) {
      return const Card(
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_showrooms.isEmpty) {
      return InkWell(
        onTap: () => _launchUrl('https://share.google/9O9JFMOoOe7WBpGRY'),
        child: Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.store, color: brandPurple, size: 24),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(lang.translate('showroom_search'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          color: Colors.black87,
                          fontWeight: FontWeight.w700))),
                Icon(Icons.arrow_forward_ios, size: 14, color: brandPurple),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: PopupMenuButton<String>(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        color: Colors.white,
        offset: const Offset(0, 60),
        onSelected: (String url) {
          _launchUrl(url);
        },
        itemBuilder: (BuildContext context) {
          return _showrooms.map((showroom) {
            return PopupMenuItem<String>(
              value: showroom['map_link'] ?? '',
              child: Row(
                children: [
                  Icon(Icons.location_on, color: brandPurple, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      showroom['branch_name'] ?? 'Showroom',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                  ),
                  Icon(Icons.directions, color: Colors.grey.shade400, size: 16),
                ],
              ),
            );
          }).toList();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.store, color: brandPurple, size: 24),
              const SizedBox(width: 10),
              Flexible(
                child: Text(lang.translate('showroom_search'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        color: Colors.black87,
                        fontWeight: FontWeight.w700))),
              const SizedBox(width: 8),
              Icon(Icons.arrow_drop_down_circle, size: 20, color: brandPurple),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialHelpSection(LanguageProvider lang) {
    const String contactNumberDisplay = '+91 96006 22031';
    const String contactLink = 'info@ttjnextgenjewels.com';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: brandPurple, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lang.translate('need_help'),
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('${lang.translate('contact_us')} $contactNumberDisplay',
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _launchUrl('mailto:$contactLink'),
            child: Text(contactLink,
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white,
                    fontWeight: FontWeight.w500)),
          ),
          const Divider(color: Colors.white24, height: 30),
          Text(lang.translate('follow_us'),
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _socialIcon(
                  'https://www.facebook.com/profile.php?id=61570023424961',
                  FontAwesomeIcons.facebook,
                  Colors.blue),
              _socialIcon('https://www.instagram.com/ttj_nextgenjewels',
                  FontAwesomeIcons.instagram, Colors.pink),
              _socialIcon('https://x.com/ttjnxtgenjwls',
                  FontAwesomeIcons.twitter, Colors.black),
              _socialIcon('https://www.youtube.com/@TTJNEXTGENJEWELS',
                  FontAwesomeIcons.youtube, Colors.red),
            ],
          )
        ],
      ),
    );
  }

  Widget _socialIcon(String url, dynamic icon, Color color) {
    return IconButton(
      icon: FaIcon(icon, color: color),
      onPressed: () => _launchUrl(url),
    );
  }

  Future<bool> _handlePopRoute() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: Text('Logout?',
                style: GoogleFonts.inter(
                    color: brandPurple, fontWeight: FontWeight.bold)),
            content: Text(
              'Do you want to logout of your session?',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('user_id');

                  if (mounted) {
                    Navigator.of(context).pop(true);
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
                child: const Text('Yes, Logout',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handlePopRoute();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadInitialData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset('assets/ttj_logo.jpeg', 
                        height: 60, 
                        width: 60, 
                        fit: BoxFit.contain, 
                        errorBuilder: (c, e, s) => 
                          const Icon(Icons.broken_image, size: 40)), 
                      const SizedBox(width: 8),
                      Text("TTJ Wardrobe", 
                        style: GoogleFonts.inter(
                          color: brandPurple, 
                          fontSize: 20, 
                          fontWeight: FontWeight.bold, 
                          fontStyle: FontStyle.italic)), 
                    ],
                  ),
                  const SizedBox(height: 20),
                
                  Center(
                      child: Text(lang.translate('live_rate_msg'),
                          style: GoogleFonts.inter(
                              color: Colors.grey,
                              fontSize: 14,
                              fontWeight: FontWeight.w500))),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildLiveRateCard(
                          lang.translate('gold_rate_title'),
                          "₹ $goldRate",
                          Icons.monetization_on,
                          brandPurple,
                          lang),
                      const SizedBox(width: 10),
                      _buildLiveRateCard(
                          lang.translate('gold9_rate_title'),
                          "₹ $gold9Rate",
                          Icons.monetization_on,
                          brandPurple,
                          lang),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildJewelryCarousel(),
                  const SizedBox(height: 10),
                  if (_enrollmentData != null &&
                      (_kycStepStatus == "kyc_done" ||
                          _kycStepStatus == "enrolled")) ...[
                    _buildUserSchemesSection(lang),
                    const SizedBox(height: 30),
                  ],
                  Text(lang.translate('welcome_header'),
                      style: GoogleFonts.inter(
                          color: brandPurple,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(lang.translate('welcome_desc'),
                      style: GoogleFonts.inter(
                          color: Colors.black54,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.4)),
                  const SizedBox(height: 30),
                  Text(lang.translate('saving_schemes_title'),
                      style: GoogleFonts.inter(
                          color: const Color.fromARGB(255, 105, 80, 172),
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 15),
                  _buildSchemesCarousel(lang),
                  const SizedBox(height: 20),
                  _buildShowroomCard(lang),
                  const SizedBox(height: 30),
                  Text(lang.translate('promo_title'),
                      style: GoogleFonts.inter(
                          color: brandPurple,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  _buildPromoCarousel(),
                  const SizedBox(height: 30),
                  _buildSocialHelpSection(lang),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),

        bottomNavigationBar: Container(
          height: 56,
          color: brandPurple,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                  icon: const Icon(Icons.home, color: Colors.white, size: 28),
                  onPressed: () {}),
              IconButton(
                  icon: const Icon(Icons.compare_arrows,
                      color: Colors.white70, size: 28),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TransactionsScreen()))),
              
              if (appSettings.showGoldWallet)
                IconButton(
                    icon: const Icon(Icons.account_balance_wallet_outlined,
                        color: Colors.white70, size: 28),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const GoldWalletScreen()))),
              if (appSettings.showRedemption)
                IconButton(
                    icon: const Icon(Icons.card_giftcard,
                        color: Colors.white70, size: 28),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RedemptionPage()))),
              IconButton(
                  icon: const Icon(Icons.person_outline,
                      color: Colors.white70, size: 28),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ProfileScreen()))),
            ],
          ),
        ),
      ),
    );
  }
}