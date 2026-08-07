import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/form_validators.dart';
import '../services/notification_service.dart';
import '../services/session_store.dart';
import '../ui/components/checktap_logo.dart';
import '../ui/theme/checktap_colors.dart';
import '../ui/theme/checktap_spacing.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.session, super.key});

  final SessionStore session;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _notificationPermissionRequestStarted = false;
  bool _loading = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_requestNotificationPermissionOnEntry());
    });
  }

  Future<void> _requestNotificationPermissionOnEntry() async {
    if (_notificationPermissionRequestStarted) {
      return;
    }
    _notificationPermissionRequestStarted = true;

    try {
      final result = await NotificationService.instance
          .requestPermissionOnLoginEntry();
      debugPrint(
        '[FCM] Login visible. Estado de permiso: '
        '${result.authorizationStatus.name}',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[FCM] No fue posible solicitar el permiso al abrir login: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.session.login(
        FormValidators.normalizeEmail(_emailController.text),
        _passwordController.text,
      );

      NotificationService.instance.attachApiClient(widget.session.apiClient);
      unawaited(
        NotificationService.instance
            .registerCurrentDevice(requestPermission: false, force: true)
            .catchError((Object error, StackTrace stackTrace) {
              debugPrint(
                '[FCM] El inicio de sesión continuó sin notificaciones: $error',
              );
              debugPrintStack(stackTrace: stackTrace);
              return false;
            }),
      );

      if (!mounted) {
        return;
      }

      setState(() => _loading = false);
      Navigator.of(context).pushNamedAndRemoveUntil('/tasks', (route) => false);
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }

      final data = error.response?.data;
      final statusCode = error.response?.statusCode;
      setState(() {
        _loading = false;
        if (statusCode == 401 || statusCode == 403) {
          _error = 'Correo o contraseña incorrectos.';
        } else if (data is Map<String, dynamic> && data['detail'] != null) {
          _error = data['detail'].toString();
        } else {
          _error =
              'No fue posible conectar con el servidor. '
              'El primer ingreso requiere conexión.';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Ocurrió un error inesperado: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 760;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final form = _LoginForm(
              formKey: _formKey,
              emailController: _emailController,
              passwordController: _passwordController,
              loading: _loading,
              hidePassword: _hidePassword,
              error: _error,
              onTogglePassword: () => setState(
                () => _hidePassword = !_hidePassword,
              ),
              onSubmit: _submit,
            );

            if (wide) {
              return Row(
                children: <Widget>[
                  Expanded(
                    flex: 11,
                    child: _BrandPanel(height: constraints.maxHeight),
                  ),
                  Expanded(
                    flex: 10,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(CheckTapSpacing.xxl),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 450),
                          child: form,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return Stack(
              children: <Widget>[
                const Positioned.fill(child: _MobileBackground()),
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 52,
                    ),
                    child: Column(
                      children: <Widget>[
                        const SizedBox(height: 6),
                        const CheckTapLogo(width: 238),
                        const SizedBox(height: 4),
                        const CheckTapWordmark(fontSize: 28, centered: true),
                        const SizedBox(height: 8),
                        Text(
                          'Organiza. Asigna. Cumple.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: CheckTapColors.textMuted,
                              ),
                        ),
                        const SizedBox(height: 28),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 450),
                          child: form,
                        ),
                        const SizedBox(height: 24),
                        _OfflineNote(offlineSession: widget.session.offlineSession),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.loading,
    required this.hidePassword,
    required this.error,
    required this.onTogglePassword,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool loading;
  final bool hidePassword;
  final String? error;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CheckTapSpacing.xl),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: CheckTapColors.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: CheckTapColors.navy.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: AutofillGroup(
        child: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Bienvenido', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'Ingresa para continuar con tu equipo.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: CheckTapColors.textMuted,
                    ),
              ),
              const SizedBox(height: CheckTapSpacing.xl),
              TextFormField(
                controller: emailController,
                enabled: !loading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[AutofillHints.username, AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  hintText: 'usuario@empresa.com',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                validator: FormValidators.email,
              ),
              const SizedBox(height: CheckTapSpacing.md),
              TextFormField(
                controller: passwordController,
                enabled: !loading,
                obscureText: hidePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const <String>[AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: hidePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
                    onPressed: loading ? null : onTogglePassword,
                    icon: Icon(
                      hidePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) => FormValidators.password(value),
                onFieldSubmitted: (_) => onSubmit(),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.topCenter,
                child: error == null
                    ? const SizedBox(height: CheckTapSpacing.sm)
                    : Container(
                        margin: const EdgeInsets.only(top: CheckTapSpacing.sm),
                        padding: const EdgeInsets.all(CheckTapSpacing.sm),
                        decoration: BoxDecoration(
                          color: CheckTapColors.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(CheckTapRadius.md),
                          border: Border.all(
                            color: CheckTapColors.danger.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Icon(
                              Icons.error_outline_rounded,
                              color: CheckTapColors.danger,
                              size: 20,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                error!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: CheckTapColors.danger,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: CheckTapSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: loading ? null : CheckTapColors.brandGradient,
                    borderRadius: BorderRadius.circular(CheckTapRadius.md),
                  ),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: loading ? null : Colors.transparent,
                      shadowColor: Colors.transparent,
                    ),
                    onPressed: loading ? null : onSubmit,
                    icon: loading
                        ? const SizedBox.square(
                            dimension: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.login_rounded),
                    label: Text(loading ? 'Ingresando…' : 'Ingresar'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: height),
      padding: const EdgeInsets.all(48),
      decoration: const BoxDecoration(
        gradient: CheckTapColors.brandGradient,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(50),
          bottomRight: Radius.circular(50),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
            ),
            child: const CheckTapLogo(width: 280),
          ),
          const SizedBox(height: 20),
          const CheckTapWordmark(fontSize: 36, centered: true),
          const SizedBox(height: 12),
          Text(
            'El trabajo de tu equipo, claro y sincronizado.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 30),
          const _FeaturePill(icon: Icons.groups_2_outlined, label: 'Colaboración por departamentos'),
          const SizedBox(height: 10),
          const _FeaturePill(icon: Icons.cloud_off_outlined, label: 'Trabajo offline confiable'),
          const SizedBox(height: 10),
          const _FeaturePill(icon: Icons.notifications_active_outlined, label: 'Avisos y reportes al instante'),
        ],
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(CheckTapRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileBackground extends StatelessWidget {
  const _MobileBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: CheckTapColors.quietGradient),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -120,
            right: -120,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CheckTapColors.cyan.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CheckTapColors.primary.withValues(alpha: 0.07),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineNote extends StatelessWidget {
  const _OfflineNote({required this.offlineSession});

  final bool offlineSession;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(
          offlineSession ? Icons.cloud_off_rounded : Icons.shield_outlined,
          size: 17,
          color: offlineSession ? CheckTapColors.warning : CheckTapColors.textMuted,
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            offlineSession
                ? 'Sesión local activa. Los cambios se sincronizarán al volver la red.'
                : 'Sesión segura y trabajo disponible sin conexión después del primer ingreso.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: CheckTapColors.textMuted,
                ),
          ),
        ),
      ],
    );
  }
}
