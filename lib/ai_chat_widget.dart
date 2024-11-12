import 'dart:io';
import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chatgpt_wrapper_ui/tool_call_collector.dart';
import 'package:flutter_chatgpt_wrapper_ui/tool_handler_response.dart';

import 'chat_config.dart';
import 'chat_message.dart';
import 'image_handler.dart';
import 'message_status.dart';

class AIChatWidget extends StatefulWidget {
  final ChatConfig config;
  final List<ChatMessage> messageHistory;
  final Widget Function(types.CustomMessage, {required int messageWidth})?
      customMessageBuilder;
  final List<OpenAIToolModel>? tools;
  final Future<ToolHandlerResponse> Function(String, String)? onToolCall;
  final Function(ChatMessage)? onNewMessage;
  Map<String, Map<String, String>> _toolCallCollector = {};
  String _currentToolCallId = '';

   AIChatWidget({
    super.key,
    required this.config,
    required this.messageHistory,
    this.customMessageBuilder,
    this.tools,
    this.onToolCall,
    this.onNewMessage,
  });

  @override
  State<AIChatWidget> createState() => _AIChatWidgetState();
}

class _AIChatWidgetState extends State<AIChatWidget> {
  final List<types.Message> _messages = [];
  final List<OpenAIChatCompletionChoiceMessageModel> _aiMessages = [];

