import 'package:flutter/material.dart';
import '../models/adherence_event.dart';

/// Widget that displays a sync status badge for medication reminders
/// Shows a colored indicator (🟢, 🟡, 🔴) based on sync status
class ReminderSyncBadge extends StatelessWidget {
  final SyncStatus syncStatus;
  final bool showLabel;
  final double size;

  const ReminderSyncBadge({
    super.key,
    required this.syncStatus,
    this.showLabel = false,
    this.size = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Choose color based on sync status
    final color = switch (syncStatus) {
      SyncStatus.synced => Colors.green,
      SyncStatus.pending => Colors.orange,
      SyncStatus.failed => Colors.red,
    };
    
    // Choose icon based on sync status
    final icon = switch (syncStatus) {
      SyncStatus.synced => Icons.cloud_done,
      SyncStatus.pending => Icons.cloud_upload,
      SyncStatus.failed => Icons.cloud_off,
    };

    if (showLabel) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: size,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            syncStatus.displayName,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontSize: size * 0.75,
            ),
          ),
        ],
      );
    }

    return Tooltip(
      message: syncStatus.displayName,
      child: Icon(
        icon,
        size: size,
        color: color,
      ),
    );
  }
}

/// Compact sync badge that shows just the emoji indicator
class CompactSyncBadge extends StatelessWidget {
  final SyncStatus syncStatus;

  const CompactSyncBadge({
    super.key,
    required this.syncStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: syncStatus.displayName,
      child: Text(
        syncStatus.emoji,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}
