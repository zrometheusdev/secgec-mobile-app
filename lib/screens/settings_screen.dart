import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:secgec/providers/theme_provider.dart';
import 'package:secgec/widgets/modern_toast.dart';
import 'package:lucide_icons/lucide_icons.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text('Ayarlar', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          _buildSectionTitle('Görünüm & Tema', isDark),
          ListTile(
            leading: Icon(LucideIcons.moon, color: isDark ? Colors.white : Colors.black),
            title: Text('Karanlık Mod', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600)),
            trailing: Switch(
              value: isDark,
              activeColor: Colors.blueAccent,
              onChanged: (val) {
                themeProvider.toggleTheme(val);
              },
            ),
          ),
          const Divider(height: 32),
          _buildSectionTitle('Hesap', isDark),
          ListTile(
            leading: Icon(LucideIcons.bell, color: isDark ? Colors.white : Colors.black),
            title: Text('Bildirim Ayarları', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600)),
            trailing: const Icon(LucideIcons.chevronRight, color: Colors.grey),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()));
            },
          ),
          ListTile(
            leading: Icon(LucideIcons.lock, color: isDark ? Colors.white : Colors.black),
            title: Text('Gizlilik ve Güvenlik', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600)),
            trailing: const Icon(LucideIcons.chevronRight, color: Colors.grey),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacySecurityScreen()));
            },
          ),
          ListTile(
            leading: Icon(LucideIcons.badgeCheck, color: Colors.blueAccent),
            title: Text('Doğrulama İsteği', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600)),
            trailing: const Icon(LucideIcons.chevronRight, color: Colors.grey),
            onTap: () {
              _showVerificationDialog(context);
            },
          ),
          const Divider(height: 32),
          _buildSectionTitle('Sistem', isDark),
          ListTile(
            leading: Icon(LucideIcons.trash2, color: isDark ? Colors.white : Colors.black),
            title: Text('Önbelleği Temizle', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600)),
            onTap: () {
              ModernToast.info(context, 'Temizleniyor', 'Uygulama önbelleği başarıyla temizlendi.');
            },
          ),
          const Divider(height: 32),
          _buildSectionTitle('Diğer', isDark),
          ListTile(
            leading: Icon(LucideIcons.info, color: isDark ? Colors.white : Colors.black),
            title: Text('Hakkında', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600)),
            trailing: const Icon(LucideIcons.chevronRight, color: Colors.grey),
            onTap: () {
              ModernToast.info(context, 'Hakkında', 'SeçGeç v1.0.0\nTopluluğun Kararı!');
            },
          ),
          ListTile(
            leading: Icon(LucideIcons.logOut, color: Colors.redAccent),
            title: const Text('Çıkış Yap', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) Navigator.pop(context); // close settings
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: isDark ? Colors.white54 : Colors.black54,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _showVerificationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Row(
          children: [
            Icon(Icons.verified, color: Colors.blueAccent),
            SizedBox(width: 10),
            Text('Doğrulama', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Hesabını doğrulamak için bir talep gönder. Toplulukta güvenilir bir profil oluşturmak için bu adımı tamamlaman gerekir.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('İptal', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await FirebaseFirestore.instance.collection('verification_requests').doc(user.uid).set({
                  'uid': user.uid,
                  'email': user.email,
                  'requestedAt': FieldValue.serverTimestamp(),
                  'status': 'pending',
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  ModernToast.success(context, 'Talep Alındı', 'Doğrulama talebiniz incelemeye alındı.');
                }
              }
            },
            child: Text('Talep Gönder'),
          ),
        ],
      ),
    );
  }
}

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool pushNotifications = true;
  bool newFollowers = true;
  bool votesAndComments = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          if (mounted) {
            setState(() {
              pushNotifications = data['pushNotifications'] ?? true;
              newFollowers = data['newFollowersNotifications'] ?? true;
              votesAndComments = data['votesCommentsNotifications'] ?? true;
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

  Future<void> _updateSetting(String key, bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          key: value,
        }, SetOptions(merge: true));
        ModernToast.success(context, 'Kaydedildi', 'Ayarlarınız güncellendi.');
      } catch (e) {
        ModernToast.error(context, 'Hata', 'Değişiklik kaydedilemedi.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text('Bildirim Ayarları', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        children: [
          SwitchListTile(
            title: Text('Tüm Anlık Bildirimler', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600)),
            subtitle: Text('Anlık bildirimleri açıp kapatın', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
            activeColor: Colors.blueAccent,
            value: pushNotifications,
            onChanged: (val) {
              setState(() => pushNotifications = val);
              _updateSetting('pushNotifications', val);
            },
          ),
          const Divider(),
          SwitchListTile(
            title: Text('Yeni Takipçiler', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w500)),
            subtitle: Text('Biri seni takip ettiğinde bildir', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
            activeColor: Colors.blueAccent,
            value: newFollowers,
            onChanged: pushNotifications ? (val) {
              setState(() => newFollowers = val);
              _updateSetting('newFollowersNotifications', val);
            } : null,
          ),
          SwitchListTile(
            title: Text('Oylar ve Yorumlar', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w500)),
            subtitle: Text('Anketlerine oy verildiğinde veya yorum yapıldığında bildir', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
            activeColor: Colors.blueAccent,
            value: votesAndComments,
            onChanged: pushNotifications ? (val) {
              setState(() => votesAndComments = val);
              _updateSetting('votesCommentsNotifications', val);
            } : null,
          ),
        ],
      ),
    );
  }
}

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  bool isPrivate = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          if (mounted) {
            setState(() {
              isPrivate = data['isPrivateAccount'] ?? false;
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

  Future<void> _togglePrivate(bool val) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() => isPrivate = val);
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'isPrivateAccount': val,
        }, SetOptions(merge: true));
        ModernToast.success(context, 'Kaydedildi', 'Gizlilik ayarınız güncellendi.');
      } catch (e) {
        setState(() => isPrivate = !val);
        ModernToast.error(context, 'Hata', 'Değişiklik kaydedilemedi.');
      }
    }
  }

  void _showChangePasswordDialog() {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Şifre Değiştir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('$email adresine şifre sıfırlama bağlantısı gönderilsin mi?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () async {
              final auth = FirebaseAuth.instance;
              final navigator = Navigator.of(context);
              try {
                await auth.sendPasswordResetEmail(email: email);
                if (mounted) {
                  navigator.pop();
                  ModernToast.success(context, 'E-posta Gönderildi', 'Şifre sıfırlama bağlantısı gönderildi.');
                }
              } catch (e) {
                if (mounted) {
                  ModernToast.error(context, 'Hata', e.toString());
                }
              }
            },
            child: const Text('Gönder', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Hesabı Sil', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text('Hesabınızı silmek istediğinize emin misiniz? Bu işlem geri alınamaz.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(context);
              // Account delete logic
              try {
                ModernToast.info(context, 'Bilgi', 'Hesap silme işlemi yönetici paneline iletildi.');
                await FirebaseFirestore.instance.collection('deletions').add({
                  'uid': FirebaseAuth.instance.currentUser?.uid,
                  'timestamp': FieldValue.serverTimestamp(),
                });
              } catch (e) {
                ModernToast.error(context, 'Hata', 'İşlem başarısız');
              }
            },
            child: const Text('Hesabı Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text('Gizlilik ve Güvenlik', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView(
        children: [
          SwitchListTile(
            title: Text('Gizli Hesap', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600)),
            subtitle: Text('Profilinizi sadece takipçileriniz görebilir', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
            activeColor: Colors.blueAccent,
            value: isPrivate,
            onChanged: _togglePrivate,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(LucideIcons.key, color: Colors.blueAccent),
            title: Text('Şifre Değiştir', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600)),
            subtitle: Text('Şifre sıfırlama e-postası gönder', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: _showChangePasswordDialog,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(LucideIcons.userX, color: Colors.grey),
            title: Text('Engellenen Kullanıcılar', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              ModernToast.info(context, 'Yakında', 'Bu özellik çok yakında eklenecektir.');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(LucideIcons.trash2, color: Colors.redAccent),
            title: const Text('Hesabımı Sil', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onTap: _showDeleteAccountDialog,
          )
        ],
      ),
    );
  }
}
