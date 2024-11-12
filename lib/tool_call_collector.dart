
class ToolCallCollector {
  String functionName = '';
  String toolCallId = '';
  StringBuffer argumentsBuffer = StringBuffer();

  void reset() {
    functionName = '';
    toolCallId = '';
    argumentsBuffer.clear();
  }

  bool get hasData => functionName.isNotEmpty && toolCallId.isNotEmpty;
  String get arguments => argumentsBuffer.toString();
}
