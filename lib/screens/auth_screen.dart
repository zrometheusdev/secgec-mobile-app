import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:secgec/widgets/modern_toast.dart';
import 'dart:ui';
import 'package:secgec/widgets/particle_background.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  String _activeTab = 'login'; // 'login' | 'register'
  int _step = 1;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String _heardFrom = '';
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    _nameController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    if (mounted) {
      ModernToast.error(context, 'Hata', msg);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() { _isLoading = true; });
    try {
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        final userCredential = await _auth.signInWithPopup(googleProvider);
        final user = userCredential.user;

        if (user != null) {
          final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
          final docSnap = await docRef.get();

          if (!docSnap.exists) {
            await docRef.set({
              'uid': user.uid,
              'displayName': user.displayName ?? 'Yeni Kullanıcı',
              'username': 'u_${user.uid.substring(0, 8)}'.toLowerCase(),
              'photoURL': user.photoURL ?? '',
              'bio': 'SeçGeç dünyasına hoş geldin!',
              'followersCount': 0,
              'followingCount': 0,
              'totalVotes': 0,
              'isPro': false,
              'credits': 5,
              'interests': [],
              'onboardingCompleted': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }
      } else {
        _showError('Google girişi şu an sadece Web sürümünde aktiftir. Lütfen Chrome vb. bir tarayıcıda çalıştırın.');
      }
    } catch (e) {
      _showError('Google girişi sırasında bir hata oluştu: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmailLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('Lütfen e-posta ve şifrenizi girin.');
      return;
    }
    setState(() { _isLoading = true; });
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _showError('Hatalı e-posta veya şifre girdiniz.');
      } else if (e.code == 'too-many-requests') {
        _showError('Çok fazla başarısız deneme uyguladınız. Lütfen daha sonra tekrar deneyin.');
      } else {
        _showError('Giriş yapılırken bir sorun oluştu.');
      }
    } catch (e) {
      _showError('Hata: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRegister() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final username = _usernameController.text.trim();
    final name = _nameController.text.trim();
    final dob = _dobController.text.trim();

    if (name.isEmpty || username.isEmpty || dob.isEmpty || _heardFrom.isEmpty || email.isEmpty || password.isEmpty) {
      _showError('Lütfen tüm alanları doldurun.');
      return;
    }

    if (password != confirmPassword) {
      _showError('Şifreler eşleşmiyor.');
      return;
    }

    if (!_acceptedTerms || !_acceptedPrivacy) {
      _showError('Devam etmek için Gizlilik Politikası ve Hizmet Şartlarını onaylamalısınız.');
      return;
    }

    final usernameRegex = RegExp(r'^[a-zA-Z][a-zA-Z0-9._]*$');
    if (!usernameRegex.hasMatch(username)) {
      _showError('Kullanıcı adı harf ile başlamalıdır ve sadece harf, rakam, nokta (.) ve alt çizgi (_) içerebilir.');
      return;
    }

    setState(() { _isLoading = true; });
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user;
      if (user != null) {
        await user.updateDisplayName(name);
        final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        await docRef.set({
          'uid': user.uid,
          'displayName': name,
          'username': username.toLowerCase(),
          'photoURL': '',
          'bio': 'SeçGeç dünyasına hoş geldin!',
          'dob': dob,
          'heardFrom': _heardFrom,
          'followersCount': 0,
          'followingCount': 0,
          'totalVotes': 0,
          'isPro': false,
          'credits': 5,
          'interests': [],
          'onboardingCompleted': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _showError('Bu e-posta adresi zaten kullanımda.');
      } else if (e.code == 'weak-password') {
        _showError('Şifre en az 6 karakter olmalıdır.');
      } else {
        _showError(e.message ?? 'Kayıt sırasında bir hata oluştu.');
      }
    } catch (e) {
      _showError('Hata: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _nextStep() {
    if (_step == 1) {
      final username = _usernameController.text.trim();
      final name = _nameController.text.trim();
      final dob = _dobController.text.trim();
      if (username.isEmpty || name.isEmpty || dob.isEmpty) {
        _showError('Lütfen kullanıcı adı, ad soyad ve doğum tarihinizi girin.');
        return;
      }
      final usernameRegex = RegExp(r'^[a-zA-Z][a-zA-Z0-9._]*$');
      if (!usernameRegex.hasMatch(username)) {
        _showError('Kullanıcı adı harf ile başlamalıdır ve sadece harf, rakam, nokta (.) ve alt çizgi (_) içerebilir.');
        return;
      }
    } else if (_step == 2) {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final confirmPassword = _confirmPasswordController.text;
      if (email.isEmpty || password.length < 6) {
        _showError('Geçerli bir e-posta ve en az 6 karakterli şifre girin.');
        return;
      }
      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
      if (!emailRegex.hasMatch(email)) {
        _showError('Lütfen geçerli bir e-posta adresi girin.');
        return;
      }
      if (password != confirmPassword) {
        _showError('Şifreler eşleşmiyor.');
        return;
      }
    }
    setState(() => _step++);
  }

  void _prevStep() {
    setState(() {
      _step--;
    });
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    TextInputType? keyboardType,
    Function(String)? onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.4), size: 20),
          suffixIcon: isPassword ? IconButton(
            icon: Icon(obscureText ? LucideIcons.eyeOff : LucideIcons.eye, color: Colors.white.withValues(alpha: 0.4), size: 20),
            onPressed: onToggleVisibility,
          ) : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  void _showForgotPasswordModal() {
    final emailController = TextEditingController(text: _emailController.text);
    bool isSending = false;

    showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF111111),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        isScrollControlled: true,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setModalState) {
                return Padding(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                      left: 24, right: 24, top: 24
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Şifremi Unuttum', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Kayıtlı e-posta adresinizi girin. Size bir sıfırlama bağlantısı göndereceğiz.', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14)),
                      const SizedBox(height: 24),
                      _buildTextField(
                        controller: emailController,
                        hint: 'E-posta Adresi',
                        icon: LucideIcons.mail,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 24),
                      _buildPrimaryButton(
                        onPressed: () async {
                          if (emailController.text.isEmpty) {
                            ModernToast.error(context, 'Hata', 'Lütfen e-posta adresinizi girin.');
                            return;
                          }
                          setModalState(() => isSending = true);
                          try {
                            await FirebaseAuth.instance.sendPasswordResetEmail(email: emailController.text.trim());
                            if (context.mounted) {
                              Navigator.pop(context);
                              ModernToast.success(context, 'Başarılı', 'Şifre sıfırlama bağlantısı gönderildi.');
                            }
                          } catch (e) {
                            if (context.mounted) ModernToast.error(context, 'Hata', 'Gönderilemedi. E-postanızı kontrol edin.');
                          } finally {
                            if (context.mounted) setModalState(() => isSending = false);
                          }
                        },
                        text: 'Bağlantı Gönder',
                        icon: LucideIcons.send,
                        isLoading: isSending,
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                );
              }
          );
        }
    );
  }

  Widget _buildPrimaryButton({
    required VoidCallback? onPressed,
    required String text,
    required IconData icon,
    bool isLoading = false,
  }) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: EdgeInsets.zero,
        ),
        child: isLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: -200,
            left: -200,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withValues(alpha: 0.1),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                child: Container(),
              ),
            ),
          ),
          Positioned(
            bottom: -200,
            right: -200,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purple.withValues(alpha: 0.1),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                child: Container(),
              ),
            ),
          ),

          const ParticleBackground(),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Transform.rotate(
                                angle: 0.05,
                                child: Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Colors.blue, Colors.purple],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withValues(alpha: 0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(LucideIcons.checkCircle, color: Colors.white, size: 32),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TweenAnimationBuilder(
                            tween: Tween<double>(begin: 0, end: 1),
                            duration: const Duration(seconds: 1),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, 20 * (1 - value)),
                                  child: child,
                                ),
                              );
                            },
                            child: const Text(
                              'SeçGeç',
                              style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1),
                            ),
                          ),
                          const SizedBox(height: 4),
                          TweenAnimationBuilder(
                            tween: Tween<double>(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 1500),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, 20 * (1 - value)),
                                  child: child,
                                ),
                              );
                            },
                            child: Text(
                              'Karar veremediğin her an yanındayız.',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Card container
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111111).withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 50,
                                  offset: const Offset(0, 25),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Tab Switcher
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => setState(() { _activeTab = 'login'; }),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            decoration: BoxDecoration(
                                              color: _activeTab == 'login' ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text('Giriş Yap', style: TextStyle(color: _activeTab == 'login' ? Colors.white : Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.bold, fontSize: 13)),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => setState(() { _activeTab = 'register'; }),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            decoration: BoxDecoration(
                                              color: _activeTab == 'register' ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text('Kayıt Ol', style: TextStyle(color: _activeTab == 'register' ? Colors.white : Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.bold, fontSize: 13)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),

                                if (_activeTab == 'login') ...[
                                  _buildTextField(controller: _emailController, hint: 'E-posta Adresi', icon: LucideIcons.mail, keyboardType: TextInputType.emailAddress),
                                  _buildTextField(
                                      controller: _passwordController, hint: 'Şifre', icon: LucideIcons.lock,
                                      isPassword: true, obscureText: _obscurePassword,
                                      onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword)
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _showForgotPasswordModal,
                                      child: Text('Şifremi Unuttum', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildPrimaryButton(
                                    onPressed: _handleEmailLogin,
                                    text: 'Giriş Yap',
                                    icon: LucideIcons.logIn,
                                    isLoading: _isLoading,
                                  ),
                                ] else ...[
                                  // Progress indicator
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(height: 2, color: Colors.white.withValues(alpha: 0.05)),
                                        Row(
                                          children: [
                                            Expanded(child: Container(height: 2, color: _step > 1 ? Colors.purple : Colors.transparent)),
                                            Expanded(child: Container(height: 2, color: _step > 2 ? Colors.purple : Colors.transparent)),
                                          ],
                                        ),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [1, 2, 3].map((s) => Container(
                                            width: 24, height: 24,
                                            decoration: BoxDecoration(
                                              color: _step >= s ? const Color(0xFFa855f7) : const Color(0xFF111111),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: _step >= s ? const Color(0xFFa855f7) : Colors.white.withValues(alpha: 0.1), width: 1.5),
                                            ),
                                            alignment: Alignment.center,
                                            child: _step > s
                                                ? const Icon(LucideIcons.check, size: 12, color: Colors.white)
                                                : Text('$s', style: TextStyle(color: _step >= s ? Colors.white : Colors.white.withValues(alpha: 0.5), fontSize: 10, fontWeight: FontWeight.bold)),
                                          )).toList(),
                                        )
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  if (_step == 1) ...[
                                    _buildTextField(controller: _usernameController, hint: 'Kullanıcı Adı', icon: LucideIcons.user, onChanged: (v) => _usernameController.text = v.replaceAll(RegExp(r'[^a-zA-Z0-9._]'), '')),
                                    _buildTextField(controller: _nameController, hint: 'Ad Soyad', icon: LucideIcons.user),
                                    GestureDetector(
                                      onTap: () async {
                                        final DateTime? picked = await showDatePicker(
                                          context: context,
                                          initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
                                          firstDate: DateTime(1900),
                                          lastDate: DateTime.now(),
                                          builder: (context, child) {
                                            return Theme(
                                              data: Theme.of(context).copyWith(
                                                colorScheme: const ColorScheme.dark(
                                                  primary: Colors.purple,
                                                  onPrimary: Colors.white,
                                                  surface: Color(0xFF1A1A1A),
                                                  onSurface: Colors.white,
                                                ),
                                                dialogBackgroundColor: const Color(0xFF111111),
                                              ),
                                              child: child!,
                                            );
                                          },
                                        );
                                        if (picked != null) {
                                          setState(() {
                                            _dobController.text = "${picked.day.toString().padLeft(2, '0')}.${picked.month.toString().padLeft(2, '0')}.${picked.year}";
                                          });
                                        }
                                      },
                                      child: AbsorbPointer(
                                        child: _buildTextField(
                                          controller: _dobController,
                                          hint: 'Doğum Tarihi Seçin',
                                          icon: LucideIcons.calendar,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildPrimaryButton(
                                      onPressed: _nextStep,
                                      text: 'İleri',
                                      icon: LucideIcons.arrowRight,
                                    ),
                                  ] else if (_step == 2) ...[
                                    _buildTextField(controller: _emailController, hint: 'E-posta Adresi', icon: LucideIcons.mail, keyboardType: TextInputType.emailAddress),
                                    _buildTextField(
                                        controller: _passwordController, hint: 'Şifre (En az 6 karakter)', icon: LucideIcons.lock,
                                        isPassword: true, obscureText: _obscurePassword,
                                        onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword)
                                    ),
                                    _buildTextField(
                                        controller: _confirmPasswordController, hint: 'Şifre (Tekrar)', icon: LucideIcons.lock,
                                        isPassword: true, obscureText: _obscureConfirmPassword,
                                        onToggleVisibility: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword)
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 50, height: 50,
                                          child: ElevatedButton(
                                            onPressed: _prevStep,
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.1), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: EdgeInsets.zero),
                                            child: const Icon(LucideIcons.arrowLeft, size: 20),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _buildPrimaryButton(
                                            onPressed: _nextStep,
                                            text: 'İleri',
                                            icon: LucideIcons.arrowRight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else if (_step == 3) ...[
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.5),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _heardFrom.isEmpty ? null : _heardFrom,
                                          hint: const Text('Bizi Nereden Duydunuz?', style: TextStyle(color: Colors.grey, fontSize: 14)),
                                          isExpanded: true,
                                          dropdownColor: const Color(0xFF111111),
                                          style: const TextStyle(color: Colors.white, fontSize: 14),
                                          icon: const Icon(LucideIcons.chevronDown, color: Colors.grey, size: 20),
                                          items: const [
                                            DropdownMenuItem(value: 'Instagram', child: Text('Instagram')),
                                            DropdownMenuItem(value: 'Twitter / X', child: Text('Twitter / X')),
                                            DropdownMenuItem(value: 'TikTok', child: Text('TikTok')),
                                            DropdownMenuItem(value: 'Arkadaş Tavsiyesi', child: Text('Arkadaş Tavsiyesi')),
                                            DropdownMenuItem(value: 'Arama Motoru', child: Text('Arama Motoru (Google vb.)')),
                                            DropdownMenuItem(value: 'Diğer', child: Text('Diğer')),
                                          ],
                                          onChanged: (v) => setState(() => _heardFrom = v ?? ''),
                                        ),
                                      ),
                                    ),
                                    CheckboxListTile(
                                      value: _acceptedTerms,
                                      onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                                      title: const Text('Hizmet Şartlarını okudum ve kabul ediyorum.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                      activeColor: Colors.purple,
                                      contentPadding: EdgeInsets.zero,
                                      controlAffinity: ListTileControlAffinity.leading,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    CheckboxListTile(
                                      value: _acceptedPrivacy,
                                      onChanged: (v) => setState(() => _acceptedPrivacy = v ?? false),
                                      title: const Text('Gizlilik Politikasını okudum, kişisel verilerimin işlenmesine onay veriyorum.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                      activeColor: Colors.purple,
                                      contentPadding: EdgeInsets.zero,
                                      controlAffinity: ListTileControlAffinity.leading,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 50, height: 50,
                                          child: ElevatedButton(
                                            onPressed: _isLoading ? null : _prevStep,
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.1), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: EdgeInsets.zero),
                                            child: const Icon(LucideIcons.arrowLeft, size: 20),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _buildPrimaryButton(
                                            onPressed: _handleRegister,
                                            text: 'Aramıza Katıl',
                                            icon: LucideIcons.userPlus,
                                            isLoading: _isLoading,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],

                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                                    const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('VEYA', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1))),
                                    Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: OutlinedButton.icon(
                                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      foregroundColor: Colors.white,
                                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                                    ),
                                    icon: const Icon(LucideIcons.chrome, size: 18), // fallback icon for google
                                    label: Text('Google ile ${_activeTab == 'login' ? 'Giriş Yap' : 'Kayıt Ol'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: OutlinedButton.icon(
                                    onPressed: _isLoading ? null : () => ModernToast.info(context, 'Yakında', 'Apple ile giriş yakında aktif olacak.'),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      foregroundColor: Colors.white,
                                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                                    ),
                                    icon: const Icon(LucideIcons.apple, size: 18),
                                    label: Text('Apple ile ${_activeTab == 'login' ? 'Giriş Yap' : 'Kayıt Ol'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: OutlinedButton.icon(
                                    onPressed: _isLoading ? null : () => ModernToast.info(context, 'Yakında', 'X (Twitter) ile giriş yakında aktif olacak.'),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      foregroundColor: Colors.white,
                                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                                    ),
                                    icon: const Icon(LucideIcons.twitter, size: 18),
                                    label: Text('X ile ${_activeTab == 'login' ? 'Giriş Yap' : 'Kayıt Ol'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'Lütfen e-posta/şifre ile giriş sağlayabilmek için Firebase konsolundan Email/Password sağlayıcısını aktif ettiğinizden emin olun.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
