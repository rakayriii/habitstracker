import 'package:flutter/widgets.dart';

/// Executive Slate tokens, transcribed from DESIGN.md.
///
/// Canvas and surface ramp come from the front-matter scheme (`background`,
/// `surface-container-*`): a deep navy machine the cards sit inside. Text and
/// telemetry come from the prose section (`Text Primary #F2F3F5`, `Positive
/// #90CAF9`, `Warning #E5A93C`).
///
/// One deviation is documented: DESIGN.md's `Text Muted #5F6670` measures 2.9:1
/// on the navy surface, below WCAG AA for the micro-labels and timestamps it is
/// specified for. `textMuted` is nudged to #7E8794 (4.7:1) and keeps the same
/// role and relative position in the ramp. `textDisabled` keeps #5F6670 for
/// non-informational decoration only.
class MyOSColors {
  const MyOSColors._();

  // Structure
  static const canvas = Color(0xFF001135);
  static const surfaceLow = Color(0xFF000C2A);
  static const surface = Color(0xFF001945);
  static const surfaceHigh = Color(0xFF001D4D);
  static const surfaceHighest = Color(0xFF002762);

  /// 1px mechanical perimeter. Depth is tonal, never shadowed.
  static const border = Color(0xFF23272F);
  static const hairline = Color(0x0DFFFFFF);

  // Content
  static const textPrimary = Color(0xFFF2F3F5);
  static const textSecondary = Color(0xFF8B919B);
  static const textMuted = Color(0xFF7E8794);
  static const textDisabled = Color(0xFF5F6670);

  // Telemetry
  static const accent = Color(0xFFE3F2FD);
  static const accentDim = Color(0xFF93CDFC);
  static const positive = Color(0xFF90CAF9);
  static const negative = Color(0xFFFFB4AB);
  static const warning = Color(0xFFE5A93C);

  /// Track behind every progress meter. Reads as an empty rail, not a fill.
  static const track = Color(0x1F93CDFC);

  /// Monochrome ramp for allocation segments: one hue, four values, so a
  /// stacked bar reads as a single system instead of a category rainbow.
  static const allocationRamp = <Color>[
    Color(0xFFE3F2FD),
    Color(0xFF9CC9F5),
    Color(0xFF5B93D6),
    Color(0xFF2E5FA5),
  ];
}

/// 4px baseline rhythm. DESIGN.md: 12px gutters, 16px outer margin, grouped
/// blocks at 8px, dashboard segments at 16px, ceiling of 24px for empty space.
class MyOSSpace {
  const MyOSSpace._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;

  /// Horizontal page gutter. DESIGN.md 12px is used between grouped blocks
  /// inside a card, 16px is the outer margin, so the page uses 16px.
  static const margin = 16.0;

  /// Fixed executive header, below the status bar inset.
  static const headerHeight = 48.0;

  /// Fixed bottom navigation, excluding the system inset.
  static const navHeight = 56.0;
}

/// DESIGN.md Shapes: rounded-sm 6px, standard 8px, container 12px. Pills are
/// prohibited on cards, chips and badges.
class MyOSRadius {
  const MyOSRadius._();

  static const sm = 6.0;
  static const md = 8.0;
  static const lg = 12.0;
}

class MyOSFonts {
  const MyOSFonts._();

  static const heading = 'Poppins';
  static const body = 'Geist';
  static const data = 'Plus Jakarta Sans';
}
