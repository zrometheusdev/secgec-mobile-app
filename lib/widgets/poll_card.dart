import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import 'package:secgec/models/poll_enums.dart';
import 'package:secgec/widgets/modern_toast.dart';
import 'package:secgec/screens/profile_screen.dart';
import 'package:secgec/widgets/smart_avatar.dart';
import 'package:secgec/screens/discover_screen.dart';

class PollCard extends StatefulWidget {
  final Map<String, dynamic> poll;
  final String pollId;
  final VoidCallback onSwipedLeft;
  final VoidCallback onSwipedRight;
  final PollInteractionMode interactionMode;
  final bool showDelete;

  const PollCard({
    super.key,
    required this.poll,
    required this.pollId,
    required this.onSwipedLeft,
    required this.onSwipedRight,
    this.interactionMode = PollInteractionMode.swipe,
    this.showDelete = false,
  });

  @override
  State<PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<PollCard> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  double _swipeOffset = 0.0;
  bool _isAnimating = false;
  String? _userChoice;
  bool _checkingVote = true;

  bool _showLikeHeart = false;
  double _likeHeartScale = 0.0;
  bool _isLiked = false;
  bool _isSaved = false;

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
    });
    // In a real app, update Firestore subcollection 'likes' or 'likedBy'
    if (_isLiked) {
      _handleDoubleTap();
    }
  }

  void _toggleSave() {
    setState(() {
      _isSaved = !_isSaved;
    });
    ModernToast.info(context, _isSaved ? 'Kaydedildi' : 'Kaldırıldı', _isSaved ? 'Anket kaydedilenlere eklendi.' : 'Anket kaydedilenlerden kaldırıldı.');
  }

  void _handleDoubleTap() {
    if (mounted) {
      setState(() {
        _showLikeHeart = true;
        _likeHeartScale = 1.0;
        _isLiked = true;
      });

      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _showLikeHeart = false;
            _likeHeartScale = 0.0;
          });
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _checkUserVote();
  }

  Future<void> _checkUserVote() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (mounted) setState(() => _checkingVote = true);
      final voteRef = FirebaseFirestore.instance
          .collection('polls')
          .doc(widget.pollId)
          .collection('votes')
          .doc(user.uid);

      final voteSnap = await voteRef.get();
      if (mounted) {
        setState(() {
          if (voteSnap.exists) {
            _userChoice = voteSnap.data()?['choice'];
          }
          _checkingVote = false;
        });
      }
    } else {
      if (mounted) setState(() => _checkingVote = false);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _vote(String choice) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) ModernToast.error(context, 'Hata', 'Oy vermek için giriş yapmalısınız.');
      return;
    }

    final String? previousChoice = _userChoice;

    if (previousChoice == choice) {
      if (mounted) ModernToast.info(context, 'Bilgi', 'Zaten bu seçeneğe oy verdiniz.');
      return;
    }

    // Seçim anında küçük bir haptic geri bildirim hissi için ve görsel tepki için
    if (mounted) setState(() => _userChoice = choice);

    try {
      final pollRef = FirebaseFirestore.instance.collection('polls').doc(widget.pollId);
      final voteRef = pollRef.collection('votes').doc(user.uid);

      final batch = FirebaseFirestore.instance.batch();
      batch.set(voteRef, {
        'pollId': widget.pollId,
        'userId': user.uid,
        'choice': choice,
        'createdAt': FieldValue.serverTimestamp()
      }, SetOptions(merge: true));

      Map<String, dynamic> updates = {};
      if (previousChoice != null) {
        updates['votes$previousChoice'] = FieldValue.increment(-1);
        updates['votes$choice'] = FieldValue.increment(1);
      } else {
        updates['votes$choice'] = FieldValue.increment(1);
        updates['totalVotes'] = FieldValue.increment(1);
      }

      batch.update(pollRef, updates);

      await batch.commit();

      if (user.uid != widget.poll['creatorId'] && widget.poll['creatorId'] != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(widget.poll['creatorId']).collection('notifications').add({
            'title': 'Yeni Oy',
            'body': '${user.displayName ?? 'Birisi'} anketinize oy verdi.',
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
            'type': 'vote',
            'pollId': widget.pollId,
          });
        } catch (e) {
          debugPrint('Notification sent failed: $e');
        }
      }

      if (mounted) {
        ModernToast.success(context, 'Başarılı', 'Oyunuz $choice seçeneğine verildi');
      }

      // Animasyonla geçiş yapalım
      if (!mounted) return;
      final screenWidth = MediaQuery.sizeOf(context).width;
      if (choice == 'A') {
        _animateSwipe(screenWidth, widget.onSwipedRight);
      } else {
        _animateSwipe(-screenWidth, widget.onSwipedLeft);
      }
    } on FirebaseException catch (e) {
      if (mounted) ModernToast.error(context, 'Hata', 'Firebase Hatası: ${e.message}');
    } catch (e) {
      if (mounted) ModernToast.error(context, 'Hata', 'Sistem Hatası: $e');
    }
  }

  void _animateSwipe(double target, VoidCallback onComplete) {
    if (_isAnimating) return;
    _isAnimating = true;

    final start = _swipeOffset;
    final animation = Tween<double>(begin: start, end: target).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic)
    );

    animation.addListener(() {
      setState(() {
        _swipeOffset = animation.value;
      });
    });

    _animController.forward(from: 0).then((_) {
      _isAnimating = false;
      onComplete();
      // Sıfırla (eğer aynı widget tekrar kullanılacaksa)
      if (mounted) {
        setState(() {
          _swipeOffset = 0;
        });
      }
      _animController.reset();
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (widget.interactionMode != PollInteractionMode.swipe || _isAnimating) return;
    setState(() {
      _swipeOffset += details.delta.dx;
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (widget.interactionMode != PollInteractionMode.swipe || _isAnimating) return;

    final threshold = MediaQuery.of(context).size.width * 0.3;
    if (_swipeOffset > threshold) {
      _vote('A');
    } else if (_swipeOffset < -threshold) {
      _vote('B');
    } else {
      // Geri dön
      _animateSwipe(0, () {});
    }
  }

  void _sharePoll() {
    final title = widget.poll['title'] ?? 'SeçGeç Anketi';
    final pollId = widget.pollId;
    Share.share('Hadi bu ankete sen de katıl! "$title" \n\nUygulamayı indir ve oyunu kullan: https://secgec.app/poll/$pollId');
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final reasons = ['Spam', 'Uygunsuz İçerik', 'Nefret Söylemi', 'Telif Hakkı', 'Diğer'];
        return AlertDialog(
          title: const Text('Anketi Raporla'),
          backgroundColor: const Color(0xFF1A1A1A),
          titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons.map((reason) => ListTile(
              title: Text(reason, style: const TextStyle(color: Colors.white70)),
              onTap: () async {
                final user = FirebaseAuth.instance.currentUser;
                await FirebaseFirestore.instance.collection('reports').add({
                  'pollId': widget.pollId,
                  'reporterId': user?.uid ?? 'anonim',
                  'reason': reason,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (mounted) {
                  Navigator.pop(context);
                  ModernToast.success(context, 'Rapor İletildi', 'Bildiriminiz için teşekkürler.');
                }
              },
            )).toList(),
          ),
        );
      },
    );
  }

  void _deletePoll() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Anketi Sil'),
          content: const Text('Bu anketi silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.'),
          backgroundColor: const Color(0xFF1A1A1A),
          titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          contentTextStyle: const TextStyle(color: Colors.white70),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await FirebaseFirestore.instance.collection('polls').doc(widget.pollId).delete();
                  if (mounted) ModernToast.success(context, 'Silindi', 'Anket başarıyla silindi.');
                } catch (e) {
                  if (mounted) ModernToast.error(context, 'Hata', 'Anket silinirken bir hata oluştu: $e');
                }
              },
              child: const Text('Sil', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CommentSheet(pollId: widget.pollId),
    );
  }

  Widget _buildResultOverlay({
    required String choice,
    required int votes,
    required int total,
    required bool isSelected,
  }) {
    final percentage = total == 0 ? 0 : (votes / total * 100).round();
    return AnimatedScale(
      scale: isSelected ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blueAccent.withAlpha(50)
                  : Colors.black.withAlpha(160),
              border: isSelected
                  ? Border.all(color: Colors.blueAccent.withAlpha(120), width: 3.5)
                  : null,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutBack,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Opacity(opacity: value, child: child),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueAccent.withAlpha(140),
                              blurRadius: 20,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.check, color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                            const Text('SENİN TERCİHİN', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                          ],
                        ),
                      ),
                    ),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: 0.8 + (0.2 * value),
                        child: Text(
                          '%$percentage',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: isSelected ? 80 : 64,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -4,
                              shadows: const [Shadow(color: Colors.black87, offset: Offset(0, 6), blurRadius: 20)]
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withAlpha(20)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.zap, color: Colors.yellowAccent, size: 14),
                        const SizedBox(width: 8),
                        Text(
                          '$votes OY',
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(String url, Color fallbackColor) {
    if (url.startsWith('data:image')) {
      try {
        final base64Str = url.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) => Container(color: fallbackColor),
        );
      } catch (e) {
        return Container(color: fallbackColor);
      }
    } else if (url.isNotEmpty && url.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        placeholder: (context, url) => Container(color: Colors.black, child: const Center(child: CircularProgressIndicator())),
        errorWidget: (context, url, error) => Container(color: fallbackColor),
      );
    } else {
      return Container(color: fallbackColor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final imageA = widget.poll['imageA'] ?? '';
    final imageB = widget.poll['imageB'] ?? '';
    final title = widget.poll['title'] ?? 'İsimsiz Anket';
    final creatorName = widget.poll['creatorName'] ?? 'Kullanıcı';

    String creatorPhoto = widget.poll['creatorPhoto'] ?? '';
    if (creatorPhoto.isEmpty || !creatorPhoto.startsWith('http')) {
      creatorPhoto = 'https://api.dicebear.com/7.x/avataaars/png?seed=${widget.poll['creatorId'] ?? 'default'}';
    }

    DateTime? createdAt;
    if (widget.poll['createdAt'] != null) {
      if (widget.poll['createdAt'] is Timestamp) {
        createdAt = (widget.poll['createdAt'] as Timestamp).toDate();
      } else if (widget.poll['createdAt'] is DateTime) {
        createdAt = widget.poll['createdAt'] as DateTime;
      }
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final rotation = (_swipeOffset / screenWidth) * 0.1; // Radyan cinsinden

    if (_checkingVote) {
      return Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (isDark ? Colors.black : Colors.white).withAlpha(200),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Center(child: CircularProgressIndicator(color: isDark ? Colors.white : Colors.black)),
      );
    }

    return RepaintBoundary(
      child: GestureDetector(
        onDoubleTap: _handleDoubleTap,
        child: Stack(
          children: [
            GestureDetector(
              onPanUpdate: widget.interactionMode == PollInteractionMode.swipe ? _handlePanUpdate : null,
              onPanEnd: widget.interactionMode == PollInteractionMode.swipe ? _handlePanEnd : null,
              child: Transform.translate(
                offset: Offset(_swipeOffset, 0),
                child: Transform.rotate(
                  angle: rotation,
                  child: Container(
                    margin: widget.interactionMode == PollInteractionMode.swipe
                        ? EdgeInsets.zero
                        : const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black : Colors.white,
                      borderRadius: widget.interactionMode == PollInteractionMode.swipe
                          ? BorderRadius.zero
                          : BorderRadius.circular(32),
                      boxShadow: widget.interactionMode == PollInteractionMode.swipe
                          ? null
                          : [
                        BoxShadow(
                          color: Colors.black.withAlpha(50),
                          blurRadius: 20,
                          spreadRadius: 5,
                        )
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Images
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: widget.interactionMode == PollInteractionMode.tap ? () => _vote('A') : null,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    _buildImage(imageA, isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0)),
                                    // Subtle Vignette
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: RadialGradient(
                                          colors: [
                                            Colors.black.withAlpha(0),
                                            Colors.black.withAlpha(100),
                                          ],
                                          center: Alignment.center,
                                          radius: 1.5,
                                        ),
                                      ),
                                    ),
                                    if (_userChoice != null)
                                      _buildResultOverlay(
                                        choice: 'A',
                                        votes: widget.poll['votesA'] ?? 0,
                                        total: widget.poll['totalVotes'] ?? 0,
                                        isSelected: _userChoice == 'A',
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: widget.interactionMode == PollInteractionMode.tap ? () => _vote('B') : null,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    _buildImage(imageB, isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0)),
                                    // Subtle Vignette
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: RadialGradient(
                                          colors: [
                                            Colors.black.withAlpha(0),
                                            Colors.black.withAlpha(100),
                                          ],
                                          center: Alignment.center,
                                          radius: 1.5,
                                        ),
                                      ),
                                    ),
                                    if (_userChoice != null)
                                      _buildResultOverlay(
                                        choice: 'B',
                                        votes: widget.poll['votesB'] ?? 0,
                                        total: widget.poll['totalVotes'] ?? 0,
                                        isSelected: _userChoice == 'B',
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Diagonal Split Line (Visual interest)
                        Center(
                          child: Container(
                            width: 2,
                            color: Colors.white.withAlpha(40),
                          ),
                        ),


                        // Selection Indicators during swipe
                        if (_swipeOffset > 20)
                          Positioned(
                            top: 100,
                            left: 40,
                            child: Transform.rotate(
                              angle: -0.2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.black87 : Colors.white,
                                  border: Border.all(color: Colors.blueAccent, width: 4),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('SEÇENEK A', style: TextStyle(color: Colors.blueAccent, fontSize: 32, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        if (_swipeOffset < -20)
                          Positioned(
                            top: 100,
                            right: 40,
                            child: Transform.rotate(
                              angle: 0.2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.black87 : Colors.white,
                                  border: Border.all(color: Colors.pinkAccent, width: 4),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('SEÇENEK B', style: TextStyle(color: Colors.pinkAccent, fontSize: 32, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),

                        // VS Circle
                        Center(
                          child: AnimatedScale(
                            scale: _swipeOffset.abs() > 50 ? 1.2 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(20),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withAlpha(80), width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withAlpha(30),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withAlpha(60),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              alignment: Alignment.center,
                              child: ClipOval(
                                child: BackdropFilter(
                                  filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: const Text('VS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 1.5, shadows: [Shadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4)])),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Info Overlay
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withAlpha(160),
                                    Colors.transparent,
                                    Colors.transparent,
                                    Colors.black.withAlpha(100),
                                    Colors.black.withAlpha(240),
                                  ],
                                  stops: const [0.0, 0.2, 0.4, 0.6, 1.0],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Engagement Actions (Side Bar - Social Style)
                        Positioned(
                          right: 16,
                          bottom: 220,
                          child: Column(
                            children: [
                              _SideAction(
                                icon: _isLiked ? LucideIcons.heart : LucideIcons.heart,
                                count: '${widget.poll['totalVotes'] ?? 0}',
                                onTap: _toggleLike,
                                color: _isLiked ? Colors.redAccent : Colors.white,
                              ),
                              const SizedBox(height: 24),
                              _SideAction(
                                icon: LucideIcons.messageSquare,
                                count: null,
                                onTap: _showComments,
                                stream: FirebaseFirestore.instance.collection('polls').doc(widget.pollId).collection('comments').snapshots(),
                                color: Colors.white,
                              ),
                              const SizedBox(height: 24),
                              _SideAction(
                                icon: _isSaved ? LucideIcons.bookmark : LucideIcons.bookmark,
                                onTap: _toggleSave,
                                color: _isSaved ? Colors.amber : Colors.white,
                              ),
                              const SizedBox(height: 24),
                              _SideAction(
                                icon: LucideIcons.share2,
                                onTap: _sharePoll,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),

                        // Info Content (Bottom Left)
                        Positioned(
                          left: 20,
                          right: 80, // Leave room for side actions
                          bottom: 180,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  if (widget.poll['creatorId'] != null) {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: widget.poll['creatorId'])));
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(20),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SmartAvatar(url: creatorPhoto, radius: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        creatorName,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.2),
                                      ),
                                      if (widget.poll['creatorIsVerified'] == true)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 4),
                                          child: Icon(Icons.verified, color: Colors.blueAccent, size: 14),
                                        ),
                                      const SizedBox(width: 8),
                                      if (createdAt != null)
                                        Text(
                                          timeago.format(createdAt, locale: 'tr'),
                                          style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 11, fontWeight: FontWeight.w500),
                                        ),
                                      const SizedBox(width: 8),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              _buildRichTextTitle(title),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Like Heart Animation
            if (_showLikeHeart)
              Center(
                child: AnimatedScale(
                  scale: _likeHeartScale,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.elasticOut,
                  child: const Icon(
                    LucideIcons.heart,
                    color: Colors.redAccent,
                    size: 100,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 20)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRichTextTitle(String text) {
    final words = text.split(' ');
    List<InlineSpan> spans = [];

    for (var word in words) {
      if (word.startsWith('#')) {
        spans.add(
          WidgetSpan(
            alignment: ui.PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => DiscoverScreen(initialSearch: word)));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withAlpha(40),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$word ',
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: '$word ',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              height: 1.1,
            ),
          ),
        );
      }
    }

    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Colors.white, Colors.white70],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: RichText(
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(children: spans),
      ),
    );
  }
}

class _SideAction extends StatefulWidget {
  final IconData icon;
  final String? count;
  final VoidCallback onTap;
  final Stream<QuerySnapshot>? stream;
  final Color color;

  const _SideAction({
    required this.icon,
    this.count,
    required this.onTap,
    this.stream,
    this.color = Colors.white,
  });

  @override
  State<_SideAction> createState() => _SideActionState();
}

class _SideActionState extends State<_SideAction> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(40),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withAlpha(20), width: 1),
              ),
              child: ClipOval(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    alignment: Alignment.center,
                    child: Icon(widget.icon, color: widget.color, size: 26),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            if (widget.stream != null)
              StreamBuilder<QuerySnapshot>(
                stream: widget.stream,
                builder: (context, snapshot) {
                  final c = snapshot.data?.docs.length ?? 0;
                  return Text(
                    '$c',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 2)]),
                  );
                },
              )
            else if (widget.count != null)
              Text(
                widget.count!,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 2)]),
              ),
          ],
        ),
      ),
    );
  }
}

