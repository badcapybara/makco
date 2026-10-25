import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/madras_flow.dart';

/// Signature ticket-stub card: rounded corners with two notches on the top edge.
class TicketCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Border? border;
  final VoidCallback? onTap;

  const TicketCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 20, 18, 18),
    this.color = Mf.surface,
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TicketPainter(
        color: color,
        border: border ?? Border.all(color: Mf.hairline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _TicketPainter extends CustomPainter {
  final Color color;
  final Border border;
  _TicketPainter({required this.color, required this.border});

  @override
  void paint(Canvas canvas, Size size) {
    final notchR = 10.0;
    final r = 20.0;
    final inset = size.width / 2 - 34;

    final path = Path()
      ..moveTo(inset - notchR, 0)
      ..arcToPoint(Offset(inset + notchR, 0), radius: Radius.circular(notchR))
      ..lineTo(size.width - r, 0)
      ..quadraticBezierTo(size.width, 0, size.width, r)
      ..lineTo(size.width, size.height - r)
      ..quadraticBezierTo(size.width, size.height, size.width - r, size.height)
      ..lineTo(size.width - inset - notchR, size.height)
      ..arcToPoint(
        Offset(size.width - inset + notchR, size.height),
        radius: Radius.circular(notchR),
      )
      ..lineTo(r, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - r)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..close();

    canvas.drawPath(path, Paint()..color = color);

    final top = border.top.color;
    final left = border.left.color;
    if (top != Colors.transparent) {
      final line = Path()
        ..moveTo(inset - notchR, 0.6)
        ..lineTo(size.width - r, 0.6)
        ..moveTo(0.6, r)
        ..lineTo(0.6, size.height - r)
        ..moveTo(size.width - 0.6, r)
        ..lineTo(size.width - 0.6, size.height - r)
        ..moveTo(inset - notchR, size.height - 0.6)
        ..lineTo(size.width - r, size.height - 0.6)
        ..moveTo(r, size.height - 0.6)
        ..lineTo(size.width - inset + notchR, size.height - 0.6);
      // placeholders to keep border color references
      canvas.drawPath(
        line,
        Paint()..color = left == Colors.transparent ? top : top,
      );
    }
  }

  @override
  bool shouldRepaint(_TicketPainter old) => old.color != color;
}

/// Soft-filled status chip.
class StatusChip extends StatelessWidget {
  final String label;
  final StatusKind kind;
  const StatusChip(this.label, {super.key, this.kind = StatusKind.info});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      StatusKind.success => (Mf.greenSoft, Mf.green),
      StatusKind.error => (Mf.coralSoft, Mf.coral),
      StatusKind.info => (Mf.tealSoft, Mf.teal),
      StatusKind.neutral => (Mf.surfaceAlt, Mf.inkMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: Mf.overline(
          color: fg,
        ).copyWith(letterSpacing: 0.8, fontSize: 10),
      ),
    );
  }
}

enum StatusKind { success, error, info, neutral }

/// Pill primary button (amber).
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  const PrimaryButton(
    this.label, {
    super.key,
    this.onPressed,
    this.icon,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: enabled ? Mf.amber : Mf.amber.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Mf.ink,
                    ),
                  )
                else if (icon != null) ...[
                  Icon(icon, size: 20, color: Mf.ink),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: Mf.body(16, color: Mf.ink, weight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tonal teal secondary button.
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  const SecondaryButton(this.label, {super.key, this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: Mf.tealSoft,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: Mf.teal),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: Mf.body(16, color: Mf.teal, weight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ghost/outline button.
class GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  const GhostButton(
    this.label, {
    super.key,
    this.onPressed,
    this.color = Mf.teal,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: color, width: 1.4),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Center(
            child: Text(
              label,
              style: Mf.body(15, color: color, weight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

/// Route line: origin -> destination with a connecting line and meta chip.
class RouteRow extends StatelessWidget {
  final String from;
  final String to;
  final String? meta;
  const RouteRow({super.key, required this.from, required this.to, this.meta});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                from,
                style: Mf.body(16, weight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(width: 34, height: 2, color: Mf.hairline),
                    Icon(
                      Icons.arrow_right_rounded,
                      size: 16,
                      color: Mf.inkFaint,
                    ),
                  ],
                ),
              ),
              Text(
                to,
                style: Mf.body(16, weight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (meta != null)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: StatusChip(meta!, kind: StatusKind.info),
          ),
      ],
    );
  }
}

/// Large tabular fare.
class FareTag extends StatelessWidget {
  final num amount;
  final double size;
  const FareTag(this.amount, {super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '₹',
            style: Mf.price(size * 0.72, color: Mf.inkMuted),
          ),
          TextSpan(
            text: '${amount.round()}',
            style: Mf.price(size, color: Mf.ink, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Gopuram step motif — layered tiers behind a headline or divider.
class GopuramMark extends StatelessWidget {
  final double width;
  final Color color;
  const GopuramMark({super.key, this.width = 72, this.color = Mf.amber});

  @override
  Widget build(BuildContext context) {
    final step = width / 4;
    return SizedBox(
      width: width,
      height: step * 2.4,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(width: width, height: step, color: color),
          Container(width: width * 0.72, height: step, color: color),
          Container(width: width * 0.42, height: step, color: color),
        ],
      ),
    );
  }
}

/// Soft filled text field per Madras Flow.
class InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String label;
  final TextInputType keyboardType;
  final int? maxLength;
  final bool numeric;
  const InputField({
    super.key,
    required this.controller,
    required this.hint,
    required this.label,
    this.keyboardType = TextInputType.text,
    this.maxLength,
    this.numeric = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Mf.body(13, color: Mf.inkMuted, weight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          inputFormatters: numeric
              ? [FilteringTextInputFormatter.digitsOnly]
              : null,
          style: Mf.body(17, weight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: Mf.body(16, color: Mf.inkFaint),
            counterText: '',
            filled: true,
            fillColor: Mf.surfaceAlt,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Mf.amber, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// Friendly skeleton for loading.
class SkeletonCard extends StatelessWidget {
  final double height;
  const SkeletonCard({super.key, this.height = 92});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Mf.surfaceAlt.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}
