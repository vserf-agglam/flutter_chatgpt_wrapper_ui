// chat_message.dart

import 'message_status.dart';

class ChatMessage {
  final String content;
  final bool isUserMessage;
  final DateTime timestamp;
  final LocalMessageStatus status;
  final String? imageUrl;
  final Map<String, dynamic>? metadata;

  const ChatMessage({
    required this.content,
    required this.isUserMessage,
    required this.timestamp,
    this.status = LocalMessageStatus.sending,
    this.imageUrl,
    this.metadata,
  });

  ChatMessage copyWith({
    String? content,
    bool? isUserMessage,
    DateTime? timestamp,
    LocalMessageStatus? status,
    String? imageUrl,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      content: content ?? this.content,
      isUserMessage: isUserMessage ?? this.isUserMessage,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      imageUrl: imageUrl ?? this.imageUrl,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'isUserMessage': isUserMessage,
      'timestamp': timestamp.toIso8601String(),
      'status': status.toString(),
      'imageUrl': imageUrl,
      'metadata': metadata,
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
      imageUrl: json['imageUrl'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
