import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/form_validators.dart';
import '../models/department.dart';
import '../services/session_store.dart';
import '../ui/components/checktap_logo.dart';
import '../ui/theme/checktap_colors.dart';
import '../ui/theme/checktap_spacing.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({required this.session, super.key});

  final SessionStore session;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  List<DepartmentSummary> _departments = const <DepartmentSummary>[];
  String? _departmentId;
  String? _error;
  bool _loadingDepartments = true;
  bool _saving = false;
  bool _submitted = false;
  bool _hidePassword = true;
  bool _hideConfirmation = true;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    setState(() {
      _loadingDepartments = true;
      _error = null;
    });
    try {
      final departments = await widget.session.authService
          .registrationDepartments();
      if (!mounted) {
        return;
      }
      setState(() {
        _departments = departments;
        _departmentId = departments.length == 1 ? departments.first.id : null;
        if (departments.isEmpty) {
          _error = 'No hay departamentos disponibles para solicitar acceso.';
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = _message(error));
      }
    } finally {
      if (mounted) {
        setState(() => _loadingDepartments = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_saving || _loadingDepartments) {
      return;
    }
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.session.authService.register(
        name: FormValidators.normalizeSingleLine(_nameController.text),
        email: FormValidators.normalizeEmail(_emailController.text),
        password: _passwordController.text,
        departmentId: _departmentId!,
      );
      if (mounted) {
        setState(() {
          _saving = false;
          _submitted = true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _message(error);
        });
      }
    }
  }

  String _message(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final detail = data['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail;
        }
      }
      if (error.response == null) {
        return 'No fue posible conectar con el servidor de la empresa.';
      }
    }
    return 'No fue posible enviar la solicitud. Inténtalo nuevamente.';
  }

  String? _confirmPassword(String? value) {
    final passwordError = FormValidators.password(value);
    if (passwordError != null) {
      return passwordError;
    }
    if (value != _passwordController.text) {
      return 'Las contraseñas no coinciden.';
    }
    return null;
  }

  void _returnToLogin() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_submitted ? 'Solicitud enviada' : 'Crear cuenta'),
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: <Widget>[
            const Positioned.fill(child: _RegistrationBackground()),
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 40,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: _submitted
                            ? _RegistrationSuccess(
                                email: FormValidators.normalizeEmail(
                                  _emailController.text,
                                ),
                                onReturn: _returnToLogin,
                              )
                            : _buildForm(context),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CheckTapSpacing.xl),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(CheckTapRadius.xl),
        border: Border.all(color: CheckTapColors.borderFor(context)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: CheckTapColors.shadowFor(context),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Align(child: CheckTapLogo(width: 104)),
              const SizedBox(height: CheckTapSpacing.sm),
              Text(
                'Solicita acceso a tu equipo',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Completa tu perfil. El administrador confirmará tu entrada antes del primer acceso.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: CheckTapColors.textMutedFor(context),
                ),
              ),
              const SizedBox(height: CheckTapSpacing.xl),
              TextFormField(
                key: const ValueKey<String>('registration-name'),
                controller: _nameController,
                enabled: !_saving,
                maxLength: 120,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[AutofillHints.name],
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: FormValidators.personName,
              ),
              const SizedBox(height: CheckTapSpacing.sm),
              TextFormField(
                key: const ValueKey<String>('registration-email'),
                controller: _emailController,
                enabled: !_saving,
                maxLength: 254,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const <String>[
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                validator: FormValidators.email,
              ),
              const SizedBox(height: CheckTapSpacing.sm),
              TextFormField(
                key: const ValueKey<String>('registration-password'),
                controller: _passwordController,
                enabled: !_saving,
                maxLength: 128,
                obscureText: _hidePassword,
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _hidePassword
                        ? 'Mostrar contraseña'
                        : 'Ocultar contraseña',
                    onPressed: _saving
                        ? null
                        : () => setState(() => _hidePassword = !_hidePassword),
                    icon: Icon(
                      _hidePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: FormValidators.password,
              ),
              const SizedBox(height: CheckTapSpacing.sm),
              TextFormField(
                key: const ValueKey<String>('registration-confirm-password'),
                controller: _confirmPasswordController,
                enabled: !_saving,
                maxLength: 128,
                obscureText: _hideConfirmation,
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Confirmar contraseña',
                  prefixIcon: const Icon(Icons.lock_reset_rounded),
                  suffixIcon: IconButton(
                    tooltip: _hideConfirmation
                        ? 'Mostrar confirmación'
                        : 'Ocultar confirmación',
                    onPressed: _saving
                        ? null
                        : () => setState(
                            () => _hideConfirmation = !_hideConfirmation,
                          ),
                    icon: Icon(
                      _hideConfirmation
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: _confirmPassword,
              ),
              const SizedBox(height: CheckTapSpacing.sm),
              if (_loadingDepartments)
                const SizedBox(
                  height: 56,
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                DropdownButtonFormField<String>(
                  key: const ValueKey<String>('registration-department'),
                  initialValue: _departmentId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Departamento',
                    prefixIcon: Icon(Icons.apartment_rounded),
                  ),
                  items: _departments
                      .map(
                        (department) => DropdownMenuItem<String>(
                          value: department.id,
                          child: Text(
                            department.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _departmentId = value),
                  validator: (value) => value == null
                      ? 'Seleccione el departamento al que pertenece.'
                      : null,
                ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: CheckTapSpacing.md),
                _RegistrationMessage(
                  message: _error!,
                  color: CheckTapColors.danger,
                  icon: Icons.error_outline_rounded,
                ),
              ],
              const SizedBox(height: CheckTapSpacing.lg),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: _saving || _departments.isEmpty
                      ? null
                      : CheckTapColors.brandGradient,
                  borderRadius: BorderRadius.circular(CheckTapRadius.md),
                ),
                child: FilledButton.icon(
                  key: const ValueKey<String>('submit-registration'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _saving || _departments.isEmpty
                        ? null
                        : Colors.transparent,
                    shadowColor: Colors.transparent,
                  ),
                  onPressed: _saving || _departments.isEmpty ? null : _submit,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _saving ? 'Enviando solicitud…' : 'Enviar solicitud',
                  ),
                ),
              ),
              const SizedBox(height: CheckTapSpacing.md),
              const _RegistrationMessage(
                message:
                    'El registro requiere conexión con el servidor de la empresa. Nunca podrás registrarte como administrador.',
                color: CheckTapColors.info,
                icon: Icons.info_outline_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegistrationSuccess extends StatelessWidget {
  const _RegistrationSuccess({required this.email, required this.onReturn});

  final String email;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CheckTapSpacing.xxl),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(CheckTapRadius.xl),
        border: Border.all(color: CheckTapColors.borderFor(context)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: CheckTapColors.shadowFor(context),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              color: CheckTapColors.primaryFor(context).withValues(alpha: 0.09),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Icon(
                  Icons.shield_outlined,
                  size: 72,
                  color: CheckTapColors.primaryFor(context),
                ),
                Icon(
                  Icons.schedule_rounded,
                  size: 31,
                  color: CheckTapColors.cyanFor(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: CheckTapSpacing.xl),
          Text(
            'Solicitud enviada',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: CheckTapSpacing.sm),
          Text(
            'Un administrador revisará el acceso de $email y confirmará el departamento.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: CheckTapColors.textMutedFor(context),
            ),
          ),
          const SizedBox(height: CheckTapSpacing.lg),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: CheckTapColors.warning.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(CheckTapRadius.pill),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.schedule_rounded,
                  size: 20,
                  color: CheckTapColors.warning,
                ),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Pendiente de aprobación',
                    style: TextStyle(
                      color: CheckTapColors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: CheckTapSpacing.xxl),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onReturn,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Volver al inicio'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegistrationMessage extends StatelessWidget {
  const _RegistrationMessage({
    required this.message,
    required this.color,
    required this.icon,
  });

  final String message;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CheckTapSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(CheckTapRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegistrationBackground extends StatelessWidget {
  const _RegistrationBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: CheckTapColors.quietGradientFor(context),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -130,
            right: -110,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CheckTapColors.cyanFor(context).withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -120,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CheckTapColors.primaryFor(
                  context,
                ).withValues(alpha: 0.06),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
