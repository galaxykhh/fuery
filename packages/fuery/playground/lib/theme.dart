import 'package:flutter/material.dart';

/// The Fuery palette.
abstract final class Brand {
  static const violet = Color(0xFF6B4EFF);
  static const lime = Color(0xFFC6F542);
  static const lavender = Color(0xFFC9BEFF);
  static const ink = Color(0xFF14112B);
}

/// The font of the code panel and of values in the state panels.
const monoFamily = 'RobotoMono';

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.violet,
    brightness: brightness,
  ).copyWith(
    primary: dark ? Brand.lavender : Brand.violet,
    onPrimary: dark ? Brand.ink : Colors.white,
    primaryContainer: dark ? const Color(0xFF2E2766) : const Color(0xFFECE8FF),
    onPrimaryContainer: dark ? Brand.lavender : const Color(0xFF3A26B8),
    secondary: dark ? Brand.lime : const Color(0xFF4F6B00),
    onSecondary: dark ? Brand.ink : Colors.white,
    // Tonal buttons and selected segments: calm lavender, so lime stays for
    // what is fresh and successful.
    secondaryContainer:
        dark ? const Color(0xFF332B70) : const Color(0xFFE4DEFF),
    onSecondaryContainer:
        dark ? const Color(0xFFE4DEFF) : const Color(0xFF2A1B8F),
    surface: dark ? const Color(0xFF1A1633) : Colors.white,
    onSurface: dark ? const Color(0xFFEDEBF7) : Brand.ink,
    onSurfaceVariant: dark ? const Color(0xFFB4AFCF) : const Color(0xFF5B5775),
    surfaceContainerLowest: dark ? const Color(0xFF110E24) : Colors.white,
    surfaceContainerLow: dark ? Brand.ink : const Color(0xFFF7F6FC),
    surfaceContainer: dark ? const Color(0xFF1F1A3D) : const Color(0xFFF1EFFA),
    surfaceContainerHigh:
        dark ? const Color(0xFF282248) : const Color(0xFFEAE7F7),
    outline: dark ? const Color(0xFF4A4470) : const Color(0xFFCFCBE3),
    outlineVariant: dark ? const Color(0xFF2E2852) : const Color(0xFFE6E3F2),
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surfaceContainerLow,
    dividerColor: scheme.outlineVariant,
    visualDensity: VisualDensity.standard,
  );
}

/// Colors for the pills of the state panels.
class Tone {
  const Tone(this.background, this.foreground);

  final Color background;
  final Color foreground;

  static Tone neutral(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tone(scheme.surfaceContainerHigh, scheme.onSurfaceVariant);
  }

  static Tone good(BuildContext context) => const Tone(Brand.lime, Brand.ink);

  static Tone active(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark
        ? const Tone(Brand.lavender, Brand.ink)
        : const Tone(Brand.violet, Colors.white);
  }

  static Tone waiting(BuildContext context) =>
      const Tone(Color(0xFFFFD27A), Brand.ink);

  static Tone bad(BuildContext context) =>
      const Tone(Color(0xFFE5484D), Colors.white);
}
