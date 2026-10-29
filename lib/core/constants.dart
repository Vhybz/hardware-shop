import 'package:flutter/material.dart';

/// Design System Specification & Token Definitions
class AppColors {
  // 1. Brand & Primary Palette (Construction Gold & Hardware Yellow Default)
  static const Color constructionGold = Color(0xFFF59E0B); // DeWalt Hardware Amber Gold
  static const Color primaryMaroon = Color(0xFFF59E0B); // Default Theme Color (Construction Amber Gold)
  static const Color secondaryMaroon = Color(0xFF18181B); // Hardware Onyx Black
  static const Color primaryYellowMaroon = Color(0xFFEAB308); // Construction Gold Yellow
  static const Color primaryBlue = Color(0xFF0284C7); // Sky Blue
  static const Color primaryGreen = Color(0xFF10B981); // Safety Green
  static const Color primaryPink = Color(0xFF880E4F); // Rose Pink

  // Backward compatibility alias tokens
  static const Color hardwareDeepRed = Color(0xFF4A0808);
  static const Color hardwareBrown = Color(0xFF4A0808);
  static const Color hardwareBlack = Color(0xFF121212);
  static const Color hardwareAsh = Color(0xFF455A64);
  static const Color hardwareQledRed = Color(0xFFB71C1C);
  static const Color hardwareBlueBlack = Color(0xFF0D47A1);
  static const Color hardwareDeepYellow = Color(0xFFE65100);
  static const Color primaryBlueBlack = Color(0xFF121212);
  static const Color deepBlack = Color(0xFF000000);

  // 2. Neutral & Surface Tokens
  static const Color surfaceWhite = Color(0xFFECEFF1); // Premium Slate Light Surface
  static const Color textDark = Color(0xFF121212); // High Emphasis Text
  static const Color textLight = Color(0xFF455A64); // Medium Emphasis Text Muted
  static const Color borderGray = Color(0xFFCFD8DC); // Border Gray
  static const Color cardShadow = Color(0x1A000000); // Card Elevation Shadow

  // 3. Semantic Financial & Status Accents
  static const Color success = Color(0xFF1B5E20); // Success / Revenue / Paid (Deep Green)
  static const Color warning = Color(0xFFE65100); // Warning / Salary Advance / Low Stock (Vibrant Amber/Orange)
  static const Color danger = Color(0xFFB71C1C); // Danger / Debt / Cancelled / Reversal (Crimson Red)
  static const Color loan = Color(0xFF7B1FA2); // Loans / Bank Deposits (Deep Royal Purple)
  static const Color loanRepayment = Color(0xFF00796B); // Loan Repayment / Verified (Teal)

  static const Color accentGreen = Color(0xFF1B5E20);
  static const Color accentOrange = Color(0xFFE65100);
}

/// Spacing Scale
class AppSpacing {
  static const double xs = 4.0;
  static const double s = 8.0;
  static const double m = 16.0;
  static const double l = 24.0;
  static const double xl = 32.0;
}

/// Border Radius Scale
class AppRadius {
  static const double s = 8.0;
  static const double m = 12.0;
  static const double l = 16.0;
  static const double xl = 24.0;
}
