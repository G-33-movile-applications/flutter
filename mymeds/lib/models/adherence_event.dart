/// Represents a user's adherence event for a medication reminder
/// Tracks when a user marks a reminder as taken or skipped
class AdherenceEvent {
  final String id;
  final String reminderId;
  final String userId;
  final DateTime timestamp;
  final AdherenceAction action;
  final SyncStatus syncStatus;
  final DateTime? lastSyncedAt;
  final int version;
  final String? notes;

  const AdherenceEvent({
    required this.id,
    required this.reminderId,
    required this.userId,
    required this.timestamp,
    required this.action,
    this.syncStatus = SyncStatus.pending,
    this.lastSyncedAt,
    this.version = 1,
    this.notes,
  });

  AdherenceEvent copyWith({
    String? id,
    String? reminderId,
    String? userId,
    DateTime? timestamp,
    AdherenceAction? action,
    SyncStatus? syncStatus,
    DateTime? lastSyncedAt,
    int? version,
    String? notes,
  }) {
    return AdherenceEvent(
      id: id ?? this.id,
      reminderId: reminderId ?? this.reminderId,
      userId: userId ?? this.userId,
      timestamp: timestamp ?? this.timestamp,
      action: action ?? this.action,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      version: version ?? this.version,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reminderId': reminderId,
      'userId': userId,
      'timestamp': timestamp.toIso8601String(),
      'action': action.name,
      'syncStatus': syncStatus.name,
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'version': version,
      'notes': notes,
    };
  }

  static AdherenceEvent fromJson(Map<String, dynamic> json) {
    return AdherenceEvent(
      id: json['id'] as String,
      reminderId: json['reminderId'] as String,
      userId: json['userId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      action: AdherenceAction.values.firstWhere(
        (e) => e.name == json['action'],
        orElse: () => AdherenceAction.taken,
      ),
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name == json['syncStatus'],
        orElse: () => SyncStatus.pending,
      ),
      lastSyncedAt: json['lastSyncedAt'] != null
          ? DateTime.parse(json['lastSyncedAt'] as String)
          : null,
      version: json['version'] as int? ?? 1,
      notes: json['notes'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdherenceEvent &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Action taken by user for a reminder
enum AdherenceAction {
  taken,
  skipped,
}

/// Sync status for offline-first operations
enum SyncStatus {
  synced,
  pending,
  failed,
}

extension SyncStatusExtension on SyncStatus {
  String get displayName {
    switch (this) {
      case SyncStatus.synced:
        return 'Sincronizado';
      case SyncStatus.pending:
        return 'Pendiente';
      case SyncStatus.failed:
        return 'Error';
    }
  }

  String get emoji {
    switch (this) {
      case SyncStatus.synced:
        return '🟢';
      case SyncStatus.pending:
        return '🟡';
      case SyncStatus.failed:
        return '🔴';
    }
  }
}
