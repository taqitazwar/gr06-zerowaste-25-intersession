import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String sender;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.sender,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'sender': sender,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      sender: map['sender'] ?? '',
      content: map['content'] ?? '',
      timestamp: map['timestamp'] != null 
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

class MessageModel {
  final String chatId;
  final String postId;
  final String user1;
  final String user2;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime lastUpdated;

  MessageModel({
    required this.chatId,
    required this.postId,
    required this.user1,
    required this.user2,
    required this.messages,
    required this.createdAt,
    required this.lastUpdated,
  });

  // Convert MessageModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'postId': postId,
      'user1': user1,
      'user2': user2,
      'messages': messages.map((msg) => msg.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  // Create MessageModel from Firestore Document
  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      chatId: map['chatId'] ?? '',
      postId: map['postId'] ?? '',
      user1: map['user1'] ?? '',
      user2: map['user2'] ?? '',
      messages: (map['messages'] as List<dynamic>?)
          ?.map((msgMap) => ChatMessage.fromMap(msgMap as Map<String, dynamic>))
          .toList() ?? [],
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastUpdated: map['lastUpdated'] != null 
          ? (map['lastUpdated'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // Create MessageModel from Firestore DocumentSnapshot
  factory MessageModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['chatId'] = doc.id; // Use document ID as chatId
    return MessageModel.fromMap(data);
  }

  MessageModel copyWith({
    String? chatId,
    String? postId,
    String? user1,
    String? user2,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? lastUpdated,
  }) {
    return MessageModel(
      chatId: chatId ?? this.chatId,
      postId: postId ?? this.postId,
      user1: user1 ?? this.user1,
      user2: user2 ?? this.user2,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  // Add a new message to the chat
  MessageModel addMessage(ChatMessage message) {
    final updatedMessages = List<ChatMessage>.from(messages)..add(message);
    return copyWith(
      messages: updatedMessages,
      lastUpdated: DateTime.now(),
    );
  }

  // Get the last message
  ChatMessage? get lastMessage => messages.isNotEmpty ? messages.last : null;

  @override
  String toString() {
    return 'MessageModel(chatId: $chatId, postId: $postId, messageCount: ${messages.length})';
  }
} 