import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:pai_morn_web/auth/auth_provider.dart';
import 'package:pai_morn_web/l10n/l10n.dart';
import 'package:pai_morn_web/l10n/locale_provider.dart';
import 'package:pai_morn_web/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _AuthMode { login, register, forgotPassword }

class _LoginScreenState extends State<LoginScreen> {
  _AuthMode _mode = _AuthMode.login;
  bool _isSubmitting = false;
  String? _errorMessage;
  // Distinct from _errorMessage so a successful "reset link sent" message
  // doesn't render in the error color.
  String? _infoMessage;

  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _switchMode(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _errorMessage = null;
      _infoMessage = null;
    });
  }

  Future<void> _submit(AuthProvider auth, String language) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final isRegisterMode = _mode == _AuthMode.register;

    if (email.isEmpty ||
        password.isEmpty ||
        (isRegisterMode &&
            (_displayNameController.text.trim().isEmpty ||
                _confirmPasswordController.text.isEmpty))) {
      setState(
        () =>
            _errorMessage = AppTranslations.getText(
              'pleaseFillAllFields',
              language,
            ),
      );
      return;
    }
    if (isRegisterMode && password != _confirmPasswordController.text) {
      setState(
        () =>
            _errorMessage = AppTranslations.getText(
              'passwordsDontMatch',
              language,
            ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final error =
        isRegisterMode
            ? await auth.register(email, password, _displayNameController.text)
            : await auth.signIn(email, password);

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _errorMessage = error;
    });
  }

  Future<void> _sendResetLink(AuthProvider auth, String language) async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(
        () =>
            _errorMessage = AppTranslations.getText(
              'pleaseFillAllFields',
              language,
            ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    final error = await auth.sendPasswordResetEmail(email);

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      if (error != null) {
        _errorMessage = error;
      } else {
        _infoMessage = AppTranslations.getText(
          'resetEmailSentMessage',
          language,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final language = context.watch<LocaleProvider>().currentLanguage;
    final auth = context.watch<AuthProvider>();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: scheme.onSurface.withOpacity(0.08)),
              boxShadow: AppShadows.soft(scheme.onSurface),
            ),
            child:
                auth.isLoggedIn
                    ? _buildLoggedInCard(context, auth, scheme, language)
                    : _mode == _AuthMode.forgotPassword
                    ? _buildForgotPasswordForm(context, auth, scheme, language)
                    : _buildForm(context, auth, scheme, language),
          ),
        ),
      ),
    );
  }

  Widget _buildLoggedInCard(
    BuildContext context,
    AuthProvider auth,
    ColorScheme scheme,
    String language,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FaIcon(FontAwesomeIcons.solidCircleUser, size: 64, color: scheme.onSurface),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${AppTranslations.getText('loggedInAs', language)} '
          '${auth.displayName ?? auth.user?.email ?? ''}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: scheme.onSurface),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _mode = _AuthMode.login;
                _displayNameController.clear();
                _emailController.clear();
                _passwordController.clear();
                _confirmPasswordController.clear();
              });
              auth.signOut();
            },
            child: Text(AppTranslations.getText('logout', language)),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(
    BuildContext context,
    AuthProvider auth,
    ColorScheme scheme,
    String language,
  ) {
    final isRegisterMode = _mode == _AuthMode.register;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppTranslations.getText(
            isRegisterMode ? 'register' : 'login',
            language,
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (isRegisterMode) ...[
          TextField(
            controller: _displayNameController,
            decoration: InputDecoration(
              labelText: AppTranslations.getText('displayName', language),
              prefixIcon: const FaIcon(FontAwesomeIcons.user, size: 18),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: AppTranslations.getText('email', language),
            prefixIcon: const FaIcon(FontAwesomeIcons.envelope, size: 18),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: AppTranslations.getText('password', language),
            prefixIcon: const FaIcon(FontAwesomeIcons.lock, size: 18),
          ),
        ),
        if (isRegisterMode) ...[
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _confirmPasswordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: AppTranslations.getText('confirmPassword', language),
              prefixIcon: const FaIcon(FontAwesomeIcons.lock, size: 18),
            ),
          ),
        ],
        if (!isRegisterMode) ...[
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed:
                  _isSubmitting
                      ? null
                      : () => _switchMode(_AuthMode.forgotPassword),
              child: Text(AppTranslations.getText('forgotPassword', language)),
            ),
          ),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _errorMessage!,
            style: TextStyle(color: scheme.error),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        ElevatedButton(
          onPressed: _isSubmitting ? null : () => _submit(auth, language),
          child:
              _isSubmitting
                  ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.surface,
                    ),
                  )
                  : Text(
                    AppTranslations.getText(
                      isRegisterMode ? 'register' : 'login',
                      language,
                    ),
                  ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed:
              _isSubmitting
                  ? null
                  : () => _switchMode(
                    isRegisterMode ? _AuthMode.login : _AuthMode.register,
                  ),
          child: Text(
            AppTranslations.getText(
              isRegisterMode ? 'alreadyHaveAccount' : 'dontHaveAccount',
              language,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForgotPasswordForm(
    BuildContext context,
    AuthProvider auth,
    ColorScheme scheme,
    String language,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppTranslations.getText('resetPasswordTitle', language),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          AppTranslations.getText('resetPasswordInstructions', language),
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurface.withOpacity(0.7)),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: AppTranslations.getText('email', language),
            prefixIcon: const FaIcon(FontAwesomeIcons.envelope, size: 18),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _errorMessage!,
            style: TextStyle(color: scheme.error),
            textAlign: TextAlign.center,
          ),
        ],
        if (_infoMessage != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _infoMessage!,
            style: TextStyle(color: scheme.onSurface),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        ElevatedButton(
          onPressed:
              _isSubmitting ? null : () => _sendResetLink(auth, language),
          child:
              _isSubmitting
                  ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.surface,
                    ),
                  )
                  : Text(AppTranslations.getText('sendResetLink', language)),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: _isSubmitting ? null : () => _switchMode(_AuthMode.login),
          child: Text(AppTranslations.getText('backToLogin', language)),
        ),
      ],
    );
  }
}
