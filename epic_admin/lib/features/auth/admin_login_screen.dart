import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:epic_admin/core/services/auth_service.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleEmailPasswordSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userCredential = await _authService.signInWithEmailPassword(
        _emailCtrl.text.trim(),
        _passwordCtrl.text.trim(),
      );
      final user = userCredential.user;

      if (user == null) {
        throw Exception("Failed to retrieve user info.");
      }

      final isAdmin = await _authService.validateAdminRole(user.uid);

      if (!mounted) return;

      if (isAdmin) {
        context.go('/');
      } else {
        await _authService.signOut();
        setState(() {
          _errorMessage = "Akses Ditolak: Akun Anda tidak terdaftar sebagai administrator aktif.";
        });
        _showErrorSnackBar(_errorMessage!);
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint("Login error: $e");
      
      String errorMsg = e.toString().replaceAll('Exception:', '');
      if (errorMsg.contains('invalid-credential') || errorMsg.contains('wrong-password') || errorMsg.contains('user-not-found')) {
        errorMsg = "Email atau password salah.";
      } else if (errorMsg.contains('invalid-email')) {
        errorMsg = "Format email tidak valid.";
      }
      
      setState(() {
        _errorMessage = "Gagal masuk: $errorMsg";
      });
      _showErrorSnackBar(_errorMessage!);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Sign in with Google Web OAuth
      final userCredential = await _authService.signInWithGoogleWeb();
      final user = userCredential.user;

      if (user == null) {
        throw Exception("Failed to retrieve user information from Google.");
      }

      // 2. Validate role against /admins/{uid} collection
      final isAdmin = await _authService.validateAdminRole(user.uid);

      if (!mounted) return;

      if (isAdmin) {
        // Successful Admin login
        context.go('/');
      } else {
        // Unauthorized user (not registered as active admin)
        await _authService.signOut();
        setState(() {
          _errorMessage = "Akses Ditolak: Akun Anda tidak terdaftar sebagai administrator aktif.";
        });
        _showErrorSnackBar(_errorMessage!);
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint("Login error: $e");
      
      setState(() {
        _errorMessage = "Gagal melakukan masuk Google: ${e.toString().replaceAll('Exception:', '')}";
      });
      _showErrorSnackBar(_errorMessage!);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: AdminColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;

    return Scaffold(
      backgroundColor: AdminColors.background,
      body: Row(
        children: [
          // Left Decorative Side Pane (Visible only on desktop)
          if (isDesktop)
            Expanded(
              flex: 4,
              child: Container(
                decoration: const BoxDecoration(
                  color: AdminColors.sidebar,
                  gradient: LinearGradient(
                    colors: [
                      AdminColors.sidebar,
                      Color(0xFF1E293B),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    // Dynamic background glowing circles
                    Positioned(
                      top: -100,
                      left: -100,
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AdminColors.primary.withOpacity(0.15),
                              blurRadius: 100,
                              spreadRadius: 50,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -50,
                      right: -50,
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AdminColors.archive.withOpacity(0.12),
                              blurRadius: 80,
                              spreadRadius: 40,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Centered branding contents
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 36.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row: App Tag/Logo
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.asset(
                                    'assets/images/logo/epic_logo_v2.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Text(
                                "EPIC Hub",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // Center branding text
                          const Text(
                            "Ecocultural Pattern\nInnovation Creator",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              height: 1.2,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Game Edukasi Matematika Berbasis Budaya Madura",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Version tag badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.15)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_user_outlined, color: Colors.white70, size: 14),
                                SizedBox(width: 6),
                                Text(
                                  "v1.0.0-admin",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          // Footer text
                          Text(
                            "© 2026 EPIC Project. All rights reserved.",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Right Login Panel Workspace
          Expanded(
            flex: isDesktop ? 6 : 10,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SingleChildScrollView(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AdminColors.border),
                    ),
                    color: AdminColors.surface,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36.0, vertical: 48.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!isDesktop) ...[
                            // Header logo on Mobile view
                            Center(
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/images/logo/epic_logo_v2.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Center(
                              child: Text(
                                "EPIC Admin Panel",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AdminColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Center(
                              child: Text(
                                "v1.0.0-admin",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AdminColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          
                          const Text(
                            "Sign In",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AdminColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Access the management panel for managing users, digital classes, templates, and monitoring Gemini AI scoring.",
                            style: TextStyle(
                              fontSize: 14,
                              color: AdminColors.textSecondary,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 40),

                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AdminColors.danger.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AdminColors.danger.withOpacity(0.2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: AdminColors.danger, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: AdminColors.danger,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Email Field
                                const Text(
                                  "Email Address",
                                  style: TextStyle(fontWeight: FontWeight.w600, color: AdminColors.textPrimary, fontSize: 13),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  style: const TextStyle(fontSize: 14),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Email tidak boleh kosong';
                                    }
                                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val)) {
                                      return 'Format email tidak valid';
                                    }
                                    return null;
                                  },
                                  decoration: InputDecoration(
                                    hintText: "admin@epic.com",
                                    hintStyle: TextStyle(color: Colors.grey.shade400),
                                    isDense: true,
                                    prefixIcon: const Icon(Icons.email_outlined, size: 18, color: AdminColors.textSecondary),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdminColors.border)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdminColors.primary, width: 1.5)),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Password Field
                                const Text(
                                  "Password",
                                  style: TextStyle(fontWeight: FontWeight.w600, color: AdminColors.textPrimary, fontSize: 13),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _passwordCtrl,
                                  obscureText: _obscurePassword,
                                  style: const TextStyle(fontSize: 14),
                                  validator: (val) {
                                    if (val == null || val.isEmpty) {
                                      return 'Password tidak boleh kosong';
                                    }
                                    return null;
                                  },
                                  decoration: InputDecoration(
                                    hintText: "••••••••",
                                    hintStyle: TextStyle(color: Colors.grey.shade400),
                                    isDense: true,
                                    prefixIcon: const Icon(Icons.lock_outline, size: 18, color: AdminColors.textSecondary),
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AdminColors.textSecondary),
                                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdminColors.border)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdminColors.primary, width: 1.5)),
                                  ),
                                ),
                                const SizedBox(height: 28),

                                // Submit Button
                                ElevatedButton(
                                  onPressed: _isLoading ? null : _handleEmailPasswordSignIn,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AdminColors.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Text(
                                          "Sign In",
                                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                        ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),
                          
                          // Divider
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.grey.shade300)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text("OR", style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              Expanded(child: Divider(color: Colors.grey.shade300)),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Google Sign-in Button with loading state
                          ElevatedButton(
                            onPressed: _isLoading ? null : _handleGoogleSignIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AdminColors.textPrimary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: _isLoading 
                                      ? Colors.grey.shade300 
                                      : AdminColors.border,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(AdminColors.primary),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Google Icon Custom Painter
                                      CustomPaint(
                                        size: const Size(20, 20),
                                        painter: GoogleLogoPainter(),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        "Sign in with Google",
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 24),
                          const Text(
                            "Only registered administrator accounts with active roles are allowed authorization to access the Epic Hub control dashboard.",
                            style: TextStyle(
                              fontSize: 11,
                              color: AdminColors.textSecondary,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
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

// Custom Painter for Google Icon Logo
class GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double scale = width / 48;
    canvas.scale(scale, scale);

    // Path 1: Red (top)
    final Paint paintRed = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;
    final Path pathRed = Path()
      ..moveTo(24, 9.5)
      ..cubicTo(27.3, 9.5, 30.2, 10.6, 32.5, 12.7)
      ..lineTo(38.8, 6.4)
      ..cubicTo(36.2, 2.9, 30.5, 0, 24, 0)
      ..cubicTo(14.8, 0, 6.9, 5.2, 2.9, 12.9)
      ..lineTo(10.2, 18.5)
      ..cubicTo(12.2, 13.2, 17.6, 9.5, 24, 9.5)
      ..close();
    canvas.drawPath(pathRed, paintRed);

    // Path 2: Blue (right + horizontal bar)
    final Paint paintBlue = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final Path pathBlue = Path()
      ..moveTo(46.1, 24.5)
      ..cubicTo(46.1, 23, 46, 21.5, 45.7, 20.1)
      ..lineTo(24, 20.1)
      ..lineTo(24, 28.5)
      ..lineTo(36.5, 28.5)
      ..cubicTo(36, 31.5, 34.5, 34, 32, 35.6)
      ..lineTo(39.2, 41.2)
      ..cubicTo(43.4, 37.3, 46.1, 31.6, 46.1, 24.5)
      ..close();
    canvas.drawPath(pathBlue, paintBlue);

    // Path 3: Left Arc (Yellow)
    final Paint paintYellow = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill;
    final Path pathYellow = Path()
      ..moveTo(12.2, 28.5)
      ..cubicTo(11.2, 25.6, 11.2, 22.5, 12.2, 19.6)
      ..lineTo(4.9, 14.0)
      ..cubicTo(2.2, 18.6, 0.0, 21.1, 0.0, 24.0)
      ..cubicTo(0.0, 26.9, 2.2, 29.4, 4.9, 31.1)
      ..lineTo(12.2, 25.5)
      ..close();
    canvas.drawPath(pathYellow, paintYellow);

    // Path 4: Bottom Arc (Green)
    final Paint paintGreen = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill;
    final Path pathGreen = Path()
      ..moveTo(24, 48)
      ..cubicTo(30.5, 48, 36.2, 45.8, 40.3, 42.1)
      ..lineTo(33.1, 36.5)
      ..cubicTo(31.1, 37.8, 28.6, 38.6, 26, 38.6)
      ..cubicTo(19.6, 38.6, 14.2, 34.9, 11.5, 29.5)
      ..lineTo(4.2, 35.1)
      ..cubicTo(8.9, 42.8, 16.8, 48, 24, 48)
      ..close();
    canvas.drawPath(pathGreen, paintGreen);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
