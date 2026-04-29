enum MessageStatus { sending, sent, delivered, failed }

class Message {
  final String id;
  final String chatId; // peer id of the other party
  final String senderId; // 'me' or peer id
  final String text;
  final DateTime timestamp;
  MessageStatus status;
  final bool isGhost;
  bool isDeleted;

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.status = MessageStatus.sending,
    this.isGhost = false,
    this.isDeleted = false,
  });

  static const String myIdMarker = 'me';

  bool get isMine => senderId == myIdMarker;

  Map<String, dynamic> toMap() => {
        'id': id,
        'chat_id': chatId,
        'sender_id': senderId,
        'text': text,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'status': status.index,
        'is_ghost': isGhost ? 1 : 0,
        'is_deleted': isDeleted ? 1 : 0,
      };

  factory Message.fromMap(Map<String, dynamic> map) => Message(
        id: map['id'] as String,
        chatId: map['chat_id'] as String,
        senderId: map['sender_id'] as String,
        text: map['text'] as String,
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        status: MessageStatus.values[map['status'] as int],
        isGhost: (map['is_ghost'] as int) == 1,
        isDeleted: (map['is_deleted'] as int) == 1,
      );

  /// Wire format sent over the Nearby Connections payload.
  Map<String, dynamic> toWire() => {
        'type': 'message',
        'id': id,
        'text': text,
        'ts': timestamp.millisecondsSinceEpoch,
        'ghost': isGhost,
      };

  Message copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? text,
    DateTime? timestamp,
    MessageStatus? status,
    bool? isGhost,
    bool? isDeleted,
  }) =>
      Message(
        id: id ?? this.id,
        chatId: chatId ?? this.chatId,
        senderId: senderId ?? this.senderId,
        text: text ?? this.text,
        timestamp: timestamp ?? this.timestamp,
        status: status ?? this.status,
        isGhost: isGhost ?? this.isGhost,
        isDeleted: isDeleted ?? this.isDeleted,
      );
}
