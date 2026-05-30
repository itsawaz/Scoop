import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, LinearGradient, RadialGradient;

// ============================================================
// HOOP — NOVA DESIGN SYSTEM
// ============================================================

// Core colours
const kBg       = Color(0xFF050508);
const kSurface  = Color(0xFF0F0F14);
const kSurface2 = Color(0xFF18181F);
const kBorder   = Color(0xFF1E1E2A);
const kBorder2  = Color(0xFF2A2A3A);
const kCard     = kSurface; // Legacy alias

// Accent palette
const kNeon   = Color(0xFFCDFF3C);   // Electric lime – primary
const kTeal   = Color(0xFF3CFFEF);   // Electric blue – secondary
const kPink   = Color(0xFFFF2D6B);   // Hot pink – danger
const kAmber  = Color(0xFFFF9F2E);   // Amber – protein / warnings
const kPurple = Color(0xFF8B5CF6);   // Purple – fasting
const kBlue   = Color(0xFF3B82F6);   // Blue – carbs

// Semantic colours
const kProtein = Color(0xFFFF9F2E);
const kCarbs   = Color(0xFF3B82F6);
const kFat     = Color(0xFF8B5CF6);
const kSugar   = Color(0xFFFF2D6B);

// Text
const kTextPrimary   = Color(0xFFFFFFFF);
const kTextSecondary = Color(0xFF8888AA);
const kTextMuted     = Color(0xFF444455);

// ============================================================
// GLASS CARD
// ============================================================
class GlassCard extends StatelessWidget {
  final Widget child;
  final double? height;
  final double? width;
  final EdgeInsets padding;
  final Color glowColor;
  final double radius;
  final Color? borderColor;
  final Gradient? gradient;

  const GlassCard({
    super.key,
    required this.child,
    this.height,
    this.width,
    this.padding = const EdgeInsets.all(20),
    this.glowColor = const Color(0x22CDFF3C),
    this.radius = 24,
    this.borderColor,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: kSurface,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? kBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(color: glowColor, blurRadius: 48, spreadRadius: -8),
        ],
      ),
      child: child,
    );
  }
}

// Legacy alias — keeps old code compiling
typedef BentoCard = GlassCard;

// ============================================================
// PULSE BUTTON (animated press)
// ============================================================
class PulseButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color color;
  final Color textColor;
  final double height;
  final Widget? icon;

  const PulseButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.color = kNeon,
    this.textColor = kBg,
    this.height = 56,
    this.icon,
  });

  @override
  State<PulseButton> createState() => _PulseButtonState();
}

class _PulseButtonState extends State<PulseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _onTapDown(_) => _ctrl.forward();
  void _onTapUp(_) { _ctrl.reverse(); widget.onPressed?.call(); }
  void _onTapCancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isLoading ? null : _onTapDown,
      onTapUp: widget.isLoading ? null : _onTapUp,
      onTapCancel: widget.isLoading ? null : _onTapCancel,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: Container(
          width: double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.isLoading ? widget.color.withValues(alpha: 0.5) : widget.color,
            borderRadius: BorderRadius.circular(100),
            boxShadow: widget.isLoading
                ? []
                : [BoxShadow(color: widget.color.withValues(alpha: 0.35), blurRadius: 24, spreadRadius: 0, offset: const Offset(0, 4))],
          ),
          child: Center(
            child: widget.isLoading
                ? CupertinoActivityIndicator(color: widget.textColor)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[widget.icon!, const SizedBox(width: 8)],
                      Text(
                        widget.text.toUpperCase(),
                        style: TextStyle(
                          color: widget.textColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// Legacy alias
class NeonButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
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
    return PulseButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      color: color,
    );
  }
}

// ============================================================
// ANIMATED ACTIVITY RINGS
// ============================================================
class ActivityRing extends StatefulWidget {
  final double size;
  final double movePercent;
  final double exercisePercent;
  final double standPercent;
  final bool animate;

  const ActivityRing({
    super.key,
    required this.size,
    required this.movePercent,
    required this.exercisePercent,
    required this.standPercent,
    this.animate = true,
  });

  @override
  State<ActivityRing> createState() => _ActivityRingState();
}

