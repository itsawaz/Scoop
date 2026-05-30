import 'package:flutter/cupertino.dart';
import '../services/api_service.dart';
import '../widgets.dart';

/// Widget that displays current API usage status
/// Shows remaining requests and provides visual feedback on capacity
class ApiUsageIndicator extends StatefulWidget {
  final bool compact;
  
  const ApiUsageIndicator({super.key, this.compact = false});

  @override
  State<ApiUsageIndicator> createState() => _ApiUsageIndicatorState();
}

class _ApiUsageIndicatorState extends State<ApiUsageIndicator> {
  String _statusMessage = 'Loading...';
  int _remaining = 0;
  int _totalLimit = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final apiService = ApiService();
      final stats = await apiService.getUsageStats();
      final message = await apiService.getStatusMessage();
      
      if (mounted) {
        setState(() {
          _statusMessage = message;
          _remaining = stats['remaining'] ?? 0;
          _totalLimit = stats['totalLimit'] ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error loading API status';
          _isLoading = false;
        });
      }
    }
  }

  Color _getStatusColor() {
    if (_totalLimit == 0) return CupertinoColors.systemGrey;
    
    final percentRemaining = (_remaining / _totalLimit) * 100;
    
    if (percentRemaining > 50) return kTeal;
    if (percentRemaining > 20) return kAmber;
    return kPink;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CupertinoActivityIndicator(),
      );
    }

    if (widget.compact) {
      return _buildCompactView();
    }

    return _buildFullView();
  }

  Widget _buildCompactView() {
    final color = _getStatusColor();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.bolt_fill, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            '$_remaining left',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullView() {
    final color = _getStatusColor();
    final percentRemaining = _totalLimit > 0 ? (_remaining / _totalLimit) : 0.0;
    
    return BentoCard(
      glowColor: color.withOpacity(0.2),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.bolt_fill, color: color, size: 20),
              const SizedBox(width: 8),
              const Text(
                'AI USAGE TODAY',
                style: TextStyle(
                  color: CupertinoColors.systemGrey,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Progress bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFF222222),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentRemaining.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Status text
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$_remaining / $_totalLimit',
                style: const TextStyle(
                  color: CupertinoColors.systemGrey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          // Tip for adding more keys
          if (_remaining < _totalLimit * 0.2) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kAmber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kAmber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(CupertinoIcons.lightbulb, color: kAmber, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Add more API keys in Profile to increase your daily limit',
                      style: TextStyle(
                        color: kAmber,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact badge version for navigation bars
class ApiUsageBadge extends StatelessWidget {
  const ApiUsageBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const ApiUsageIndicator(compact: true);
  }
}