  late types.User _ai;
  late types.User _user;
    File? _pendingImage;
  String _streamText = '';
  String _chatResponseId = '';
  bool _isAiTyping = false;
  final ToolCallCollector _toolCallCollector = ToolCallCollector();

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _setupUsers();
    _loadMessageHistory();
    _automaticallyReplyIfNeeded();
  }

  void _initializeChat() {
    OpenAI.apiKey = widget.config.openAiKey;
    _addSystemPrompt();
  }

  void _addSystemPrompt() {
    _aiMessages.insert(
      0,
      OpenAIChatCompletionChoiceMessageModel(
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(
              widget.config.systemPrompt)
        ],
        role: OpenAIChatMessageRole.system,
      ),
    );
  }

  void _setupUsers() {
    _ai = types.User(
      id: 'ai',
      firstName: widget.config.aiName,
    );

    _user = types.User(
      id: 'user',
      firstName: widget.config.userName,
    );
  }

  void _loadMessageHistory() {
    for (var message in widget.messageHistory) {
      if (message.imageUrl != null) {
        final imageMessage = types.ImageMessage(
          author: message.isUserMessage ? _user : _ai,
          createdAt: message.timestamp.millisecondsSinceEpoch,
          id: message.timestamp.millisecondsSinceEpoch.toString(),
          name: 'Image',
          size: 0,
          uri: message.imageUrl!,
        );
        _messages.insert(0, imageMessage);
      }

      final textMessage = types.TextMessage(
        author: message.isUserMessage ? _user : _ai,
        createdAt: message.timestamp.millisecondsSinceEpoch,
        id: message.timestamp.millisecondsSinceEpoch.toString(),
        text: message.content,
        status: _convertMessageStatus(message.status),
      );

      _messages.insert(0, textMessage);

      _aiMessages.add(
        OpenAIChatCompletionChoiceMessageModel(
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(
                message.content)
          ],
          role: message.isUserMessage
              ? OpenAIChatMessageRole.user
              : OpenAIChatMessageRole.assistant,
        ),
      );
    }

    if (_messages.isEmpty) {
      final initialMessage = types.TextMessage(
        author: _ai,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: widget.config.initialAiMessage,
      );
      _messages.insert(0, initialMessage);
    }
  }

  types.Status _convertMessageStatus(LocalMessageStatus status) {
    switch (status) {
      case LocalMessageStatus.sending:
        return types.Status.sending;
      case LocalMessageStatus.sent:
        return types.Status.sent;
      case LocalMessageStatus.error:
        return types.Status.error;
      default:
        return types.Status.sending;
    }
  }

  Future<void> _handleImageSelection() async {
    final imageData = await ImageMessageHandler.pickImage();

    if (imageData != null) {
      setState(() {
        _pendingImage = kIsWeb ? null : imageData.file;
      });

      final imageMessage = types.ImageMessage(
        author: _user,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: imageData.name,
        size: imageData.bytes.length,
        uri: imageData.path,
      );

      setState(() {
        _messages.insert(0, imageMessage);
      });

      _handleImageMessage(imageData);
    }
  }

  void _handleImageMessage(ImageData imageData) async {
    try {
      final base64Image = ImageMessageHandler.getImageBase64(imageData);

      setState(() {
        _isAiTyping = true;
      });

      final base64Url = "data:image/jpeg;base64,$base64Image";

      final imageContent =
          OpenAIChatCompletionChoiceMessageContentItemModel.imageUrl(base64Url);

      _aiMessages.add(
        OpenAIChatCompletionChoiceMessageModel(
          content: [imageContent],
          role: OpenAIChatMessageRole.user,
        ),
      );

      final chatStream = OpenAI.instance.chat.createStream(
        model: widget.config.modelName,
        maxTokens: widget.config.maxTokens,
        messages: _aiMessages,
        tools: widget.tools,
        temperature: widget.config.temperature
      );

      chatStream.listen(
        (event) {
          _handleStreamResponse(event);
        },
        onError: (error) {
          print('Error in chat stream: $error');
          setState(() {
            _isAiTyping = false;
            _messages[0] = (_messages[0] as types.ImageMessage).copyWith(
              status: types.Status.error,
            );
          });
        },
        onDone: () {
          setState(() {
            _isAiTyping = false;
            _pendingImage = null;
          });
        },
      );
    } catch (e) {
      print('Error processing image: $e\nStacktrace: ${e.toString()}');
      setState(() {
        _isAiTyping = false;
        if (_messages.isNotEmpty) {
          _messages[0] = (_messages[0] as types.ImageMessage).copyWith(
            status: types.Status.error,
          );
        }
      });
    }
  }

  void _automaticallyReplyIfNeeded() {
    if (widget.config.automaticallyReplyLastMessageFromHistory &&
        widget.messageHistory.isNotEmpty) {
      final lastMessage = widget.messageHistory.last;
      if (lastMessage.isUserMessage) {
        // Delay the automatic reply slightly to allow the UI to update
        Future.delayed(Duration(milliseconds: 100), () {
          _completeChatStream(lastMessage.content);
        });
      }
    }
  }

  void _handleSendPressed(types.PartialText message) async {
    final textMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: message.text,
      status: types.Status.sent,
    );

    setState(() {
      _messages.insert(0, textMessage);
    });

    widget.onNewMessage?.call(
      ChatMessage(
        content: message.text,
        isUserMessage: true,
        timestamp: DateTime.now(),
        status: LocalMessageStatus.sent,
      ),
    );

    _completeChatStream(message.text);
  }

  void _completeChatStream(String prompt) async {
    _aiMessages.add(
      OpenAIChatCompletionChoiceMessageModel(
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt)
        ],
        role: OpenAIChatMessageRole.user,
      ),
    );

    final chatStream = OpenAI.instance.chat.createStream(
      model: widget.config.modelName,
      temperature: widget.config.temperature,
      maxTokens: widget.config.maxTokens,
      messages: _aiMessages,
      tools: widget.tools,
    );

    setState(() {
      _isAiTyping = true;
    });

    chatStream.listen(
      (event) {
        _handleStreamResponse(event);
      },
      onError: (error) {
        print('Error in chat stream: $error');
        setState(() {
          _isAiTyping = false;
          if (_messages.isNotEmpty) {
            _messages[0] = (_messages[0] as types.TextMessage).copyWith(
              status: types.Status.error,
            );
          }
        });
      },
      onDone: () {
        setState(() {
          _isAiTyping = false;
          var lastMessage = _messages.first;
          if (lastMessage is types.TextMessage) {
            lastMessage = lastMessage.copyWith(
              status: types.Status.sent,
            );
          }
        });
      },
    );
  }

  void _handleStreamResponse(OpenAIStreamChatCompletionModel event) {
    final chatResponseContent =
        event.choices.first.delta.content?.first?.text ?? '';

    if (event.choices.first.delta.toolCalls?.isNotEmpty ?? false) {
      final toolCall = event.choices.first.delta.toolCalls!.first;
      if (toolCall.function.name != null && widget.onToolCall != null) {
        _handleToolCall(toolCall);
      }
    }

    if (_chatResponseId == event.id) {
      _updateStreamMessage(chatResponseContent);

      if (event.choices.first.finishReason == "stop") {
        _handleStreamComplete(_streamText);
      } else if (event.choices.first.finishReason == "tool_calls") {
        _handleToolCallComplete();
      }
    } else {
      _startNewStreamMessage(event.id, chatResponseContent);
    }
  }

  void _mergeToolResponse(ToolHandlerResponse toolResponse) {
    if (toolResponse.messages.isNotEmpty) {
      _messages.removeAt(0); // Remove the first message before merging
      _messages.insertAll(0, toolResponse.messages);
    }

    _aiMessages.addAll(toolResponse.choices);
  }

  void _handleToolCallComplete() {
    if (_toolCallCollector.hasData) {
      if (widget.onToolCall != null) {
        var arguments =_toolCallCollector.arguments.toString();
        widget.onToolCall!(_toolCallCollector.functionName,  arguments)
        .then((toolResponse) {
          // Merge the tool response
          _mergeToolResponse(toolResponse);
        })
        .catchError((error) {
           print('Error handling tool call: $error');
         });


        // Reset the tool call collector for the next round
        _toolCallCollector.reset();
      }

    }
  }


  void _handleToolCall(OpenAIResponseToolCall toolCall) {
    if (toolCall.id != null) {
      _toolCallCollector.toolCallId = toolCall.id!;
    }

    if (toolCall.function.name != null) {
      _toolCallCollector.functionName += toolCall.function.name!;
    }

    if (toolCall.function.arguments != null) {
      _toolCallCollector.argumentsBuffer.write(toolCall.function.arguments!);
    }
  }

  void _updateStreamMessage(String content) {
    setState(() {
      _streamText += content;
      if (_messages.isNotEmpty) {
        _messages[0] = (_messages[0] as types.TextMessage).copyWith(
          text: _streamText,
        );
      }
    });
  }

  void _startNewStreamMessage(String id, String content) {
    setState(() {
      _streamText = content;
      _chatResponseId = id;
      _isAiTyping = true;

      final newMessage = types.TextMessage(
        author: _ai,
        id: id,
        text: content,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      _messages.insert(0, newMessage);
    });
  }

  void _handleStreamComplete(String finalContent) {
    setState(() {
      _isAiTyping = false;
      _chatResponseId = '';
      _streamText = '';

      if (_messages.isNotEmpty && _messages[0] is types.TextMessage) {
        _messages[0] = (_messages[0] as types.TextMessage).copyWith(
          status: types.Status.sent,
        );
      }
    });

    _aiMessages.add(
      OpenAIChatCompletionChoiceMessageModel(
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(finalContent)
        ],
        role: OpenAIChatMessageRole.assistant,
      ),
    );

    widget.onNewMessage?.call(
      ChatMessage(
        content: finalContent,
        isUserMessage: false,
        timestamp: DateTime.now(),
        status: LocalMessageStatus.sent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Chat(
      theme: widget.config.chatTheme,
      messages: _messages,
      onSendPressed: _handleSendPressed,
      user: _user,
      customMessageBuilder: widget.customMessageBuilder,
      onAttachmentPressed: _handleImageSelection,
      typingIndicatorOptions: TypingIndicatorOptions(
        typingUsers: [if (_isAiTyping) _ai],
      ),
      inputOptions: InputOptions(
        enabled: !_isAiTyping,
      ),
    );
  }
}
