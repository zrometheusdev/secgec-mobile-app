import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:secgec/screens/poll_detail_screen.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:secgec/widgets/smart_avatar.dart';
import 'dart:convert';
import 'package:lucide_icons/lucide_icons.dart';

class DiscoverScreen extends StatefulWidget {
  final String? initialSearch;
  const DiscoverScreen({super.key, this.initialSearch});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialSearch ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: isDark ? Colors.black : const Color(0xFFF5F5F5),
            elevation: 0,
            toolbarHeight: 100,
            title: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: (isDark ? Colors.white : Colors.black).withAlpha(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 40 : 10),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.w500),
                  onChanged: (val) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Keşfet...',
                    hintStyle: TextStyle(color: (isDark ? Colors.white : Colors.black).withAlpha(100), fontSize: 15),
                    prefixIcon: Icon(LucideIcons.search, color: (isDark ? Colors.white : Colors.black).withAlpha(140), size: 18),
                    suffixIcon: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.slidersHorizontal, color: Colors.blueAccent, size: 16),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ),
            ),
          ),
          if (_searchController.text.isEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 16.0),
                child: SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildCategoryChip('Trendler', isSelected: true, isDark: isDark),
                      _buildCategoryChip('#Moda', isDark: isDark),
                      _buildCategoryChip('#Teknoloji', isDark: isDark),
                      _buildCategoryChip('#Spor', isDark: isDark),
                      _buildCategoryChip('#Müzik', isDark: isDark),
                    ],
                  ),
                ),
              ),
            ),
            StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('polls').limit(20).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final polls = snapshot.data!.docs;

                  if (polls.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.tag, size: 64, color: (isDark ? Colors.white : Colors.black).withOpacity(0.1)),
                            const SizedBox(height: 16),
                            Text(
                              'Henüz aktif bir anket yok.',
                              style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.5)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    sliver: SliverMasonryGrid.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      itemBuilder: (context, index) {
                        final pollData = polls[index].data() as Map<String, dynamic>;
                        final id = polls[index].id;
                        return _buildPollThumbnail(pollData, id, isDark, index % 2 == 0 ? 240.0 : 200.0);
                      },
                      childCount: polls.length,
                    ),
                  );
                }
            ),
          ] else ...[
            // Dynamic Search Results
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('polls').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SliverToBoxAdapter(child: SizedBox());
                final query = _searchController.text.toLowerCase();
                final pollResults = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final title = (data['title'] ?? '').toString().toLowerCase();
                  return title.contains(query);
                }).toList();

                return SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (pollResults.isNotEmpty) ...[
                        const Text('Anketler', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 12),
                        ...pollResults.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 40, height: 40,
                                child: SmartAvatar(url: data['imageA'], radius: 20),
                              ),
                            ),
                            title: Text(data['title'] ?? 'İsimsiz Anket', style: const TextStyle(color: Colors.white)),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PollDetailScreen(poll: data, pollId: doc.id))),
                          );
                        }).toList(),
                        const SizedBox(height: 24),
                      ],
                      // Label for users if we were searching users too
                      const Text('Kişiler', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 12),
                      const Center(child: Text('Daha fazla kişi bulmak için kullanıcı adını tam yazın.', style: TextStyle(color: Colors.white54, fontSize: 12))),
                    ]),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, {bool isSelected = false, required bool isDark}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Transform.scale(scale: value, child: child),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        child: Material(
          color: isSelected ? Colors.blueAccent : (isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(10)),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPollThumbnail(Map<String, dynamic> data, String id, bool isDark, double height) {
    final imageA = data['imageA'] ?? '';
    Widget imageWidget;

    if (imageA.startsWith('data:image')) {
      try {
        final base64Str = imageA.split(',').last;
        final bytes = base64Decode(base64Str);
        imageWidget = Image.memory(bytes, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
      } catch (e) {
        imageWidget = Container(color: isDark ? Colors.white10 : Colors.black12);
      }
    } else if (imageA.startsWith('http')) {
      imageWidget = CachedNetworkImage(
        imageUrl: imageA,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => Container(color: isDark ? Colors.white10 : Colors.black12),
        errorWidget: (context, url, error) => Container(color: isDark ? Colors.white10 : Colors.black12),
      );
    } else {
      imageWidget = Container(color: isDark ? Colors.white10 : Colors.black12);
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => PollDetailScreen(poll: data, pollId: id)));
      },
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.black12,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 60 : 20),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageWidget,
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black87],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['title'] ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(40),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.zap, color: Colors.yellow, size: 12),
                            const SizedBox(width: 4),
                            Text('${data['totalVotes'] ?? 0}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