class _ActivityRingState extends State<ActivityRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    if (widget.animate) _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _RingPainter(
            movePercent: (widget.movePercent * _anim.value).clamp(0, 1),
            exercisePercent: (widget.exercisePercent * _anim.value).clamp(0, 1),
            standPercent: (widget.standPercent * _anim.value).clamp(0, 1),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double movePercent;
  final double exercisePercent;
  final double standPercent;

  _RingPainter({
    required this.movePercent,
    required this.exercisePercent,
    required this.standPercent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 13.0;
    const gap = 4.0;
    final cx = size.width / 2;
    final cy = size.height / 2;

    _ring(canvas, cx, cy, cx - stroke / 2, kPink, movePercent, stroke);
    _ring(canvas, cx, cy, cx - stroke - gap - stroke / 2, kNeon, exercisePercent, stroke);
    _ring(canvas, cx, cy, cx - stroke * 2 - gap * 2 - stroke / 2, kTeal, standPercent, stroke);
  }

  void _ring(Canvas c, double cx, double cy, double r, Color col, double pct, double sw) {
    // Track
    c.drawCircle(
      Offset(cx, cy), r,
      Paint()..color = col.withValues(alpha: 0.18)..style = PaintingStyle.stroke..strokeWidth = sw,
    );
    if (pct <= 0) return;
    // Arc
    c.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -math.pi / 2,
      2 * math.pi * pct,
      false,
      Paint()
        ..color = col
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.movePercent != movePercent ||
      old.exercisePercent != exercisePercent ||
      old.standPercent != standPercent;
}

// ============================================================
// CALORIE DONUT RING  (big hero)
// ============================================================
class CalorieDonut extends StatefulWidget {
  final int consumed;
  final int goal;
  final int? burnt;
  final int? resting;
  final double size;

  const CalorieDonut({
    super.key,
    required this.consumed,
    required this.goal,
    this.burnt,
    this.resting,
    this.size = 200,
  });

  @override
  State<CalorieDonut> createState() => _CalorieDonutState();
}

class _CalorieDonutState extends State<CalorieDonut>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final burnt = widget.burnt ?? 0;
    final resting = widget.resting ?? 0;
    final totalBurnt = burnt + resting;
    
    final effective = widget.consumed - totalBurnt;
    final consumedPct = (widget.consumed / (widget.goal == 0 ? 1 : widget.goal)).clamp(0.0, 1.2);
    final totalBurntPct = (totalBurnt / (widget.goal == 0 ? 1 : widget.goal)).clamp(0.0, 1.2);
    final restingShare = totalBurnt == 0 ? 0.0 : (resting / totalBurnt).clamp(0.0, 1.0);
    
    final isOver = effective > widget.goal;
    final isDeficit = effective < 0;
    final color = isOver ? kPink : (isDeficit ? kNeon : kNeon);
    final remaining = widget.goal - effective;

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _DonutPainter(
            consumedPct: (consumedPct * _anim.value).clamp(0.0, 1.2),
            totalBurntPct: (totalBurntPct * _anim.value).clamp(0.0, 1.2),
            restingShare: restingShare,
            color: color,
          ),
          child: Center(
            child: SizedBox(
              width: widget.size * 0.65,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                Text(
                  '${effective.round()}',
                  style: TextStyle(
                    color: color,
                    fontSize: widget.size * 0.18,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: -2,
                  ),
                ),
                Text(
                  'kcal',
                  style: TextStyle(
                    color: kTextSecondary,
                    fontSize: widget.size * 0.08,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double consumedPct;
  final double totalBurntPct;
  final double restingShare;
  final Color color;
  _DonutPainter({
    required this.consumedPct, 
    required this.totalBurntPct,
    required this.restingShare,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const swOuter = 14.0;
    const swInner = 12.0;
    const gap = 4.0;

    final cx = size.width / 2, cy = size.height / 2;
    
    // Outer Ring (Consumed)
    final rOuter = cx - swOuter / 2 - 4;
    // Inner Ring (Burnt: Active + Resting)
    final rInner = rOuter - swOuter / 2 - gap - swInner / 2;

    // Background rings
    canvas.drawCircle(Offset(cx, cy), rOuter, Paint()..color = kBorder2..style = PaintingStyle.stroke..strokeWidth = swOuter);
    canvas.drawCircle(Offset(cx, cy), rInner, Paint()..color = kBorder2.withValues(alpha: 0.4)..style = PaintingStyle.stroke..strokeWidth = swInner);

    // Inner Ring: Burnt Calories (Active + Resting, split by color)
    if (totalBurntPct > 0) {
      final totalSweep = 2 * math.pi * totalBurntPct.clamp(0.0, 1.0);
      final restingSweep = totalSweep * restingShare.clamp(0.0, 1.0);
      final activeSweep = totalSweep - restingSweep;

      if (restingSweep > 0) {
        final pResting = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = swInner
          ..strokeCap = StrokeCap.round
          ..color = kTeal;

        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: rInner),
          -math.pi / 2,
          restingSweep,
          false,
          pResting,
        );
      }

      if (activeSweep > 0) {
        final pActive = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = swInner
          ..strokeCap = StrokeCap.round
          ..color = kAmber;

        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: rInner),
          -math.pi / 2 + restingSweep,
          activeSweep,
          false,
          pActive,
        );
      }
    }

    // Outer Ring: Consumed Calories (Dynamic Color - green or pink)
    if (consumedPct > 0) {
      final pConsumed = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = swOuter
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: [color, color.withValues(alpha: 0.7)],
          startAngle: -math.pi / 2,
          endAngle: 2 * math.pi * consumedPct - math.pi / 2,
          tileMode: TileMode.clamp,
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: rOuter));

      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: rOuter),
        -math.pi / 2,
        2 * math.pi * consumedPct.clamp(0.0, 1.0),
        false,
        pConsumed,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => 
      old.consumedPct != consumedPct || 
      old.totalBurntPct != totalBurntPct || 
      old.restingShare != restingShare ||
      old.color != color;
}

// ============================================================
// XP BAR (gamification)
// ============================================================
class XPBar extends StatelessWidget {
  final int xp;
  final int maxXp;
  final int level;

  const XPBar({super.key, required this.xp, required this.maxXp, required this.level});

  @override
  Widget build(BuildContext context) {
    final pct = (xp / maxXp).clamp(0.0, 1.0);
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [kNeon, kTeal]),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text('$level', style: const TextStyle(color: kBg, fontSize: 14, fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('LEVEL $level', style: const TextStyle(color: kNeon, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                Text('$xp / $maxXp XP', style: const TextStyle(color: kTextMuted, fontSize: 10, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  height: 6,
                  decoration: const BoxDecoration(color: kBorder2),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: pct,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [kNeon, kTeal]),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// STAT TILE
// ============================================================
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: onTap != null ? color.withValues(alpha: 0.3) : kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
              if (onTap != null) Icon(CupertinoIcons.chevron_right, color: color.withValues(alpha: 0.5), size: 10),
            ]),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: const TextStyle(color: kTextPrimary, fontSize: 22, fontWeight: FontWeight.w900)),
            ),
            Text(unit, style: const TextStyle(color: kTextMuted, fontSize: 9), overflow: TextOverflow.ellipsis, maxLines: 1),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Container(
                height: 4,
                decoration: const BoxDecoration(color: kBorder2),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: fillFraction.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.6)]),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SECTION HEADER
// ============================================================
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onAction;

  const SectionHeader({super.key, required this.title, this.subtitle, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: kTextPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
          if (subtitle != null)
            GestureDetector(
              onTap: onAction,
              child: Text(subtitle!, style: const TextStyle(color: kTeal, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// STREAK BADGE
// ============================================================
class StreakBadge extends StatelessWidget {
  final int streak;

  const StreakBadge({super.key, required this.streak});

  @override
  Widget build(BuildContext context) {
    final isActive = streak > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: isActive
            ? const LinearGradient(colors: [Color(0xFFFF6B00), Color(0xFFFF2D6B)])
            : null,
        color: isActive ? null : kSurface2,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: isActive ? Colors.transparent : kBorder),
        boxShadow: isActive
            ? [const BoxShadow(color: Color(0x44FF6B00), blurRadius: 16, spreadRadius: 0)]
            : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            '$streak day${streak == 1 ? '' : 's'}',
            style: TextStyle(
              color: isActive ? CupertinoColors.white : kTextMuted,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MILESTONE BADGE
// ============================================================
class MilestoneBadge extends StatelessWidget {
  final String title;
  final String emoji;
  final bool earned;

  const MilestoneBadge({super.key, required this.title, this.emoji = '⭐', this.earned = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: earned ? kSurface2 : kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: earned ? kNeon.withValues(alpha: 0.6) : kBorder,
          width: earned ? 1.5 : 1,
        ),
        boxShadow: earned
            ? [BoxShadow(color: kNeon.withValues(alpha: 0.15), blurRadius: 16)]
            : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            emoji,
            style: TextStyle(fontSize: 28, color: earned ? null : const Color(0x44FFFFFF)),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: earned ? kTextPrimary : kTextMuted,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HEALTH METRIC CARD  (sleep, HR, SpO2, etc.)
// ============================================================
class HealthMetricCard extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const HealthMetricCard({
    super.key,
    required this.emoji,
    required this.label,
    required this.value,
    required this.unit,
    this.color = kTeal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 8),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900, height: 1),
            ),
          ),
          Text(unit, style: const TextStyle(color: kTextMuted, fontSize: 9, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: kTextSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
