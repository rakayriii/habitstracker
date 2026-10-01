import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/design_tokens.dart';

/// Typography from DESIGN.md. Poppins carries headings, Geist carries body and
/// narrative copy, Plus Jakarta Sans carries every number so balances and
/// timestamps align in dense ledgers (tabular figures).
class MyOSText {
  const MyOSText._();

  static const _tabular = <FontFeature>[FontFeature.tabularFigures()];

  static const headlineLg = TextStyle(
    fontFamily: MyOSFonts.heading,
    fontSize: 30,
    fontWeight: FontWeight.w600,
    height: 38 / 30,
    letterSpacing: -0.6,
    color: MyOSColors.textPrimary,
  );

  static const headlineMd = TextStyle(
    fontFamily: MyOSFonts.heading,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 28 / 22,
    letterSpacing: -0.33,
    color: MyOSColors.textPrimary,
  );

  static const headlineSm = TextStyle(
    fontFamily: MyOSFonts.heading,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 22 / 17,
    letterSpacing: -0.17,
    color: MyOSColors.textPrimary,
  );

  /// Card title. Poppins owns screen and section structure, Geist owns content
  /// inside a card, Plus Jakarta Sans owns every number. Keeping the three
  /// roles separate is what stops a dense ledger from reading as one wall of
  /// headings.
  static const cardTitle = TextStyle(
    fontFamily: MyOSFonts.body,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 20 / 15,
    color: MyOSColors.textPrimary,
  );

  static const bodyLg = TextStyle(
    fontFamily: MyOSFonts.body,
    fontSize: 16,
    height: 24 / 16,
    letterSpacing: -0.08,
    color: MyOSColors.textPrimary,
  );

  static const bodyMd = TextStyle(
    fontFamily: MyOSFonts.body,
    fontSize: 14,
    height: 20 / 14,
    color: MyOSColors.textPrimary,
  );

  static const bodySm = TextStyle(
    fontFamily: MyOSFonts.body,
    fontSize: 12,
    height: 16 / 12,
    letterSpacing: 0.12,
    color: MyOSColors.textSecondary,
  );

  static const labelLg = TextStyle(
    fontFamily: MyOSFonts.data,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 18 / 14,
    letterSpacing: 0.14,
    color: MyOSColors.textPrimary,
  );

  static const labelMd = TextStyle(
    fontFamily: MyOSFonts.data,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
    letterSpacing: 0.24,
    color: MyOSColors.textSecondary,
  );

  /// Micro-label. DESIGN.md: uppercase system status with +0.03em tracking.
  static const labelSm = TextStyle(
    fontFamily: MyOSFonts.data,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 14 / 11,
    letterSpacing: 0.33,
    color: MyOSColors.textMuted,
  );

  static const dataLg = TextStyle(
    fontFamily: MyOSFonts.data,
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 24 / 20,
    letterSpacing: -0.4,
    color: MyOSColors.textPrimary,
    fontFeatures: _tabular,
  );

  static const dataMd = TextStyle(
    fontFamily: MyOSFonts.data,
    fontSize: 14,
    height: 18 / 14,
    letterSpacing: -0.14,
    color: MyOSColors.textPrimary,
    fontFeatures: _tabular,
  );

  static const dataSm = TextStyle(
    fontFamily: MyOSFonts.data,
    fontSize: 11,
    height: 14 / 11,
    color: MyOSColors.textMuted,
    fontFeatures: _tabular,
  );
}

class MyOSTheme {
  const MyOSTheme._();

  static const systemUi = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: MyOSColors.canvas,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: MyOSColors.border,
  );

  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: MyOSColors.canvas,
    canvasColor: MyOSColors.canvas,
    colorScheme: const ColorScheme.dark(
      surface: MyOSColors.surface,
      primary: MyOSColors.accent,
      onPrimary: MyOSColors.canvas,
      secondary: MyOSColors.accentDim,
      error: MyOSColors.negative,
      onSurface: MyOSColors.textPrimary,
    ),
    textTheme: const TextTheme(
      headlineLarge: MyOSText.headlineLg,
      headlineMedium: MyOSText.headlineMd,
      headlineSmall: MyOSText.headlineSm,
      bodyLarge: MyOSText.bodyLg,
      bodyMedium: MyOSText.bodyMd,
      bodySmall: MyOSText.bodySm,
      labelLarge: MyOSText.labelLg,
      labelMedium: MyOSText.labelMd,
      labelSmall: MyOSText.labelSm,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: MyOSColors.canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: systemUi,
    ),
    splashFactory: InkSparkle.splashFactory,
    dividerTheme: const DividerThemeData(
      color: MyOSColors.hairline,
      thickness: 1,
      space: 1,
    ),
  );
}
