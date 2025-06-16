import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chats')
          .where('participants', arrayContains: _auth.currentUser?.uid)
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          );
        }

        final chats = snapshot.data!.docs;

        if (chats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.message_outlined,
                  size: 80,
                  color: AppColors.secondary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No messages yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Messages will appear here when you start chatting',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index].data() as Map<String, dynamic>;
            final chatId = chats[index].id;
            final participants = List<String>.from(chat['participants'] ?? []);
            final otherUserId = participants.firstWhere(
              (id) => id != _auth.currentUser?.uid,
              orElse: () => '',
            );

            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(otherUserId).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final userData = userSnapshot.data?.exists == true
                    ? UserModel.fromDocument(userSnapshot.data!)
                    : null;
                final userName = userData?.name ?? 'Unknown User';
                final userImage = userData?.profileImageUrl;

                return _buildChatTile(
                  chatId: chatId,
                  userName: userName,
                  userImage: userImage,
                  lastMessage: chat['lastMessage'] ?? 'No messages yet',
                  lastMessageTime: (chat['lastMessageTime'] as Timestamp)
                      .toDate(),
                  postTitle: chat['postTitle'] ?? '',
                  otherUserId: otherUserId,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildChatTile({
    required String chatId,
    required String userName,
    String? userImage,
    required String lastMessage,
    required DateTime lastMessageTime,
    required String postTitle,
    required String otherUserId,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatId: chatId,
                postTitle: postTitle,
                otherUserId: otherUserId,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // User Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                backgroundImage: userImage != null
                    ? NetworkImage(userImage)
                    : null,
                child: userImage == null
                    ? Text(
                        userName[0].toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              // Chat Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      postTitle,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Timestamp
              Text(
                DateFormat('h:mm a').format(lastMessageTime),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
