import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Dialog for prompting user to enable Data Saver Mode on mobile data
class MobileDataPromptDialog extends StatefulWidget {
  final VoidCallback onEnableDataSaver;
  final VoidCallback onDecline;
  final VoidCallback? onDontAskAgain;

  const MobileDataPromptDialog({
    super.key,
    required this.onEnableDataSaver,
    required this.onDecline,
    this.onDontAskAgain,
  });

  @override
  State<MobileDataPromptDialog> createState() => _MobileDataPromptDialogState();
}

class _MobileDataPromptDialogState extends State<MobileDataPromptDialog> {
  bool _dontAskAgain = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.signal_cellular_alt_rounded,
                color: AppTheme.primaryColor,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Mobile Data Detected',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              'You are currently using mobile data. Would you like to enable Data Saver Mode to reduce network usage and save your data plan?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Benefits section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data Saver Mode will:',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                  ),
                  const SizedBox(height: 8),
                  _buildBenefitItem('📦 Cache data to avoid repeated downloads'),
                  _buildBenefitItem('⏱️ Queue sync operations for Wi-Fi'),
                  _buildBenefitItem('📊 Show real-time savings'),
                  _buildBenefitItem('🔄 Prioritize cached content'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Don't ask again checkbox
            Row(
              children: [
                Checkbox(
                  value: _dontAskAgain,
                  onChanged: (value) {
                    setState(() => _dontAskAgain = value ?? false);
                  },
                  activeColor: AppTheme.primaryColor,
                  side: BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
                Expanded(
                  child: Text(
                    "Don't ask again for 24 hours",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[700],
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                // Decline button
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      if (_dontAskAgain) {
                        widget.onDontAskAgain?.call();
                      }
                      widget.onDecline.call();
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(
                        color: Colors.grey[400]!,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Not Now',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Enable button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onEnableDataSaver.call();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Enable Data Saver',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build a benefit list item
  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '✓',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Alternative: Simpler SnackBar-based notification
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
    showMobileDataSnackBar(
  BuildContext context, {
  required VoidCallback onEnableDataSaver,
  required VoidCallback onDecline,
}) {
  return ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(
            Icons.signal_cellular_alt_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mobile Data Detected',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enable Data Saver to reduce usage?',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: Colors.orange[700],
      duration: const Duration(seconds: 8),
      action: SnackBarAction(
        label: 'Enable',
        textColor: Colors.white,
        onPressed: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          onEnableDataSaver.call();
        },
      ),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );
}
