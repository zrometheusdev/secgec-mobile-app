import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:io';
import 'dart:convert';
import 'package:secgec/screens/settings_subscreens.dart';
import 'package:secgec/widgets/poll_card.dart';
import 'package:secgec/widgets/smart_avatar.dart';
import 'package:secgec/models/poll_enums.dart';
import 'package:secgec/widgets/modern_toast.dart';
import 'package:secgec/screens/messages_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? userData;
  bool _isLoading = true;
  bool _isFollowing = false;
  int _followersCount = 0;
  int _followingCount = 0;
  int _pollsCount = 0;
  late TabController _tabController;

  late String? _targetUserId;
  bool _isCurrentUser = true;

  @override
  void initState() {
    super.initState();
    _targetUserId = widget.userId ?? user?.uid;
    _isCurrentUser = _targetUserId == user?.uid;
    _tabController = TabController(length: 2, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (_targetUserId != null) {
      try {
        final docSnap = await FirebaseFirestore.instance.collection('users').doc(_targetUserId).get();
        if (docSnap.exists) {
          final data = docSnap.data()!;

          // Gerçek sayıları Firebase'den çekiyoruz
          final followersSnap = await FirebaseFirestore.instance.collection('users').doc(_targetUserId).collection('followers').count().get();
          final followingSnap = await FirebaseFirestore.instance.collection('users').doc(_targetUserId).collection('following').count().get();
          final pollsSnap = await FirebaseFirestore.instance.collection('polls').where('creatorId', isEqualTo: _targetUserId).count().get();

          bool following = false;
          if (!_isCurrentUser && user != null) {
            final followDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('following').doc(_targetUserId).get();
            following = followDoc.exists;
          }

          if (mounted) {
            setState(() {
              userData = data;
              _followersCount = followersSnap.count ?? 0;
              _followingCount = followingSnap.count ?? 0;
              _pollsCount = pollsSnap.count ?? 0;
              _isFollowing = following;
              _isLoading = false;
            });
          }
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (user == null || _isCurrentUser) return;

    final currentUid = user!.uid;
    final targetUid = _targetUserId!;

    try {
      if (_isFollowing) {
        // Takipten çık
        await FirebaseFirestore.instance.collection('users').doc(currentUid).collection('following').doc(targetUid).delete();
        await FirebaseFirestore.instance.collection('users').doc(targetUid).collection('followers').doc(currentUid).delete();
        setState(() {
          _isFollowing = false;
          _followersCount = (_followersCount > 0) ? _followersCount - 1 : 0;
        });
      } else {
        // Takip et
        await FirebaseFirestore.instance.collection('users').doc(currentUid).collection('following').doc(targetUid).set({
          'timestamp': FieldValue.serverTimestamp(),
        });
        await FirebaseFirestore.instance.collection('users').doc(targetUid).collection('followers').doc(currentUid).set({
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Bildirim Gönder
        await FirebaseFirestore.instance.collection('users').doc(targetUid).collection('notifications').add({
          'title': 'Yeni Takipçi',
          'body': '${userData?['displayName'] ?? 'Birisi'} seni takip etmeye başladı!',
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
          'type': 'follow',
          'followerId': currentUid,
        });

        setState(() {
          _isFollowing = true;
          _followersCount++;
        });
      }
    } catch (e) {
      if (mounted) ModernToast.error(context, 'Hata', 'İşlem başarısız oldu.');
    }
  }

  Widget _buildSmartAvatar(String? url, {double radius = 46}) {
    // This is now replaced by SmartAvatar widget import
    return SmartAvatar(url: url, radius: radius);
  }

  Future<void> _pickAndUploadImage(StateSetter modalSetState) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (image != null) {
      modalSetState(() {});
      try {
        final storage = FirebaseStorage.instance;
        final storageRef = storage.ref().child('user_profiles').child('${user!.uid}.jpg');

        final uploadTask = storageRef.putFile(
          File(image.path),
          SettableMetadata(contentType: 'image/jpeg'),
        );

        await uploadTask.whenComplete(() => null);
        final downloadUrl = await storageRef.getDownloadURL();

        await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
          'photoURL': downloadUrl,
        }, SetOptions(merge: true));

        // Also update FirebaseAuth profile for local persistence
        await user!.updatePhotoURL(downloadUrl);

        await _loadProfile();
        if (mounted) Navigator.pop(context);
        if (mounted) ModernToast.success(context, 'Başarılı', 'Profil fotoğrafın güncellendi.');
      } catch (e) {
        if (!context.mounted) return;
        String errorMessage = 'Hatalı yükleme: $e';
        if (e.toString().contains('permission-denied')) {
          errorMessage = 'Firebase Storage izni reddedildi. Lütfen kuralları kontrol edin.';
        }
        ModernToast.error(context, 'Hata', errorMessage);
      }
    }
  }

  Future<void> _pickAndUploadBanner(StateSetter modalSetState) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (image != null) {
      modalSetState(() {});
      try {
        final storage = FirebaseStorage.instance;
        final storageRef = storage.ref().child('user_banners').child('${user!.uid}.jpg');

        final uploadTask = storageRef.putFile(
          File(image.path),
          SettableMetadata(contentType: 'image/jpeg'),
        );

        await uploadTask.whenComplete(() => null);
        final downloadUrl = await storageRef.getDownloadURL();

        await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
          'bannerURL': downloadUrl,
        }, SetOptions(merge: true));

        await _loadProfile();
        if (mounted) Navigator.pop(context);
        if (mounted) ModernToast.success(context, 'Başarılı', 'Kapak fotoğrafın güncellendi.');
      } catch (e) {
        if (!context.mounted) return;
        ModernToast.error(context, 'Hata', 'Kapak fotoğrafı yüklenemedi: $e');
      }
    }
  }

  void _showEditProfileModal() {
    final nameCtrl = TextEditingController(text: userData?['displayName'] ?? '');
    final usernameCtrl = TextEditingController(text: userData?['username'] ?? '');
    final bioCtrl = TextEditingController(text: userData?['bio'] ?? '');

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF1A1A1A),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (context) {
          bool saving = false;
          return StatefulBuilder(
              builder: (context, setModalState) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                    left: 24, right: 24, top: 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Profili Düzenle', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white54)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Banner Edit
                      GestureDetector(
                        onTap: () => _pickAndUploadBanner(setModalState),
                        child: Container(
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: (userData?['bannerURL'] != null && userData?['bannerURL'].toString().isNotEmpty == true)
                                ? DecorationImage(image: NetworkImage(userData?['bannerURL']), fit: BoxFit.cover)
                                : null,
                            gradient: (userData?['bannerURL'] == null || userData?['bannerURL'].toString().isEmpty == true)
                                ? const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)])
                                : null,
                          ),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.image, color: Colors.white, size: 16),
                                  SizedBox(width: 8),
                                  Text('Kapağı Değiştir', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Stack(
                          children: [
                            SmartAvatar(url: userData?['photoURL'], radius: 40),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () => _pickAndUploadImage(setModalState),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Color(0xFF8B5CF6), shape: BoxShape.circle),
                                  child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: nameCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Ad Soyad',
                          labelStyle: TextStyle(color: Colors.white.withAlpha(128)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: usernameCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Kullanıcı Adı',
                          labelStyle: TextStyle(color: Colors.white.withAlpha(128)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          helperText: '7 günde 2 defa değiştirme hakkınız vardır.',
                          helperStyle: const TextStyle(color: Colors.grey, fontSize: 10),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: bioCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Biyografi',
                          labelStyle: TextStyle(color: Colors.white.withAlpha(128)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: saving ? null : () async {
                          setModalState(() => saving = true);
                          try {
                            final newUsername = usernameCtrl.text.trim().toLowerCase();
                            final oldUsername = userData?['username'] ?? '';

                            if (newUsername != oldUsername) {
                              // Check policy: 7 days, 2 changes
                              final lastChanges = List<Timestamp>.from(userData?['usernameChangeHistory'] ?? []);
                              final now = Timestamp.now();
                              final weekAgo = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7)));

                              final changesThisWeek = lastChanges.where((t) => t.compareTo(weekAgo) > 0).toList();

                              if (changesThisWeek.length >= 2) {
                                if (context.mounted) ModernToast.info(context, 'Sınır Uyarısı', 'Kullanıcı adı değiştirme sınırına ulaştınız (7 günde 2 defa).');
                                setModalState(() => saving = false);
                                return;
                              }

                              // Check if username taken
                              final takenSnap = await FirebaseFirestore.instance.collection('users').where('username', isEqualTo: newUsername).get();
                              if (takenSnap.docs.isNotEmpty) {
                                if (context.mounted) ModernToast.error(context, 'Hata', 'Bu kullanıcı adı zaten alınmış.');
                                setModalState(() => saving = false);
                                return;
                              }

                              lastChanges.add(now);
                              await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
                                'displayName': nameCtrl.text.trim(),
                                'bio': bioCtrl.text.trim(),
                                'username': newUsername,
                                'usernameChangeHistory': lastChanges,
                              });
                            } else {
                              await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
                                'displayName': nameCtrl.text.trim(),
                                'bio': bioCtrl.text.trim(),
                              });
                            }

                            await _loadProfile();
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            ModernToast.success(context, 'Başarılı', 'Profil güncellendi.');
                          } catch (e) {
                            if (!context.mounted) return;
                            ModernToast.error(context, 'Hata', e.toString());
                          } finally {
                            setModalState(() => saving = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                        ),
                        child: saving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Kaydet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              }
          );
        }
    );
  }

  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 48, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: const Text('Profili Düzenle', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showEditProfileModal();
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.bell, color: Colors.white),
                title: const Text('Bildirim Ayarları', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()));
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.shield, color: Colors.white),
                title: const Text('Gizlilik ve Güvenlik', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacySecurityScreen()));
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.share, color: Colors.white),
                title: const Text('Profilimi Paylaş', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _handleShareProfile();
                },
              ),
              const Divider(color: Colors.white12),
              ListTile(
                leading: const Icon(LucideIcons.logOut, color: Colors.redAccent),
                title: const Text('Çıkış Yap', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                onTap: () async {
                  Navigator.pop(context);
                  await FirebaseAuth.instance.signOut();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _handleShareProfile() {
    final username = userData?['username'] ?? user?.uid ?? '';
    ModernToast.info(context, 'Profil Bağlantısı', 'https://secgec.app/u/$username panoya kopyalandı! (Demo)');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          backgroundColor: Color(0xFF050505),
          body: Center(child: CircularProgressIndicator(color: Colors.blueAccent))
      );
    }

    final isAnonymous = _isCurrentUser && (user?.isAnonymous ?? true);

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        title: Text(
            '@${userData?['username'] ?? (isAnonymous ? 'misafir' : 'kullanici')}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)
        ),
        backgroundColor: const Color(0xFF050505),
        elevation: 0,
        centerTitle: false,
        actions: [
          if (_isCurrentUser)
            IconButton(
              icon: const Icon(LucideIcons.menu, color: Colors.white),
              onPressed: isAnonymous ? null : _showSettingsModal,
            )
          else ...[
            IconButton(
              icon: const Icon(LucideIcons.messageCircle, color: Colors.white),
              onPressed: () {
                if (_targetUserId != null) {
                  // Direct message logic
                  Navigator.push(context, MaterialPageRoute(builder: (_) => MessagesScreen(targetUserId: _targetUserId, targetUserName: userData?['displayName'])));
                }
              },
            ),
            IconButton(
              icon: const Icon(LucideIcons.ban, color: Colors.white70),
              onPressed: () {
                ModernToast.info(context, 'Yakında', 'Kullanıcı engelleme özelliği yakında eklenecek.');
              },
            ),
          ]
        ],
      ),
      bottomNavigationBar: null,
      body: isAnonymous
          ? _buildAnonymousView()
          : NestedScrollView(
        headerSliverBuilder: (context, _) {
          return [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Cover Photo with Gradient or Image
                      Container(
                        height: 160,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: (userData?['bannerURL'] == null || userData?['bannerURL'].toString().isEmpty == true)
                              ? const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                              : null,
                          image: (userData?['bannerURL'] != null && userData?['bannerURL'].toString().isNotEmpty == true)
                              ? DecorationImage(
                            image: NetworkImage(userData!['bannerURL'].toString()),
                            fit: BoxFit.cover,
                          )
                              : null,
                        ),
                        child: (userData?['bannerURL'] == null || userData?['bannerURL'].toString().isEmpty == true)
                            ? const Center(
                          child: Text(
                            'SeçGeç Banner',
                            style: TextStyle(
                              color: Colors.white24,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                        )
                            : null,
                      ),
                      Positioned(
                        bottom: -40,
                        left: 20,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                          child: SmartAvatar(url: userData?['photoURL'], radius: 46),
                        ),
                      ),
                      if (_isCurrentUser)
                        Positioned(
                          bottom: -35,
                          left: 85,
                          child: GestureDetector(
                            onTap: _showEditProfileModal,
                            child: const CircleAvatar(
                              radius: 14,
                              backgroundColor: Color(0xFF111111),
                              child: Icon(LucideIcons.camera, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 50),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userData?['displayName'] ?? 'Kullanıcı',
                                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '@${userData?['username'] ?? 'kullanici'}',
                                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                                ),
                              ],
                            ),
                            if (_isCurrentUser)
                              ElevatedButton(
                                onPressed: _showEditProfileModal,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                child: const Text('Düzenle', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              )
                            else
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => MessagesScreen(targetUserId: widget.userId, targetUserName: userData?['displayName'])));
                                    },
                                    icon: const Icon(LucideIcons.messageCircle, color: Colors.white),
                                    style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.08)),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _toggleFollow,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isFollowing ? Colors.white.withValues(alpha: 0.08) : const Color(0xFF8B5CF6),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    ),
                                    child: Text(_isFollowing ? 'Takiptesin' : 'Takip Et', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        if (userData?['bio'] != null && userData!['bio'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              userData?['bio'] ?? '',
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            _buildStatColumn('Anketler', _pollsCount.toString()),
                            const SizedBox(width: 24),
                            _buildStatColumn('Takipçi', _followersCount.toString(), highlight: true),
                            const SizedBox(width: 24),
                            _buildStatColumn('Takip', _followingCount.toString()),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (userData?['interests'] != null && (userData!['interests'] as List).isNotEmpty)
                              ? (userData!['interests'] as List).map((i) => _buildTagChip('#$i')).toList()
                              : [
                            _buildTagChip('#Moda'),
                            _buildTagChip('#Teknoloji'),
                            _buildTagChip('#Gündem'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.blueAccent,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  tabs: [
                    Tab(text: _isCurrentUser ? "Anketlerim" : "Anketleri"),
                    Tab(text: "Kaydedilenler"),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildMyPolls(),
            _buildEmptyState("Kaydedilmiş anketin yok", LucideIcons.bookmark),
          ],
        ),
      ),
    );
  }

  Widget _buildMyPolls() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('polls').where('creatorId', isEqualTo: _targetUserId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('Hata', style: TextStyle(color: Colors.white)));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        var polls = snapshot.data?.docs.toList() ?? [];
        polls.sort((a, b) {
          final timeA = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          final timeB = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          if (timeA == null) return 1;
          if (timeB == null) return -1;
          return timeB.compareTo(timeA);
        });

        if (polls.isEmpty) return _buildEmptyState("Henüz anket oluşturmadın", LucideIcons.barChart2);

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.8,
          ),
          itemCount: polls.length,
          itemBuilder: (context, index) {
            final pollData = polls[index].data() as Map<String, dynamic>;
            final pollId = polls[index].id;
            return GestureDetector(
              onTap: () {
                // Navigate to detail
              },
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(40),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      pollData['imageA'] ?? 'https://via.placeholder.com/300',
                      fit: BoxFit.cover,
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Colors.black87],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            pollData['title'] ?? 'İsimsiz Anket',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(LucideIcons.zap, color: Colors.yellow, size: 12),
                              const SizedBox(width: 4),
                              Text('${pollData['totalVotes'] ?? 0}', style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          Text(text, style: const TextStyle(color: Colors.white54, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildAnonymousView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.userCircle, size: 80, color: Colors.white24),
            const SizedBox(height: 24),
            const Text(
              'Misafir Hesabı',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Profilini özelleştirmek, takipçi kazanmak ve oluşturduğun anketleri takip etmek için giriş yapmalısın.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
              child: const Text('Giriş Yap / Kayıt Ol', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String count, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          count,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTagChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFF050505),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