class _CommentSheet extends StatefulWidget {
  final String pollId;

  const _CommentSheet({required this.pollId});

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final user = FirebaseAuth.instance.currentUser;
  String? _replyToCommentId;
  String? _replyToUserName;
  final Set<String> _expandedReplies = {};

  void _sendComment() async {
    if (user == null || _commentController.text.trim().isEmpty) return;

    final commentText = _commentController.text.trim();
    final isReply = _replyToCommentId != null;

    final data = {
      'userId': user!.uid,
      'userName': user!.displayName ?? 'Anonim',
      'userPhoto': user!.photoURL ?? '',
      'text': commentText,
      'createdAt': FieldValue.serverTimestamp(),
      'replyToId': _replyToCommentId,
      'replyToUserName': _replyToUserName,
    };

    _commentController.clear();
    setState(() {
      _replyToCommentId = null;
      _replyToUserName = null;
    });

    await _firestore.collection('polls').doc(widget.pollId).collection('comments').add(data);

    // Add Notification
    if (user != null && widget.pollId.isNotEmpty) {
      // Find poll creator
      try {
        final pollSnap = await _firestore.collection('polls').doc(widget.pollId).get();
        if (pollSnap.exists) {
          final creatorId = pollSnap.data()?['creatorId'];
          if (creatorId != null && creatorId != user!.uid) {
            await _firestore.collection('users').doc(creatorId).collection('notifications').add({
              'title': 'Yeni Yorum',
              'body': '${user!.displayName ?? 'Birisi'}: $commentText',
              'createdAt': FieldValue.serverTimestamp(),
              'isRead': false,
              'type': 'comment',
              'pollId': widget.pollId,
            });
          }
        }
      } catch (e) {
        debugPrint('Comment notification error $e');
      }
    }
  }

