import 'package:flutter/cupertino.dart';

// ==========================================
// COLORS & THEME
// ==========================================
const kBg = Color(0xFF0A0A0A);
const kCard = Color(0xFF141414);
const kBorder = Color(0xFF2A2A2A);
const kNeon = Color(0xFFE5FF00);
const kTeal = Color(0xFF00FFD1);
const kPink = Color(0xFFFF0055);

// ==========================================
// BENTO CARD
// ==========================================
class BentoCard extends StatelessWidget {
  final Widget child;
  final double? height;
  final double? width;
  final EdgeInsets padding;
  final Color glowColor;

  const BentoCard({
    super.key,
    required this.child,
    this.height,
    this.width,
    this.padding = const EdgeInsets.all(20),
    this.glowColor = const Color(0x33E5FF00),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: kBorder, width: 1),
        boxShadow: [BoxShadow(color: glowColor, blurRadius: 40, spreadRadius: -10)],
      ),
      child: child,
    );
  }
}

// ==========================================
// NEON BUTTON
// ==========================================
class NeonButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final Color color;

  const NeonButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.color = kNeon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(100),
          boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 20, spreadRadius: 2)],
        ),
        child: Center(
          child: isLoading
              ? const CupertinoActivityIndicator(color: kBg)
              : Text(
                  text.toUpperCase(),
                  style: const TextStyle(color: kBg, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.5),
                ),
        ),
      ),
    );
  }
}

// ==========================================
// STAT TILE
// ==========================================
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final double fillFraction;
  final VoidCallback? onTap;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.fillFraction = 0.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: onTap != null ? color.withOpacity(0.3) : kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              if (onTap != null) Icon(CupertinoIcons.chevron_right, color: color.withOpacity(0.5), size: 10),
            ]),
            // FittedBox scales down the value if it's too long (e.g. "2300mg")
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: const TextStyle(color: CupertinoColors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            ),
            Text(unit, style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 9), overflow: TextOverflow.ellipsis, maxLines: 1),
            const SizedBox(height: 4),
            Container(
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(2)),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fillFraction.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ==========================================
// SECTION HEADER
// ==========================================
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const SectionHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: CupertinoColors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          if (subtitle != null)
            Text(subtitle!, style: const TextStyle(color: kTeal, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
