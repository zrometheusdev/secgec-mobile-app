import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:secgec/widgets/modern_toast.dart';

class CreatePollScreen extends StatefulWidget {
  const CreatePollScreen({super.key});

  @override
  State<CreatePollScreen> createState() => _CreatePollScreenState();
}

class _CreatePollScreenState extends State<CreatePollScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageAController = TextEditingController();
  final _imageBController = TextEditingController();

  bool _isLoading = false;
  String _category = 'Fashion';
  String _duration = 'Permanent';
  bool _useBoost = false;
  int _userBoosts = 0;

  XFile? _pickedA;
  XFile? _pickedB;
  Uint8List? _bytesA;
  Uint8List? _bytesB;

  Future<void> _pickImage(bool isA) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          if (isA) {
            _pickedA = picked;
            _bytesA = bytes;
            _imageAController.text = picked.name;
          } else {
            _pickedB = picked;
            _bytesB = bytes;
            _imageBController.text = picked.name;
          }
        });
      }
    } catch (e) {
      if (mounted) ModernToast.error(context, 'Hata', 'Fotoğraf seçilemedi: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserBoosts();
  }

  Future<void> _loadUserBoosts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final docSnap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (docSnap.exists) {
        setState(() {
          _userBoosts = docSnap.data()?['boostsCount'] ?? 0;
        });
      }
    }
  }

  Future<void> _createPoll() async {
    final title = _titleController.text.trim();
    String imageA = _imageAController.text.trim();
    String imageB = _imageBController.text.trim();

    if (title.isEmpty || imageA.isEmpty || imageB.isEmpty) {
      ModernToast.error(context, 'Uyarı', 'Lütfen başlık ve her iki medya linkini de doldurun');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (_bytesA != null) {
          imageA = 'data:image/jpeg;base64,${base64Encode(_bytesA!)}';
        }
        if (_bytesB != null) {
          imageB = 'data:image/jpeg;base64,${base64Encode(_bytesB!)}';
        }

        final pollRef = FirebaseFirestore.instance.collection('polls').doc();
        final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

        DateTime? expiresAt;
        if (_duration != 'Permanent') {
          final now = DateTime.now();
          if (_duration == '24h') expiresAt = now.add(const Duration(hours: 24));
          if (_duration == '3d') expiresAt = now.add(const Duration(days: 3));
          if (_duration == '1w') expiresAt = now.add(const Duration(days: 7));
        }

        final batch = FirebaseFirestore.instance.batch();

        print("[DEBUG] Batch verileri hazırlanıyor...");
        final pollData = {
          'creatorId': user.uid,
          'creatorName': user.displayName ?? 'Anonim',
          'creatorPhoto': user.photoURL ?? '',
          'title': title,
          'description': _descriptionController.text.trim(),
          'imageA': imageA,
          'imageB': imageB,
          'votesA': 0,
          'votesB': 0,
          'totalVotes': 0,
          'category': _category,
          'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
          'isBoosted': _useBoost,
          'createdAt': FieldValue.serverTimestamp(),
          'tags': [],
        };

        batch.set(pollRef, pollData);

        if (_useBoost && _userBoosts > 0) {
          batch.update(userRef, {
            'boostsCount': FieldValue.increment(-1),
            'credits': FieldValue.increment(-1)
          });
        }

        print("[DEBUG] Batch commit denemesi yapılıyor...");

        try {
          await batch.commit().timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print("[DEBUG] Batch commit ZAMANAŞIMI!");
              throw TimeoutException("Firestore sunucusuna 30 saniye içinde ulaşılamadı. Lütfen Firebase konsolundan Cloud Firestore veritabanının ve kurallarının (Rules) Firestore için doğru yapılandırıldığından emin olun.");
            },
          );
          print("[DEBUG] Batch commit BAŞARILI!");
        } catch (e) {
          print("[DEBUG] Batch commit HATASI: $e");
          rethrow;
        }

        if (mounted) {
          _titleController.clear();
          _descriptionController.clear();
          _imageAController.clear();
          _imageBController.clear();
          setState(() {
            _pickedA = null;
            _pickedB = null;
            _bytesA = null;
            _bytesB = null;
            _useBoost = false;
          });
          ModernToast.success(context, 'Başarılı', 'Anket başarıyla paylaşıldı!');
        }
      }
    } on FirebaseException catch (e) {
      if (mounted) ModernToast.error(context, 'Firebase Hatası', '${e.code} - ${e.message}');
    } catch (e) {
      if (mounted) ModernToast.error(context, 'Hata', e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        title: const Text('Yeni SeçGeç', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('GÜNLÜK HAK: 2/2', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Media inputs
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickImage(true),
                    child: Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: const Color(0xFF111111),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _bytesA != null
                          ? Image.memory(_bytesA!, fit: BoxFit.cover)
                          : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(LucideIcons.imagePlus, color: Colors.grey, size: 32),
                          const SizedBox(height: 8),
                          const Text('Medya A', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickImage(false),
                    child: Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: const Color(0xFF111111),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _bytesB != null
                          ? Image.memory(_bytesB!, fit: BoxFit.cover)
                          : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(LucideIcons.imagePlus, color: Colors.grey, size: 32),
                          const SizedBox(height: 8),
                          const Text('Medya B', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Title
            const Text('SORU BAŞLIĞI', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Hangi ayakkabı daha iyi?',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            const Text('AÇIKLAMA (OPSİYONEL)', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: TextField(
                controller: _descriptionController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Bu hafta sonu kombini için yardımlarınızı bekliyorum...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Category
            const Text('KATEGORİ', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Fashion', 'Tech', 'Home', 'Sport', 'Game', 'Art', 'Food'].map((cat) {
                  final isSel = _category == cat;
                  final label = cat == 'Fashion' ? 'Moda' : cat == 'Tech' ? 'Teknoloji' : cat == 'Home' ? 'Ev' : cat == 'Sport' ? 'Spor' : cat == 'Game' ? 'Oyun' : cat == 'Art' ? 'Sanat' : 'Yemek';
                  return GestureDetector(
                    onTap: () => setState(() => _category = cat),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? Colors.blue : const Color(0xFF111111),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSel ? Colors.blue : Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Text(label, style: TextStyle(color: isSel ? Colors.white : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Duration
            const Text('ANKET SÜRESİ', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Permanent', '24h', '3d', '1w'].map((dur) {
                  final isSel = _duration == dur;
                  final label = dur == 'Permanent' ? 'Süresiz' : dur == '24h' ? '24 Saat' : dur == '3d' ? '3 Gün' : '1 Hafta';
                  return GestureDetector(
                    onTap: () => setState(() => _duration = dur),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? Colors.purple : const Color(0xFF111111),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSel ? Colors.purple : Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Text(label, style: TextStyle(color: isSel ? Colors.white : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Boost
            GestureDetector(
              onTap: () {
                if (_userBoosts > 0) setState(() => _useBoost = !_useBoost);
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: _useBoost ? Colors.orange : const Color(0xFF111111),
                        borderRadius: BorderRadius.circular(12),
                        border: _useBoost ? null : Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                      ),
                      alignment: Alignment.center,
                      child: Icon(LucideIcons.zap, color: _useBoost ? Colors.white : Colors.orange, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Öne Çıkar (Boost)', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('$_userBoosts Boost Hakkın Var', style: TextStyle(color: Colors.orange.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ],
                      ),
                    ),
                    if (_userBoosts > 0)
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _useBoost ? Colors.orange : Colors.orange.withValues(alpha: 0.3), width: 2),
                          color: _useBoost ? Colors.orange : Colors.transparent,
                        ),
                        alignment: Alignment.center,
                        child: _useBoost ? Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)) : null,
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('SATIN AL', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                      )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _createPoll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                icon: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(LucideIcons.send, size: 20),
                label: Text(_isLoading ? '' : 'Paylaş', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
              ),
              child: Text(
                'İpucu: Yüksek çözünürlüklü ve benzer ışıklandırmaya sahip görseller daha adil sonuçlar verir.',
                style: TextStyle(color: Colors.blue.withValues(alpha: 0.8), fontSize: 10, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
