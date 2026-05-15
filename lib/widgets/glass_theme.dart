import 'package:flutter/material.dart';

/// Single source of truth for the app's glassmorphic palette.
///
/// The app sits on a warm pink/orange gradient background. Pure
/// `white.withOpacity(0.08)` glass + white text loses contrast there —
/// so the surfaces tilt cool / navy. White text reads cleanly against
/// these dark-tinted surfaces while the gradient still bleeds through.
///
/// Every color is a true `const` so it can be used inside `const`
/// constructors (`const TextStyle(color: GlassTheme.textTertiary)`,
/// `const Text(..., style: ...)`, etc).
class GlassTheme {
  GlassTheme._();

  // ---- Surfaces (cool, dark-tinted glass) -------------------------------
  // Use [surface] for primary text-heavy panels (quiz cards, dialogs,
  // section panels). It's deep enough that body text is comfortably
  // readable on the warm bg.
  static const Color surfaceBase = Color(0xFF0E1A33);

  // Pre-computed translucent variants so they can sit in const contexts.
  // surfaceBase at 55% alpha (0.55 * 255 ≈ 140 = 0x8C).
  static const Color surface = Color(0x8C0E1A33);
  // surfaceBase at 72% alpha (0.72 * 255 ≈ 184 = 0xB8).
  static const Color surfaceStrong = Color(0xB80E1A33);
  // White at 10% alpha (0.10 * 255 ≈ 26 = 0x1A).
  static const Color surfaceSoft = Color(0x1AFFFFFF);

  // White at 18% alpha (0.18 * 255 ≈ 46 = 0x2E).
  static const Color border = Color(0x2EFFFFFF);
  // White at 10% alpha.
  static const Color borderSubtle = Color(0x1AFFFFFF);

  // ---- Text ------------------------------------------------------------
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFD7DEEC); // pale cool gray
  // White at 65% alpha (0.65 * 255 ≈ 166 = 0xA6).
  static const Color textTertiary = Color(0xA6FFFFFF);
  // White at 50% alpha (0.50 * 255 ≈ 128 = 0x80).
  static const Color textMuted = Color(0x80FFFFFF);

  // ---- Accents (cool, high-contrast on warm pink/orange bg) ------------
  static const Color accentBlue = Color(0xFF7AA8FF);
  static const Color accentPurple = Color(0xFFB199FF);
  static const Color accentCyan = Color(0xFF7BE0F6);

  // Status colors — chosen to also work against navy glass surfaces.
  static const Color success = Color(0xFF7CE2C9); // mint
  static const Color danger = Color(0xFFFF7C8B); // rose
  static const Color warning = Color(0xFFFFD27A); // gold (used for achievements)

  // Convenience: a tinted glass decoration matching the app aesthetic.
  // Not const (BoxDecoration with shadows isn't const-friendly), but the
  // raw color tokens above are.
  static BoxDecoration panel({
    double radius = 22,
    Color? surfaceColor,
    bool strong = false,
  }) =>
      BoxDecoration(
        color: surfaceColor ?? (strong
            ? const Color(0x30FFFFFF)   // ~19% white for strong panels
            : const Color(0x1EFFFFFF)), // ~12% white for regular panels
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0x40FFFFFF)), // slightly brighter border
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      );

  // ---- Folder tint palette --------------------------------------------
  // Saturated, slightly desaturated-toward-pastel tones that read cleanly
  // both against the warm pink/orange background gradient and on top of
  // the navy glass surfaces. Roughly evenly-spaced around the hue wheel
  // so adjacent folders are easy to tell apart.
  static const List<Color> folderPalette = <Color>[
    Color(0xFFFF8A65), // coral
    Color(0xFFFFB74D), // amber
    Color(0xFFFFD54F), // sunflower
    Color(0xFFAED581), // lime
    Color(0xFF4DD0E1), // cyan
    Color(0xFF64B5F6), // sky blue
    Color(0xFF9575CD), // lavender
    Color(0xFFF06292), // rose
    Color(0xFF4DB6AC), // teal
    Color(0xFFBA68C8), // orchid
  ];

  /// Returns a stable folder tint color for a category.
  ///
  /// Prefers the persistent ObjectBox [id] so adjacent folders rotate
  /// cleanly through the palette and the same folder keeps its color
  /// forever. Falls back to hashing [name] when the category hasn't been
  /// persisted yet (id == 0).
  static Color folderColor({required int id, required String name}) {
    if (id > 0) {
      // 1-based modulo so a freshly-created folder doesn't always land
      // on the same first palette entry.
      return folderPalette[(id - 1) % folderPalette.length];
    }
    if (name.isEmpty) return folderPalette.first;
    // FNV-1a 32-bit — small, deterministic, no platform deps.
    int hash = 0x811c9dc5;
    for (final code in name.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return folderPalette[hash % folderPalette.length];
  }
}
