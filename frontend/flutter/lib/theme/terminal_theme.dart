import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Rail Signage / Data Terminal design system.
/// Amber-on-black departure-board aesthetic, monospace type, hard edges.
class Terminal {
  static const Color black = Color(0xFF0A0A0A);
  static const Color panel = Color(0xFF151515);
  static const Color panelLift = Color(0xFF1D1D1D);
  static const Color amber = Color(0xFFFFB000);
  static const Color amberDim = Color(0xFF8A6A00);
  static const Color green = Color(0xFF00E08A);
  static const Color red = Color(0xFFFF4D4D);
  static const Color cyan = Color(0xFF00E0E0);
  static const Color white = Color(0xFFF2F2F2);
  static const Color dim = Color(0xFF6E6E6E);
  static const Color hairline = Color(0xFF2A2A2A);

  static TextStyle mono(
    double size, {
    Color color = amber,
    FontWeight weight = FontWeight.w600,
    double? spacing,
    double height = 1.3,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      color: color,
      fontWeight: weight,
      letterSpacing: spacing,
      height: height,
    );
  }

  static ThemeData theme() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: black,
      colorScheme: const ColorScheme.dark(
        primary: amber,
        secondary: green,
        surface: panel,
        onPrimary: black,
        onSecondary: black,
        onSurface: white,
        error: red,
      ),
      textTheme: TextTheme(
        displayLarge: mono(56, spacing: -2),
        displayMedium: mono(40, spacing: -1),
        headlineMedium: mono(28),
        titleLarge: mono(22, color: white),
        titleMedium: mono(18, color: white),
        bodyLarge: mono(16, color: white),
        bodyMedium: mono(14, color: dim),
        labelLarge: mono(15, color: amber),
      ),
      dividerColor: hairline,
      appBarTheme: const AppBarTheme(
        backgroundColor: black,
        foregroundColor: white,
        elevation: 0,
      ),
    );
  }
}

/// Split-flap cell. Simulates the physical departure-board flaps.
class SplitFlap extends StatelessWidget {
  final String text;
  final double height;
  final double width;
  final Color color;
  final FontWeight weight;
  final Color? bg;
  final double fontSize;
  final double letterSpacing;

  const SplitFlap(
    this.text, {
    super.key,
    this.height = 48,
    this.width = 64,
    this.color = Terminal.amber,
    this.weight = FontWeight.w700,
    this.bg = const Color(0xFF191919),
    this.fontSize = 30,
    this.letterSpacing = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: Terminal.hairline, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black87, offset: Offset(0, 2), blurRadius: 4),
        ],
      ),
      child: Center(
        child: Container(
          width: width - 10,
          height: height / 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [const Color(0xFF111111), (bg ?? Terminal.panel).withValues(alpha: 0.6)],
            ),
          ),
          child: Center(
            child: Text(
              text,
              style: Terminal.mono(fontSize,
                  color: color, weight: weight, spacing: letterSpacing),
            ),
          ),
        ),
      ),
    );
  }
}

/// A full split-flap departure board row: label + value.
class DepartureRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final double flapWidth;

  const DepartureRow({
    super.key,
    required this.label,
    required this.value,
    this.color = Terminal.white,
    this.flapWidth = 180,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: Terminal.mono(12, color: Terminal.dim, spacing: 1.5),
            ),
          ),
          SplitFlap(
            value,
            width: flapWidth,
            height: 40,
            fontSize: 20,
            color: color,
          ),
        ],
      ),
    );
  }
}

/// Corner-bracket terminal panel.
class TerminalPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color borderColor;

  const TerminalPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor = Terminal.amber,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Terminal.panel,
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Stack(
        children: [
          child,
          Positioned(
            top: -1,
            left: -1,
            child: _corner(top: true, left: true),
          ),
          Positioned(
            top: -1,
            right: -1,
            child: _corner(top: true, left: false),
          ),
          Positioned(
            bottom: -1,
            left: -1,
            child: _corner(top: false, left: true),
          ),
          Positioned(
            bottom: -1,
            right: -1,
            child: _corner(top: false, left: false),
          ),
        ],
      ),
    );
  }

  Widget _corner({required bool top, required bool left}) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        border: Border(
          top: top ? BorderSide(color: borderColor, width: 3) : BorderSide.none,
          bottom: !top ? BorderSide(color: borderColor, width: 3) : BorderSide.none,
          left: left ? BorderSide(color: borderColor, width: 3) : BorderSide.none,
          right: !left ? BorderSide(color: borderColor, width: 3) : BorderSide.none,
        ),
      ),
    );
  }
}

/// Blinking caret "live" indicator.
class LiveIndicator extends StatelessWidget {
  final String text;
  const LiveIndicator(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: Terminal.green,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(text, style: Terminal.mono(12, color: Terminal.green, spacing: 1.5)),
      ],
    );
  }
}

/// Header bar styled like a station sign.
class SignHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SignHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: Terminal.amber,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: Terminal.mono(18, color: Terminal.black, weight: FontWeight.w700, spacing: 2),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Terminal-style button (hard edge, square, amber).
class TermButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final Color color;
  final double height;

  const TermButton({
    super.key,
    required this.label,
    this.onPressed,
    this.filled = true,
    this.color = Terminal.amber,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final bg = filled ? color : Colors.transparent;
    final fg = filled ? Terminal.black : color;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Material(
        color: bg,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 2),
            ),
            child: Center(
              child: Text(
                label.toUpperCase(),
                style: Terminal.mono(15, color: fg, weight: FontWeight.w700, spacing: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
