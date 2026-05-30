import 'package:flutter/cupertino.dart';
import 'dart:async';

/// Animated counter that smoothly increments calories in real-time
/// Updates every second to show gradual increase
class AnimatedCalorieCounter extends StatefulWidget {
  final double targetValue;
  final TextStyle? style;
  final String suffix;
  final double caloriesPerDay; // BMR for calculating per-second increment
  
  const AnimatedCalorieCounter({
    super.key,
    required this.targetValue,
    this.style,
    this.suffix = ' kcal',
    this.caloriesPerDay = 2400.0,
  });

  @override
  State<AnimatedCalorieCounter> createState() => _AnimatedCalorieCounterState();
}

class _AnimatedCalorieCounterState extends State<AnimatedCalorieCounter> {
  late double _displayValue;
  Timer? _incrementTimer;
  
  @override
  void initState() {
    super.initState();
    _displayValue = widget.targetValue;
    _startRealTimeIncrement();
  }

  @override
  void didUpdateWidget(AnimatedCalorieCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If target value changed significantly (e.g., new data from HealthKit),
    // smoothly animate to new value
    if ((widget.targetValue - oldWidget.targetValue).abs() > 10) {
      _animateToTarget();
    }
  }

  @override
  void dispose() {
    _incrementTimer?.cancel();
    super.dispose();
  }

  /// Start real-time increment based on BMR
  void _startRealTimeIncrement() {
    _incrementTimer?.cancel();
    
    // Calculate calories per second based on BMR
    final caloriesPerSecond = widget.caloriesPerDay / 86400.0; // 86400 seconds in a day
    
    // Update every second
    _incrementTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _displayValue += caloriesPerSecond;
          
          // Don't exceed target by too much (in case of clock drift)
          if (_displayValue > widget.targetValue + 10) {
            _displayValue = widget.targetValue;
          }
        });
      }
    });
  }

  /// Animate smoothly to new target value when data updates
  void _animateToTarget() {
    final difference = widget.targetValue - _displayValue;
    final steps = 30; // Animate over 30 frames
    final increment = difference / steps;
    
    int currentStep = 0;
    Timer.periodic(const Duration(milliseconds: 33), (timer) {
      if (currentStep >= steps || !mounted) {
        timer.cancel();
        if (mounted) {
          setState(() => _displayValue = widget.targetValue);
        }
        return;
      }
      
      setState(() {
        _displayValue += increment;
        currentStep++;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${_displayValue.round()}${widget.suffix}',
      style: widget.style,
    );
  }
}

/// Animated counter specifically for resting calories
/// Automatically calculates BMR-based increment
class AnimatedRestingCalories extends StatelessWidget {
  final double currentValue;
  final double bmr;
  final TextStyle? style;
  
  const AnimatedRestingCalories({
    super.key,
    required this.currentValue,
    required this.bmr,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedCalorieCounter(
      targetValue: currentValue,
      caloriesPerDay: bmr,
      style: style,
      suffix: ' kcal',
    );
  }
}
