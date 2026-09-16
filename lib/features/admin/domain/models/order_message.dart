class OrderMessage {
  final String id;
  final String orderId;
  final String senderType; // 'client' | 'tech' | 'admin'
  final String senderName;
  final String message;
  final String? audioUrl;
  final DateTime createdAt;

  const OrderMessage({
    required this.id,
    required this.orderId,
    required this.senderType,
    required this.senderName,
    required this.message,
    this.audioUrl,
    required this.createdAt,
  });

  bool get isFromClient => senderType == 'client';
  bool get isFromTech => senderType == 'tech';

  factory OrderMessage.fromJson(Map<String, dynamic> json) {
    return OrderMessage(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      senderType: json['sender_type']?.toString() ?? 'client',
      senderName: json['sender_name']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      audioUrl: json['audio_url']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'order_id': orderId,
    'sender_type': senderType,
    'sender_name': senderName,
    'message': message,
    if (audioUrl != null) 'audio_url': audioUrl,
    'created_at': createdAt.toIso8601String(),
  };
}
