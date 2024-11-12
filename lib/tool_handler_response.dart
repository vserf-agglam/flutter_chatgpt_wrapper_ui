import 'package:dart_openai/dart_openai.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;


class ToolHandlerResponse {
  List<types.Message> messages = [];
  List<OpenAIChatCompletionChoiceMessageModel> choices = [];
}