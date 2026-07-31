import 'package:flutter/material.dart';

class SchemeDetailsScreen extends StatelessWidget {
  final String planName;
  final String description;
  final String colorHex;

  const SchemeDetailsScreen({
    super.key, 
    required this.planName, 
    required this.description,
    required this.colorHex,
  });

  @override
  Widget build(BuildContext context) {
    // Convert DB hex string to Flutter Color
    final Color themeColor = Color(int.parse(colorHex.replaceAll('#', '0xFF')));

    return Scaffold(
      appBar: AppBar(
        title: Text(planName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: themeColor.withOpacity(0.1),
                border: Border.all(color: themeColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.black54),
                  SizedBox(width: 10),
                  Text("Terms & Information", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 25),
            // THIS RENDERS THE DYNAMIC CONTENT FROM YOUR CMS
            Text(
              description, 
              style: const TextStyle(
                fontSize: 16, 
                height: 1.6, 
                color: Colors.black87,
                fontFamily: 'Montserrat',
              ),
              softWrap: true,
            ),
          ],
        ),
      ),
    );
  }
}