// lib/chat/chat_config.dart

import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';

class ChatConfig {
  final String initialAiMessage;
  final String systemPrompt;
  final String openAiKey;
  final String aiName;
  final String userName;
  final String modelName;
  final DefaultChatTheme chatTheme;
  final int maxTokens;
  final double temperature;
  final bool automaticallyReplyLastMessageFromHistory;
  final List<OpenAIToolModel> tools;
  const ChatConfig({
    required this.initialAiMessage,
    required this.systemPrompt,
    required this.openAiKey,
    this.modelName = "gpt-4o-mini",
    this.maxTokens = 4096,
    this.temperature = 0.2,
    this.automaticallyReplyLastMessageFromHistory = false,
    this.tools = const [],
    this.chatTheme = const DefaultChatTheme(
      backgroundColor: Colors.white,
      primaryColor: Colors.blue,
      secondaryColor:
      Color(0xFFEEEEEE), // Using direct color instead of Colors.grey[200]
      userAvatarNameColors: [Colors.blue],
      inputBackgroundColor: Colors.white,
      inputTextColor: Colors.black87,
      inputTextStyle: TextStyle(
        color: Colors.black87,
        fontSize: 16,
      ),
      sentMessageBodyTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 16,
      ),
      receivedMessageBodyTextStyle: TextStyle(
        color: Colors.black87,
        fontSize: 16,
      ),
      inputBorderRadius: BorderRadius.all(Radius.circular(20)),
    ),
    this.aiName = 'AI Assistant',
    this.userName = 'User',
  });
}
