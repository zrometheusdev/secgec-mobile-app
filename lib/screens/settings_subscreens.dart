import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:secgec/providers/theme_provider.dart';
import 'package:secgec/widgets/modern_toast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _isUploadingBanner = false;

  Future<void> _changeBanner() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (image != null) {
      setState(() => _isUploadingBanner = true);
      try {
        final storageRef = FirebaseStorage.instance.ref().child('user_banners').child('${user.uid}.jpg');
        await storageRef.putFile(File(image.path));
        final downloadUrl = await storageRef.getDownloadURL();

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'bannerURL': downloadUrl,
        }, SetOptions(merge: true));

        if (mounted) {
          ModernToast.success(context, 'Başarılı', 'Kapak fotoğrafı güncellendi.');
        }
      } catch (e) {
        if (mounted) {
          ModernToast.error(context, 'Hata', 'Yükleme başarısız: $e');
        }
      } finally {
        if (mounted) setState(() => _isUploadingBanner = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text('Ayarlar', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        backgroundColor: isDark ? Colors.black : Colors.white,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Profil Görünümü', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            title: Text('Kapak Fotoğrafını Değiştir', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            subtitle: Text('Profilindeki arka plan görselini güncelle', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
            trailing: _isUploadingBanner ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.image, color: Colors.grey),
            onTap: _isUploadingBanner ? null : _changeBanner,
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Görünüm', style: TextStyle(color: isDark ? Colors.blue : Colors.blue, fontWeight: FontWeight.bold)),
          ),
          SwitchListTile(
            title: Text('Karanlık Mod', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            value: isDark,
            onChanged: (val) {
              themeProvider.toggleTheme(val);
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Bildirimler', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
          SwitchListTile(title: Text('Anlık Bildirimler', style: TextStyle(color: isDark ? Colors.white : Colors.black)), value: true, onChanged: (_) {}),
          SwitchListTile(title: Text('Yeni Takipçiler', style: TextStyle(color: isDark ? Colors.white : Colors.black)), value: true, onChanged: (_) {}),
          SwitchListTile(title: Text('Oylar ve Yorumlar', style: TextStyle(color: isDark ? Colors.white : Colors.black)), value: true, onChanged: (_) {}),
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
  void _showChangePasswordDialog() {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Şifre Değiştir'),
        content: Text('$email adresine şifre sıfırlama bağlantısı gönderilsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          TextButton(
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
            child: const Text('Gönder'),
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
        backgroundColor: isDark ? Colors.black : Colors.white,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text('Hesabı Gizli Yap', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            subtitle: Text('Sadece takipçilerin anketlerini görebilir.', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
            value: false,
            onChanged: (_) {},
          ),
          const Divider(),
          ListTile(
            title: Text('Şifre Değiştir', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: _showChangePasswordDialog,
          ),
          ListTile(
            title: Text('Engellenen Kullanıcılar', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