  void _setReply(String commentId, String userName) {
    setState(() {
      _replyToCommentId = commentId;
      _replyToUserName = userName;
      _commentController.text = '@$userName ';
      _commentController.selection = TextSelection.fromPosition(TextPosition(offset: _commentController.text.length));
    });
  }

  void _toggleReplies(String commentId) {
    setState(() {
      if (_expandedReplies.contains(commentId)) {
        _expandedReplies.remove(commentId);
      } else {
        _expandedReplies.add(commentId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black12, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 32),
                Text('Yorumlar', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: Icon(Icons.close, color: isDark ? Colors.white54 : Colors.black54),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('polls')
                  .doc(widget.pollId)
                  .collection('comments')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final allComments = snapshot.data!.docs;

                // Root comments (not replies)
                final rootComments = allComments.where((c) => (c.data() as Map)['replyToId'] == null).toList();

                if (rootComments.isEmpty) {
                  return Center(child: Text('İlk yorumu sen yap!', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: rootComments.length,
                  itemBuilder: (context, index) {
                    final commentDoc = rootComments[index];
                    final data = commentDoc.data() as Map<String, dynamic>;
                    final commentId = commentDoc.id;

                    // Filter replies for this comment
                    final replies = allComments.where((c) => (c.data() as Map)['replyToId'] == commentId).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCommentItem(data, commentId, isDark),
                        if (replies.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(left: 44, bottom: 8),
                            child: GestureDetector(
                              onTap: () => _toggleReplies(commentId),
                              child: Text(
                                _expandedReplies.contains(commentId) ? 'Yanıtları Gizle' : '${replies.length} Yanıtı Gör',
                                style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          if (_expandedReplies.contains(commentId))
                            ...replies.map((reply) {
                              final replyData = reply.data() as Map<String, dynamic>;
                              return Padding(
                                padding: const EdgeInsets.only(left: 44, bottom: 12),
                                child: _buildCommentItem(replyData, reply.id, isDark, isReply: true),
                              );
                            }).toList(),
                        ],
                        const Divider(height: 1, color: Colors.white10),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          if (_replyToUserName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              color: Colors.blue.withOpacity(0.1),
              child: Row(
                children: [
                  Text('$_replyToUserName kullanıcısına yanıt veriliyor', style: const TextStyle(color: Colors.blue, fontSize: 12)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() { _replyToCommentId = null; _replyToUserName = null; }),
                    child: const Icon(Icons.close, size: 16, color: Colors.blue),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: isDark ? Colors.black45 : Colors.white,
                border: Border(top: BorderSide(color: isDark ? Colors.white.withAlpha(13) : Colors.black.withAlpha(13)))
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Bir şeyler yaz...',
                      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                      filled: true,
                      fillColor: isDark ? Colors.white.withAlpha(13) : Colors.black.withAlpha(13),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(LucideIcons.send, color: Colors.blue),
                  onPressed: _sendComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> data, String commentId, bool isDark, {bool isReply = false}) {
    String photo = data['userPhoto'] ?? '';
    if (photo.isEmpty) photo = 'https://api.dicebear.com/7.x/avataaars/png?seed=${data['userId']}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            if (data['userId'] != null) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: data['userId'])));
            }
          },
          child: CircleAvatar(
            radius: isReply ? 12 : 16,
            backgroundImage: CachedNetworkImageProvider(photo),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (data['userId'] != null) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: data['userId'])));
                      }
                    },
                    child: Text(data['userName'] ?? 'Anonim', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  if (data['createdAt'] != null)
                    Text(
                      timeago.format((data['createdAt'] as Timestamp).toDate(), locale: 'tr'),
                      style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 10),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  children: [
                    if (data['replyToUserName'] != null)
                      TextSpan(
                        text: '@${data['replyToUserName']} ',
                        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    TextSpan(
                      text: data['text'] ?? '',
                      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _setReply(commentId, data['userName'] ?? 'Anonim'),
                child: const Text('Yanıtla', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
