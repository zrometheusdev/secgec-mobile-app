import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BadgedIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String collectionPath; // e.g. 'notifications' or 'chats'
  final bool isMessage;
  final bool showBadge;

  const BadgedIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.collectionPath,
    this.isMessage = false,
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showBadge) return Icon(icon, color: color);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Icon(icon, color: color);
    }

    Stream<QuerySnapshot> stream;
    if (isMessage) {
      // Messages unread count could be calculated if chats have 'unreadCount_${user.uid}' field.
      // For now, let's just assume we check for 'chats' where 'unreadCount_${user.uid}' > 0
      stream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection(collectionPath)
          .where('unreadCount', isGreaterThan: 0) // Adjust if different schema
          .snapshots();
    } else {
      stream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection(collectionPath)
          .where('isRead', isEqualTo: false)
          .snapshots();
    }

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: color),
        StreamBuilder<QuerySnapshot>(
          stream: stream,
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const SizedBox.shrink();
            }

            final count = snapshot.data!.docs.length;
            final displayCount = count > 9 ? '9+' : count.toString();

            return Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  displayCount,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
