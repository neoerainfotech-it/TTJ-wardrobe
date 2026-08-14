import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// Core Localization & Navigation
import '../core/localization/language_provider.dart';
import '../core/app_settings.dart';
import 'welcome.dart';
import 'profile.dart';
import 'redemption.dart';
import 'gold_wallet.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final Color brandPurple = const Color(0xFF5D1F88);

  Future<List<dynamic>> fetchTransactions() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? userId = prefs.getInt('user_id');

    if (userId == null) return [];

    try {
      final response = await http.get(Uri.parse(
          "https://ttjnextgen.divasprik.in/ttj_api/get_transactions.php?user_id=$userId"));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['status'] == 'success') {
          return result['data'];
        }
      }
    } catch (e) {
      debugPrint("Error fetching transactions: $e");
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (context) => const WelcomeScreen())),
        ),
        title: Text(
          lang.translate('TransactionHistory'),
          style:
              const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: fetchTransactions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No transactions found."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              var tx = snapshot.data![index];

              // 1. Map to 'trans_date' column (Dual-Compatible)
              DateTime date = DateTime.parse(tx['trans_date'] ??
                  tx['created_at'] ??
                  DateTime.now().toString());
              String formattedDate =
                  DateFormat('dd MMM yyyy  hh:mm a').format(date);

              // 🚀 Replaces 'gg', 'g', 'gram', 'grams', or 'garms' unit text from API with 'gm'
              String rawTitle = tx['details'] ?? tx['description'] ?? "Gold Purchase";
              String formattedTitle = rawTitle.replaceAll(
                RegExp(r'(?<=\d|\b)(gg|g|gram|grams|garms)\b', caseSensitive: false),
                'gm',
              );

              return _TransactionTile(
                title: formattedTitle,
                transactionId: tx['payment_id']?.toString() ?? "N/A",
                subtitle: formattedDate,
                amount: tx['amount']?.toString() ?? "0.00",
                status: (tx['type'] == 'Earned' || tx['type'] == 'Credit')
                    ? 'Confirmed'
                    : 'Debit',
                statusKey: (tx['type'] == 'Earned' || tx['type'] == 'Credit')
                    ? 'confirmed'
                    : 'canceled',
              );
            },
          );
        },
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      height: 56,
      color: brandPurple,
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.home_outlined,
                  color: Colors.white70, size: 28),
              onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const WelcomeScreen())),
            ),
            const Icon(Icons.compare_arrows, color: Colors.white, size: 32),
            
            if (appSettings.showGoldWallet)
              IconButton(
                icon: const Icon(Icons.account_balance_wallet_outlined,
                    color: Colors.white70, size: 28),
                onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const GoldWalletScreen())),
              ),
            
            if (appSettings.showRedemption)
              IconButton(
                icon: const Icon(Icons.card_giftcard,
                    color: Colors.white70, size: 28),
                onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const RedemptionPage())),
              ),
              
            IconButton(
              icon: const Icon(Icons.person_outline,
                  color: Colors.white70, size: 28),
              onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ProfileScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final String title;
  final String transactionId;
  final String subtitle;
  final String amount;
  final String status;
  final String statusKey;

  const _TransactionTile({
    required this.title,
    required this.transactionId,
    required this.subtitle,
    required this.amount,
    required this.status,
    required this.statusKey,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor = statusKey == 'confirmed' ? Colors.green : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue.shade50,
            child: Icon(Icons.history, color: Colors.blue.shade300),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text("Transaction ID: $transactionId",
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(subtitle,
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("₹$amount",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(status,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}