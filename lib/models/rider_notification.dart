/// An in-app notification for the rider (A23), from GET /api/rider/notifications.
///
/// Logistics and admin create these when they assign a job, cancel one, or an
/// offer expires (`AssignmentUpdate` on the server).
class RiderNotification {
  final String id;

  /// The server's message for the rider, e.g. "New delivery offered to you."
  final String message;

  /// offered | cancelled | expired | … (empty for other notification types)
  final String kind;

  /// The job the notification is about, when there is one.
  final int? assignmentId;
  final DateTime? createdAt;
  final DateTime? readAt;

  const RiderNotification({
    required this.id,
    required this.message,
    this.kind = '',
    this.assignmentId,
    this.createdAt,
    this.readAt,
  });

  bool get isRead => readAt != null;
  bool get opensJob => assignmentId != null;

  RiderNotification markedRead() => RiderNotification(
        id: id,
        message: message,
        kind: kind,
        assignmentId: assignmentId,
        createdAt: createdAt,
        readAt: readAt ?? DateTime.now(),
      );

  factory RiderNotification.fromJson(Map<String, dynamic> j) {
    // The row has a `data` payload; that payload also has its own `data`-free fields.
    final payload = (j['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    final assignment = (payload['assignment_id'] as num?)?.toInt();
    return RiderNotification(
      id: j['id'].toString(),
      message: (payload['message'] as String?)?.trim() ?? '',
      kind: payload['kind'] as String? ?? '',
      assignmentId: assignment,
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? ''),
      readAt: DateTime.tryParse(j['read_at'] as String? ?? ''),
    );
  }
}
