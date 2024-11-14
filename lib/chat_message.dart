import 'message_status.dart';

class ChatMessage {
  final String content;
  final bool isUserMessage;
  final DateTime timestamp;
  final LocalMessageStatus status;
  final Map<String, dynamic>? metadata;
  final List<Attachment>? attachments;

  const ChatMessage({
    required this.content,
    required this.isUserMessage,
    required this.timestamp,
    this.status = LocalMessageStatus.sending,
    this.metadata,
    this.attachments,
  });

  ChatMessage copyWith({
    String? content,
    bool? isUserMessage,
    DateTime? timestamp,
    LocalMessageStatus? status,
    String? imageUrl,
    Map<String, dynamic>? metadata,
    List<Attachment>? attachments,
  }) {
    return ChatMessage(
      content: content ?? this.content,
      isUserMessage: isUserMessage ?? this.isUserMessage,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
      attachments: attachments ?? this.attachments,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'isUserMessage': isUserMessage,
      'timestamp': timestamp.toIso8601String(),
      'status': status.toString(),
      'metadata': metadata,
      'attachments': attachments?.map((a) => a.toJson()).toList(),
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      content: json['content'] as String,
      isUserMessage: json['isUserMessage'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: LocalMessageStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => LocalMessageStatus.sent,
      ),
      metadata: json['metadata'] as Map<String, dynamic>?,
      attachments: (json['attachments'] as List<dynamic>?)
          ?.map((a) => Attachment.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Attachment {
  final AttachmentType type;
  final String url;
  final String? name;
  final int? duration;
  final int size;
  final String content;

  const Attachment({
    required this.type,
    required this.url,
    required this.size,
    required this.content,
    this.name,
    this.duration,
  });

  Map<String, dynamic> toJson() => {
        'type': type.toString(),
        'path': url,
        'name': name,
        'duration': duration,
      };

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      type: AttachmentType.values.firstWhere(
        (e) => e.toString() == json['type'],
      ),
      url: json['path'] as String,
      name: json['name'] as String?,
      duration: json['duration'] as int?,
      size: json['size'] as int,
      content: json['content'] as String,
    );
  }
}

enum AttachmentType { image, audio, file }
