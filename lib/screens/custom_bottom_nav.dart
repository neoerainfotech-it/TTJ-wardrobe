// custom_bottom_nav.dart
import 'package:flutter/material.dart';
import '../core/app_settings.dart'; // Ensure this points to your new settings file

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  const CustomBottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    // brandPurple color from WelcomeScreen
    const Color brandPurple = Color(0xFF5D1F88);

    return Container(
      height: 60, // Consistent height for touch targets
      color: brandPurple,
      child: SafeArea(
        top: false, // Ensures buttons are accessible above the hidden system bar
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(context, Icons.home, 0, '/dashboard'),
            _buildNavItem(context, Icons.compare_arrows, 1, '/transactions'),
            
            // MAGIC HERE: Only add Gold Wallet if the CMS says True!
            if (appSettings.showGoldWallet)
              _buildNavItem(context, Icons.account_balance_wallet_outlined, 2, '/gold_wallet'),
              
            // MAGIC HERE: Only add Redemption if the CMS says True!
            if (appSettings.showRedemption)
              _buildNavItem(context, Icons.card_giftcard, 3, '/redemption'),
              
            _buildNavItem(context, Icons.person_outline, 4, '/profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, int index, String route) {
    bool isActive = currentIndex == index;
    return IconButton(
      icon: Icon(
        icon, 
        color: isActive ? Colors.white : Colors.white70, 
        size: 28
      ),
      onPressed: () {
        if (!isActive) {
          Navigator.pushNamed(context, route);
        }
      },
    );
  }
}