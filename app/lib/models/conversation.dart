import '../models/group_message.dart' show SendState;

class Conversation {
  final int id;
  final int? adId;
  final String adTitle;
  final String? adPhoto;
  final String adPriceText;
  final bool adActive;
  final String otherUserId;
  final String otherName;
  final String? otherAvatar;
  final bool iAmSeller;
  final String? lastMessage;
  final DateTime lastMessageAt;
  final bool lastFromMe;
  final int unread;
  final DateTime otherReadAt;
  final bool blockedByMe;

  const Conversation({
    required this.id, this.adId, required this.adTitle, this.adPhoto, required this.adPriceText, required this.adActive,
    required this.otherUserId, required this.otherName, this.otherAvatar, required this.iAmSeller, this.lastMessage,
    required this.lastMessageAt, required this.lastFromMe, required this.unread, required this.otherReadAt, required this.blockedByMe,
  });

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        id: (j['id'] as num).toInt(),
        adId: (j['ad_id'] as num?)?.toInt(),
        adTitle: j['ad_title'] as String? ?? '',
        adPhoto: j['ad_photo'] as String?,
        adPriceText: j['ad_price_text'] as String? ?? '',
        adActive: j['ad_active'] as bool? ?? false,
        otherUserId: j['other_user_id'] as String,
        otherName: j['other_name'] as String? ?? 'Foydalanuvchi',
        otherAvatar: j['other_avatar'] as String?,
        iAmSeller: j['i_am_seller'] as bool? ?? false,
        lastMessage: j['last_message'] as String?,
        lastMessageAt: DateTime.parse(j['last_message_at'] as String),
        lastFromMe: j['last_from_me'] as bool? ?? false,
        unread: (j['unread'] as num?)?.toInt() ?? 0,
        otherReadAt: DateTime.parse(j['other_read_at'] as String),
        blockedByMe: j['blocked_by_me'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'ad_id': adId, 'ad_title': adTitle, 'ad_photo': adPhoto, 'ad_price_text': adPriceText, 'ad_active': adActive,
        'other_user_id': otherUserId, 'other_name': otherName, 'other_avatar': otherAvatar, 'i_am_seller': iAmSeller,
        'last_message': lastMessage, 'last_message_at': lastMessageAt.toIso8601String(), 'last_from_me': lastFromMe,
        'unread': unread, 'other_read_at': otherReadAt.toIso8601String(), 'blocked_by_me': blockedByMe,
      };
}

class DmMessage {
  final int id;
  final String clientId;
  final int conversationId;
  final String senderId;
  final String body;
  final int? replyToId;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final SendState state;

  const DmMessage({required this.id, required this.clientId, required this.conversationId, required this.senderId, required this.body, this.replyToId, this.editedAt, this.deletedAt, required this.createdAt, this.state = SendState.sent});

  bool get deleted => deletedAt != null;

  factory DmMessage.fromJson(Map<String, dynamic> j) => DmMessage(
        id: (j['id'] as num).toInt(),
        clientId: j['client_id'] as String? ?? 'srv-${j['id']}',
        conversationId: (j['conversation_id'] as num).toInt(),
        senderId: j['sender_id'] as String,
        body: j['body'] as String? ?? '',
        replyToId: (j['reply_to_id'] as num?)?.toInt(),
        editedAt: j['edited_at'] == null ? null : DateTime.parse(j['edited_at'] as String),
        deletedAt: j['deleted_at'] == null ? null : DateTime.parse(j['deleted_at'] as String),
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'client_id': clientId, 'conversation_id': conversationId, 'sender_id': senderId, 'body': body,
        'reply_to_id': replyToId, 'edited_at': editedAt?.toIso8601String(), 'deleted_at': deletedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  DmMessage copyWith({SendState? state}) => DmMessage(id: id, clientId: clientId, conversationId: conversationId, senderId: senderId, body: body, replyToId: replyToId, editedAt: editedAt, deletedAt: deletedAt, createdAt: createdAt, state: state ?? this.state);
}
