import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LearningTradingComingSoon extends StatelessWidget {
  const LearningTradingComingSoon({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F8),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 216, 169, 130),
        title: const Text("Learning Trading"),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_rounded,
              size: 90,
              color: Colors.blueAccent,
            ),
            const SizedBox(height: 20),
            Text(
              "Learning Trading",
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2D3142),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Coming Soon 🚀",
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
