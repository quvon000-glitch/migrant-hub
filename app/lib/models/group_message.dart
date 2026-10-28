import '../core/supa.dart';

enum SendState { sending, sent, failed }

class GroupMessage {
  final int id; // negative while the message is only on this phone
  final String clientId;
  final String city;
  final String userId;
  final String kind; // text | image | video | voice
  final String body;
  final String? mediaPath;
  final String? thumbPath;
  final int? durationSec;
  final int? width;
  final int? height;
  final bool mediaExpired;
  final int? replyToId;
  final DateTime? pinnedAt;
  final DateTime? hiddenAt;
  final int reportCount;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final DateTime createdAt;
  // local only
  final SendState state;
  final String? localFile;
  final String? error;

  const GroupMessage({
    required this.id, required this.clientId, required this.city, required this.userId, required this.kind, required this.body,
    this.mediaPath, this.thumbPath, this.durationSec, this.width, this.height, this.mediaExpired = false, this.replyToId,
    this.pinnedAt, this.hiddenAt, this.reportCount = 0, this.editedAt, this.deletedAt, required this.createdAt,
    this.state = SendState.sent, this.localFile, this.error,
  });

  bool get isLocal => id < 0;
  bool get pinned => pinnedAt != null;
  bool get hidden => hiddenAt != null;
  bool get edited => editedAt != null;
  bool get deleted => deletedAt != null;
  bool get isMedia => kind == 'image' || kind == 'video';
  String? get mediaUrl => mediaPath == null || mediaExpired ? null : publicUrl('chat-media', mediaPath!);
  String? get thumbUrl => thumbPath == null || mediaExpired ? null : publicUrl('chat-media', thumbPath!);

  String get preview {
    if (deleted) return 'O‘chirilgan xabar';
    if (body.trim().isNotEmpty) return body.trim().length > 90 ? '${body.trim().substring(0, 90)}…' : body.trim();
    switch (kind) {
      case 'image':
        return '📷 Rasm';
      case 'video':
        return '🎬 Video';
      case 'voice':
        return '🎤 Ovozli xabar';
    }
    return '';
  }

  factory GroupMessage.fromJson(Map<String, dynamic> j) => GroupMessage(
        id: (j['id'] as num).toInt(),
        clientId: j['client_id'] as String? ?? 'srv-${j['id']}',
        city: j['city'] as String,
        userId: j['user_id'] as String,
        kind: j['kind'] as String? ?? 'text',
        body: j['body'] as String? ?? '',
        mediaPath: j['media_path'] as String?,
        thumbPath: j['thumb_path'] as String?,
        durationSec: (j['duration_sec'] as num?)?.toInt(),
        width: (j['width'] as num?)?.toInt(),
        height: (j['height'] as num?)?.toInt(),
        mediaExpired: j['media_expired'] as bool? ?? false,
        replyToId: (j['reply_to_id'] as num?)?.toInt(),
        pinnedAt: _dt(j['pinned_at']),
        hiddenAt: _dt(j['hidden_at']),
        reportCount: (j['report_count'] as num?)?.toInt() ?? 0,
        editedAt: _dt(j['edited_at']),
        deletedAt: _dt(j['deleted_at']),
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'client_id': clientId, 'city': city, 'user_id': userId, 'kind': kind, 'body': body, 'media_path': mediaPath,
        'thumb_path': thumbPath, 'duration_sec': durationSec, 'width': width, 'height': height, 'media_expired': mediaExpired,
        'reply_to_id': replyToId, 'pinned_at': pinnedAt?.toIso8601String(), 'hidden_at': hiddenAt?.toIso8601String(),
        'report_count': reportCount, 'edited_at': editedAt?.toIso8601String(), 'deleted_at': deletedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  GroupMessage copyWith({SendState? state, String? error, String? body, DateTime? editedAt}) => GroupMessage(
        id: id, clientId: clientId, city: city, userId: userId, kind: kind, body: body ?? this.body, mediaPath: mediaPath,
        thumbPath: thumbPath, durationSec: durationSec, width: width, height: height, mediaExpired: mediaExpired,
        replyToId: replyToId, pinnedAt: pinnedAt, hiddenAt: hiddenAt, reportCount: reportCount, editedAt: editedAt ?? this.editedAt,
        deletedAt: deletedAt, createdAt: createdAt, state: state ?? this.state, localFile: localFile, error: error,
      );
}

DateTime? _dt(dynamic v) => v == null ? null : DateTime.parse(v as String);
