import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:secgec/widgets/poll_card.dart';
import 'package:secgec/models/poll_enums.dart';

class PollDetailScreen extends StatelessWidget {
  final Map<String, dynamic> poll;
  final String pollId;

  const PollDetailScreen({super.key, required this.poll, required this.pollId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: PollCard(
        poll: poll,
        pollId: pollId,
        onSwipedLeft: () => Navigator.pop(context),
        onSwipedRight: () => Navigator.pop(context),
        interactionMode: PollInteractionMode.swipe,
      ),
    );
  }
}
