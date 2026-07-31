import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// Navigation Screens
import 'gold_wallet.dart';
import 'welcome.dart';
import 'transactions.dart';
import 'profile.dart';

// Core Localization Import
import '../core/localization/language_provider.dart';

class RedemptionPage extends StatefulWidget {
  const RedemptionPage({super.key});

  @override
  State<RedemptionPage> createState() => _RedemptionPageState();
}

class _RedemptionPageState extends State<RedemptionPage> {
  final Color brandPurple = const Color(0xFF5D1F88);
  final Color lightPinkBg = const Color(0xFFF8BBD0);
  final Color lightBlueBg = const Color(0xFFD1E3FF);

  String totalPoints = "0";
  String expiringPoints = "0";
  String expirySubtitle = ""; 
  List<dynamic> historyList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLoyaltyData();
  }

  // --- FETCH LOGIC (SAFE VERSION WITH CORRECT EXPIRY MATH) ---
  Future<void> _fetchLoyaltyData() async {
    final prefs = await SharedPreferences.getInstance();
    final int? userId = prefs.getInt('user_id');

    if (userId == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse("https://ttjnextgen.divasprik.in/ttj_api/get_loyalty_points.php?user_id=$userId"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          if (mounted) {
            setState(() {
              totalPoints = data['total_points'].toString();
              expiringPoints = data['expiring_points'].toString();
              historyList = data['history'];

              // Parse days safely
              int? days;
              if (data['days_to_expire'] != null) {
                days = int.tryParse(data['days_to_expire'].toString());
              }
              
              // Set Subtitle Text Logic
              double expPointsVal = double.tryParse(expiringPoints) ?? 0;
              
              if (days != null && expPointsVal > 0) {
                if (days < 0) {
                  expirySubtitle = "Expired!"; // Fixed: Handles past dates correctly
                } else if (days == 0) {
                  expirySubtitle = "Expires Today!";
                } else if (days == 1) {
                  expirySubtitle = "Expires in 1 day";
                } else {
                  expirySubtitle = "Expires in $days days";
                }
              } else {
                expirySubtitle = ""; // Hide if 0 points or no expiry
              }
              
              isLoading = false;
            });
          }
        }
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching loyalty data: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    LanguageProvider? lang;
    try { lang = Provider.of<LanguageProvider>(context); } catch (_) {}

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          lang?.translate('LoyaltyPointsTitle') ?? 'Loyalty Points',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: brandPurple))
          : RefreshIndicator(
              onRefresh: _fetchLoyaltyData,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // --- SUMMARY CARDS ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      _buildSummaryCard(
                        lang?.translate('TotalPoints') ?? 'Total Points', 
                        "$totalPoints Pts"
                      ),
                      const SizedBox(width: 16),
                      _buildSummaryCard(
                        lang?.translate('PointsExpire') ?? 'Points Expire', 
                        "$expiringPoints Pts",
                        subtitle: expirySubtitle 
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  const Text("Recent History", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  
                  historyList.isEmpty
                      ? const Center(child: Padding(padding: EdgeInsets.all(50.0), child: Text("No transactions yet", style: TextStyle(color: Colors.grey))))
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: historyList.length,
                          itemBuilder: (context, index) {
                            final item = historyList[index];
                            return _HistoryCard(
                              title: item['description'] ?? "Store Purchase",
                              id: item['id']?.toString() ?? "-",
                              points: "${item['points']} Pts",
                              type: item['type'] ?? 'Earned',
                              date: item['date'],
                              amountSpent: item['amount'],
                            );
                          },
                        ),
                ],
              ),
            ),
      bottomNavigationBar: Container(
        height: 56,
        color: brandPurple,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(icon: const Icon(Icons.home_outlined, color: Colors.white70, size: 28), onPressed: () => _navigateTo(context, const WelcomeScreen())),
            IconButton(icon: const Icon(Icons.swap_horiz, color: Colors.white70, size: 28), onPressed: () => _navigateTo(context, const TransactionsScreen())),
            IconButton(icon: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white70, size: 28), onPressed: () => _navigateTo(context, const GoldWalletScreen())),
            const Icon(Icons.card_giftcard, color: Colors.white, size: 32),
            IconButton(icon: const Icon(Icons.person_outline, color: Colors.white70, size: 28), onPressed: () => _navigateTo(context, const ProfileScreen())),
          ],
        ),
      ),
    );
  }

  // --- UPDATED WIDGET TO SHOW SUBTITLE ---
  Widget _buildSummaryCard(String label, String value, {String subtitle = ""}) {
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 100), 
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(color: lightPinkBg, borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(color: brandPurple, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(color: brandPurple, fontSize: 18, fontWeight: FontWeight.w900)),
            
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.withOpacity(0.3), width: 1)
                ),
                child: Text(
                  subtitle, 
                  style: const TextStyle(color: Color(0xFFC62828), fontSize: 11, fontWeight: FontWeight.bold)
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final String title, id, points, date, type;
  final dynamic amountSpent;

  const _HistoryCard({required this.title, required this.id, required this.points, required this.date, required this.type, this.amountSpent});

  @override
  Widget build(BuildContext context) {
    bool isRedemption = type == 'Redeemed';
    Color pointColor = isRedemption ? Colors.red : Colors.green;
    String displayPoints = (!isRedemption && !points.startsWith('+')) ? "+$points" : points;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10), 
            decoration: BoxDecoration(color: const Color(0xFFD1E3FF), borderRadius: BorderRadius.circular(10)), 
            child: const Icon(Icons.stars, color: Color(0xFF5D1F88), size: 24)
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 2),
            Text("Ref ID: $id", style: const TextStyle(color: Colors.grey, fontSize: 11)),
            if (amountSpent != null && amountSpent != "0.00" && amountSpent != 0) 
              Text("Bill: ₹$amountSpent", style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(displayPoints, style: TextStyle(color: pointColor, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text(date, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          ]),
        ],
      ),
    );
  }
}