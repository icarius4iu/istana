import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/session_provider.dart';
import '../utils/extensions.dart';

/// Login/registro para poder crear o unirse a una jam session — la
/// identidad (`AuthUser.id`) es lo que viaja como `ownerId`/`userId` en las
/// rutas de sesión. Único formulario, alternando entre los dos modos (mismo
/// patrón dual que `PlaylistScreen`: una sola pantalla, distinto estado).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegisterMode = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final session = context.read<SessionProvider>();
    final ok = _isRegisterMode
        ? await session.register(
            username: _usernameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
          )
        : await session.login(
            username: _usernameController.text.trim(),
            password: _passwordController.text,
          );

    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      context.showSnack(session.errorMessage ?? 'No se pudo continuar');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isRegisterMode ? 'Crear cuenta' : 'Iniciar sesión'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.groups_outlined,
                    size: 56,
                    color: AppTheme.spotifyGreen,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Para crear o unirte a una jam session necesitás una cuenta.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(hintText: 'Usuario'),
                    validator: (value) =>
                        (value == null || value.trim().length < 3)
                        ? 'Mínimo 3 caracteres'
                        : null,
                  ),
                  if (_isRegisterMode) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(hintText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) =>
                          (value == null || !value.contains('@'))
                          ? 'Email inválido'
                          : null,
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(hintText: 'Contraseña'),
                    obscureText: true,
                    validator: (value) => (value == null || value.length < 8)
                        ? 'Mínimo 8 caracteres'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: session.isBusy ? null : _submit,
                    child: session.isBusy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Text(_isRegisterMode ? 'Crear cuenta' : 'Entrar'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () =>
                        setState(() => _isRegisterMode = !_isRegisterMode),
                    child: Text(
                      _isRegisterMode
                          ? '¿Ya tenés cuenta? Iniciá sesión'
                          : '¿No tenés cuenta? Creá una',
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
}
