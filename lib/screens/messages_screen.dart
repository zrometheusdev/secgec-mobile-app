import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:secgec/widgets/smart_avatar.dart';
import 'package:secgec/screens/profile_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

class MessagesScreen extends StatefulWidget {
  final String? targetUserId;
  final String? targetUserName;

  const MessagesScreen({super.key, this.targetUserId, this.targetUserName});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    if (widget.targetUserId != null && user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startChat(widget.targetUserId!, widget.targetUserName ?? 'Kullanıcı');
      });
    }
  }

  void _startChat(String otherId, String otherName) async {
    if (user == null) return;

    // Check if chat exists
    final chatId = user!.uid.hashCode <= otherId.hashCode
        ? '${user!.uid}_$otherId'
        : '${otherId}_${user!.uid}';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(chatId: chatId, otherUserName: otherName, otherUserId: otherId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Scaffold(body: Center(child: Text('Giriş yapmalısınız.')));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Mesajlar', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: user!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            // Eğer hala index hatası veriyorsa, kullanıcıya bir uyarı yerine boş liste gösterip loglayabiliriz.
            // Ancak orderBy'ı zaten kaldırdığımız için bu hatanın gelmemesi lazım.
            return Center(child: Text('Dizin Hatası: ${snapshot.error}', style: const TextStyle(color: Colors.white, fontSize: 10)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final chats = snapshot.data?.docs ?? [];

          // Bellekte manuel sıralama (Index hatasını önlemek için)
          final sortedChats = List<DocumentSnapshot>.from(chats);
          sortedChats.sort((a, b) {
            final aTime = (a.data() as Map<String, dynamic>)['lastMessageTime'] as Timestamp?;
            final bTime = (b.data() as Map<String, dynamic>)['lastMessageTime'] as Timestamp?;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          if (sortedChats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.messageCircle, size: 64, color: Colors.white.withOpacity(0.1)),
                  const SizedBox(height: 16),
                  const Text('Henüz mesajın yok', style: TextStyle(color: Colors.white54)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: sortedChats.length,
            itemBuilder: (context, index) {
              final chatData = sortedChats[index].data() as Map<String, dynamic>;
              final participantsInfo = (chatData['participantsInfo'] as Map<String, dynamic>? ?? {});

              // Find other guy's info
              String otherId = '';
              String otherName = 'Bilinmeyen Kullanıcı';
              String otherPhoto = '';

              chatData['participants'].forEach((pId) {
                if (pId != user!.uid) {
                  otherId = pId;
                  otherName = participantsInfo[pId]?['name'] ?? 'Kullanıcı';
                  otherPhoto = participantsInfo[pId]?['photo'] ?? '';
                }
              });

              return ListTile(
                leading: SmartAvatar(url: otherPhoto, radius: 24),
                title: Text(otherName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(
                  chatData['lastMessage'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54),
                ),
                trailing: chatData['lastMessageTime'] != null
                    ? Text(
                  timeago.format((chatData['lastMessageTime'] as Timestamp).toDate(), locale: 'tr'),
                  style: const TextStyle(color: Colors.white24, fontSize: 10),
                )
                    : null,
                onTap: () => _startChat(otherId, otherName),
              );
            },
          );
        },
      ),
    );
  }
}

class ChatDetailScreen extends StatefulWidget {
  final String chatId;
  final String otherUserName;
  final String otherUserId;

  const ChatDetailScreen({super.key, required this.chatId, required this.otherUserName, required this.otherUserId});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _msgController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;

  void _sendMessage() async {
    if (_msgController.text.trim().isEmpty || user == null) return;

    final msg = _msgController.text.trim();
    _msgController.clear();

    final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
    final msgRef = chatRef.collection('messages');

    final batch = FirebaseFirestore.instance.batch();

    final userDataSnap = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    final otherDataSnap = await FirebaseFirestore.instance.collection('users').doc(widget.otherUserId).get();

    batch.set(chatRef, {
      'participants': [user!.uid, widget.otherUserId],
      'participantsInfo': {
        user!.uid: {
          'name': userDataSnap.data()?['displayName'] ?? 'Kullanıcı',
          'photo': userDataSnap.data()?['photoURL'] ?? '',
        },
        widget.otherUserId: {
          'name': otherDataSnap.data()?['displayName'] ?? widget.otherUserName,
          'photo': otherDataSnap.data()?['photoURL'] ?? '',
        }
      },
      'lastMessage': msg,
      'lastMessageTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final newMsgDoc = msgRef.doc();
    batch.set(newMsgDoc, {
      'senderId': user!.uid,
      'text': msg,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // Notify
    await FirebaseFirestore.instance.collection('users').doc(widget.otherUserId).collection('notifications').add({
      'title': 'Yeni Mesaj',
      'body': '${userDataSnap.data()?['displayName'] ?? 'Biri'}: $msg',
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
      'type': 'message',
      'chatId': widget.chatId,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: const Color(0xFF111111),
        iconTheme: const IconThemeData(color: Colors.white),
        title: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).snapshots(),
            builder: (context, snapshot) {
              final chatData = snapshot.data?.data() as Map<String, dynamic>?;
              final otherInfo = (chatData?['participantsInfo'] as Map<String, dynamic>? ?? {})[widget.otherUserId] ?? {};
              final otherPhoto = otherInfo['photo'] ?? '';
              final otherName = otherInfo['name'] ?? widget.otherUserName;

              return InkWell(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: widget.otherUserId)));
                },
                child: Row(
                  children: [
                    SmartAvatar(url: otherPhoto, radius: 18),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(otherName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                        const Text('Profile gitmek için tıkla', style: TextStyle(color: Colors.white38, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              );
            }
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final msgs = snapshot.data?.docs ?? [];

                return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).snapshots(),
                    builder: (context, chatSnap) {
                      final chatData = chatSnap.data?.data() as Map<String, dynamic>?;
                      final info = chatData?['participantsInfo'] as Map<String, dynamic>? ?? {};

                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: msgs.length,
                        itemBuilder: (context, index) {
                          final data = msgs[index].data() as Map<String, dynamic>;
                          final senderId = data['senderId'];
                          final isMe = senderId == user?.uid;
                          final senderPhoto = info[senderId]?['photo'] ?? '';

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (!isMe) ...[
                                  SmartAvatar(url: senderPhoto, radius: 14),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isMe ? const Color(0xFF8B5CF6) : const Color(0xFF222222),
                                      borderRadius: BorderRadius.circular(20).copyWith(
                                        bottomRight: isMe ? const Radius.circular(2) : const Radius.circular(20),
                                        bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(2),
                                      ),
                                    ),
                                    child: Text(
                                      data['text'] ?? '',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 8),
                                  SmartAvatar(url: senderPhoto, radius: 14),
                                ],
                              ],
                            ),
                          );
                        },
                      );
                    }
                );
              },
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: Color(0xFF111111)),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Mesaj yaz...',
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: const CircleAvatar(
                      backgroundColor: Color(0xFF8B5CF6),
                      child: Icon(Icons.send, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
