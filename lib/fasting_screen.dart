import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'widgets.dart';
import 'models.dart';
import 'services/fasting_service.dart';

class FastingScreen extends StatefulWidget {
  const FastingScreen({super.key});

  @override
  State<FastingScreen> createState() => _FastingScreenState();
}

class _FastingScreenState extends State<FastingScreen> {
  final FastingService _fasting = FastingService();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _loadState());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _loadState() {
    if (mounted) setState(() {});
  }

  void _startFast() async {
    // Show picker for target hours
    int selected = 16;
    await showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 300,
        color: kBg,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(padding: EdgeInsets.zero, child: const Text('Cancel', style: TextStyle(color: kTextMuted)), onPressed: () => Navigator.pop(context)),
                  const Text('Fasting Goal', style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.bold)),
                  CupertinoButton(padding: EdgeInsets.zero, child: const Text('Start', style: TextStyle(color: kNeon, fontWeight: FontWeight.bold)), onPressed: () {
                    Navigator.pop(context);
                    _fasting.startFast(selected);
                    _loadState();
                  }),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                backgroundColor: kBg,
                itemExtent: 40,
                scrollController: FixedExtentScrollController(initialItem: selected - 12),
                onSelectedItemChanged: (idx) => selected = idx + 12,
                children: List.generate(24, (i) => Center(child: Text('${i + 12} hours', style: const TextStyle(color: kTextPrimary)))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _stopFast() async {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('End Fast?'),
        content: const Text('Are you sure you want to end your fast now?'),
        actions: [
          CupertinoDialogAction(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('End Fast'),
            onPressed: () async {
              Navigator.pop(context);
              await _fasting.stopFast();
              _loadState();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = _fasting.currentSession;
    final isActive = current != null && current.endTime == null;

    return CupertinoPageScaffold(
      backgroundColor: kBg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: kBg.withValues(alpha: 0.8),
        border: null,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(CupertinoIcons.chevron_back, color: kTextPrimary),
        ),
        middle: const Text('FASTING', style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w900, letterSpacing: 1)),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 140),
          children: [
            if (isActive) ...[
              const Text('CURRENT FAST', style: TextStyle(color: kTextMuted, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5), textAlign: TextAlign.center),
              const SizedBox(height: 40),
              
              // Animated Timer Ring
              Center(
                child: SizedBox(
                  width: 280, height: 280,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // BG Ring
                      ActivityRing(size: 280, movePercent: 1.0, exercisePercent: 0, standPercent: 0, animate: false),
                      
                      // Values
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _getTimeElapsed(current),
                            style: const TextStyle(color: kPurple, fontSize: 56, fontWeight: FontWeight.w900, letterSpacing: -2, height: 1),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Elapsed • Goal: ${current.targetHours.round()}h',
                            style: const TextStyle(color: kTextSecondary, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: kPurple.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: kPurple.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              _getPhaseName(current),
                              style: const TextStyle(color: kPurple, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 60),
              
              PulseButton(
                text: 'END FAST',
                color: kPink,
                textColor: kTextPrimary,
                onPressed: _stopFast,
              ),
            ] else ...[
              const Text('READY TO FAST?', style: TextStyle(color: kTextPrimary, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              const Text('Pick a protocol and start burning fat.', style: TextStyle(color: kTextSecondary, fontSize: 16), textAlign: TextAlign.center),
              const SizedBox(height: 60),
              
              PulseButton(
                text: 'START NEW FAST',
                color: kPurple,
                onPressed: _startFast,
                icon: const Icon(CupertinoIcons.flame_fill, color: kBg),
              ),
            ],

            const SizedBox(height: 40),
            const SectionHeader(title: 'Fasting Stages'),
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: const [
                  _StageRow(hours: '0-4h', title: 'Blood Sugar Rises', color: kTextMuted),
                  _StageRow(hours: '4-8h', title: 'Blood Sugar Drops', color: kTextMuted),
                  _StageRow(hours: '8-12h', title: 'Digestion Ends', color: kAmber),
                  _StageRow(hours: '12-14h', title: 'Fat Burning Starts', color: kPurple),
                  _StageRow(hours: '14-16h', title: 'Ketosis Begins', color: kNeon, isLast: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeElapsed(FastingSession session) {
    final diff = DateTime.now().difference(session.startTime);
    final hours = diff.inHours.toString().padLeft(2, '0');
    final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String _getPhaseName(FastingSession session) {
    final hours = DateTime.now().difference(session.startTime).inMinutes / 60.0;
    if (hours < 4) return 'Blood Sugar Rises';
    if (hours < 8) return 'Blood Sugar Drops';
    if (hours < 12) return 'Digestion Ends';
    if (hours < 14) return 'Fat Burning Starts';
    return 'Ketosis Begins';
  }
}

class _StageRow extends StatelessWidget {
  final String hours;
  final String title;
  final Color color;
  final bool isLast;

  const _StageRow({required this.hours, required this.title, required this.color, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: kBorder))),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text(hours, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold))),
          Expanded(child: Text(title, style: const TextStyle(color: kTextPrimary, fontSize: 14, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
