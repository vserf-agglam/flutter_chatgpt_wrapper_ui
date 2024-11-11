class ChatOperationResult<T> {
  final bool success;
  final String? error;
  final T? data;
  final DateTime timestamp;

  ChatOperationResult({
    required this.success,
    this.error,
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ChatOperationResult.success(T data) {
    return ChatOperationResult(
      success: true,
      data: data,
    );
  }

  factory ChatOperationResult.error(String error) {
    return ChatOperationResult(
      success: false,
      error: error,
    );
  }
}
