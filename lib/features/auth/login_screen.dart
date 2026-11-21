import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/constants/app_colors.dart';
import '../../core/navigation/routes.dart';
import '../../data/models/app_user.dart';
import '../../data/services/mock_database.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _keepMeSignedIn = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    ApiClient.loadSavedHost().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _showServerSettingsDialog() {
    final hostCtrl = TextEditingController(text: ApiClient.currentHost);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conexión al Servidor (API)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ingresa la IP y puerto donde corre tu backend FastAPI:',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: hostCtrl,
              decoration: const InputDecoration(
                labelText: 'IP : Puerto',
                hintText: '192.168.137.1:8000',
                prefixIcon: Icon(Icons.dns_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(
                  label: const Text('Hotspot PC (192.168.137.1)', style: TextStyle(fontSize: 11)),
                  onPressed: () => hostCtrl.text = '192.168.137.1:8000',
                ),
                ActionChip(
                  label: const Text('Wi-Fi PC (172.16.77.50)', style: TextStyle(fontSize: 11)),
                  onPressed: () => hostCtrl.text = '172.16.77.50:8000',
                ),
                ActionChip(
                  label: const Text('USB / Local (127.0.0.1)', style: TextStyle(fontSize: 11)),
                  onPressed: () => hostCtrl.text = '127.0.0.1:8000',
                ),
                ActionChip(
                  label: const Text('Emulador (10.0.2.2)', style: TextStyle(fontSize: 11)),
                  onPressed: () => hostCtrl.text = '10.0.2.2:8000',
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ApiClient.setCustomHost(hostCtrl.text);
              if (mounted) setState(() {});
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Guardar IP'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final db = Provider.of<MockDatabase>(context, listen: false);
    final success = await db.login(_emailController.text, _passwordController.text);
    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        // Navigate based on user role
        switch (db.currentUser?.role) {
          case UserRole.admin:
            Navigator.pushReplacementNamed(context, AppRoutes.adminDashboard);
            break;
          case UserRole.driver:
            Navigator.pushReplacementNamed(context, AppRoutes.driverDashboard);
            break;
          case UserRole.parent:
            Navigator.pushReplacementNamed(context, AppRoutes.parentDashboard);
            break;
          default:
            Navigator.pushReplacementNamed(context, AppRoutes.roleSelection);
        }
      } else {
        final errorMsg = db.lastAuthError ?? 'Credenciales incorrectas. Intenta de nuevo.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textLight : AppColors.textDark;
    
    return Scaffold(
      body: Stack(
        children: [
          // Bold Background Shapes
          Positioned(
            top: -150,
            right: -100,
            child: Transform.rotate(
              angle: 0.2,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(60),
                ),
              ),
            ),
          ),
          if (isDark)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.2), // Subtle dimming for dark mode contrast
              ),
            ),
            
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 60),
                    
                    // Brutalist/Premium Typography Header
                    Text(
                      'ACCESO.',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppColors.textDark,
                        letterSpacing: -2,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'TRANSPORTE ESCOLAR',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isDark ? AppColors.primary : AppColors.accent,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 64),

                    // Form Fields (Email/Cédula & Password)
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(
                        labelText: 'Correo Electrónico o Cédula',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor ingrese su correo o cédula';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Por favor ingrese su contraseña';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Keep me signed in & Forgot Password
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _keepMeSignedIn,
                                activeColor: AppColors.primary,
                                checkColor: AppColors.textDark,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                onChanged: (val) {
                                  setState(() {
                                    _keepMeSignedIn = val ?? true;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Recordarme',
                              style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Enlace para restablecer contraseña enviado.')),
                            );
                          },
                          child: Text(
                            '¿Olvidó su clave?',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.primary : AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // Login Button (Massive, High Contrast)
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.textDark),
                            )
                          : const Text(
                              'ENTRAR AHORA',
                              style: TextStyle(letterSpacing: 1.5, fontSize: 16),
                            ),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: _showServerSettingsDialog,
                      icon: const Icon(Icons.settings_ethernet, size: 16, color: AppColors.textMuted),
                      label: Text(
                        'Servidor API: ${ApiClient.baseUrl} (Cambiar)',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
