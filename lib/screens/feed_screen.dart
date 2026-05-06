import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:secgec/widgets/poll_card.dart';
import 'package:secgec/models/poll_enums.dart';
import 'package:secgec/screens/messages_screen.dart';
import 'package:secgec/screens/notifications_screen.dart';
import 'package:secgec/widgets/badged_icon.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _firestore = FirebaseFirestore.instance;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPoll() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  int _selectedTab = 0; // 0: For You, 1: Following

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: _selectedTab == 0 ? Colors.white : Colors.white54,
                  fontSize: _selectedTab == 0 ? 18 : 16,
                  letterSpacing: -0.5,
                ),
                child: const Text('Senin İçin'),
              ),
            ),
            const SizedBox(width: 20),
            GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: _selectedTab == 1 ? Colors.white : Colors.white54,
                  fontSize: _selectedTab == 1 ? 18 : 16,
                  letterSpacing: -0.5,
                ),
                child: const Text('Takip Ettiklerin'),
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withAlpha(200),
                Colors.black.withAlpha(0),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: BadgedIcon(
              icon: LucideIcons.search,
              color: Colors.white,
              collectionPath: 'none',
              showBadge: false,
            ),
            onPressed: () {
              // Quick search context
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _selectedTab == 0
            ? _firestore.collection('polls').orderBy('createdAt', descending: true).limit(15).snapshots()
            : _firestore.collection('polls').where('isFeatured', isEqualTo: true).limit(10).snapshots(), // Dummy following fallback
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text('Bağlantı Hatası: ${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Yükleniyor...', textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                ],
              ),
            );
          }

          final polls = snapshot.data?.docs ?? [];

          if (polls.isEmpty) {
            return Center(child: Text('Henüz anket yok.', style: TextStyle(color: isDark ? Colors.grey : Colors.black54)));
          }

          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: polls.length,
            itemBuilder: (context, index) {
              final pollData = polls[index].data() as Map<String, dynamic>;
              final pollId = polls[index].id;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                child: PollCard(
                  poll: pollData,
                  pollId: pollId,
                  onSwipedLeft: _nextPoll,
                  onSwipedRight: _nextPoll,
                  interactionMode: PollInteractionMode.tap,
                  showDelete: false,
                ),
              );
            },
          );
        },
      ),
    );
  }
}


