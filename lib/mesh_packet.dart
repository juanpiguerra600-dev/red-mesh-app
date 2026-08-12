import 'dart:convert';

class MeshPacket {
  final String id;
  final String senderId;
  final String recipientId;
  final String payload;
  int ttl;
  final List<String> routeHistory;

  MeshPacket({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.payload,
    this.ttl = 5,
    List<String>? routeHistory,
  }) : this.routeHistory = routeHistory ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'recipientId': recipientId,
    'payload': payload,
    'ttl': ttl,
    'routeHistory': routeHistory,
  };

  factory MeshPacket.fromJson(Map<String, dynamic> json) => MeshPacket(
    id: json['id'],
    senderId: json['senderId'],
    recipientId: json['recipientId'],
    payload: json['payload'],
    ttl: json['ttl'],
    routeHistory: List<String>.from(json['routeHistory']),
  );

  String serialize() => jsonEncode(toJson());
  static MeshPacket deserialize(String raw) => MeshPacket.fromJson(jsonDecode(raw));
}
