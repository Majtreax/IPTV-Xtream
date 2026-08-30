import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_xtream/app/theme.dart';
import 'package:iptv_xtream/widgets/loading_indicator.dart';
import 'package:iptv_xtream/providers/auth_provider.dart';
import 'package:iptv_xtream/widgets/app_button.dart';

enum LoginStep { server, username, password }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _loginButtonFocus = FocusNode();
  final _m3uButtonFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(authProvider.notifier).restoreSession();
    });
  }

  @override
  void dispose() {
    _loginButtonFocus.dispose();
    _m3uButtonFocus.dispose();
    super.dispose();
  }

  void _showLoginDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const LoginWizardDialog(),
    );
  }

  void _pickLocalFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result != null && result.files.single.path != null) {
        final url = result.files.single.path!;
        if (url.isEmpty) return;
        await ref.read(authProvider.notifier).logout();
        ref.read(authProvider.notifier).loginWithM3u(m3uUrl: url);
      }
    } catch (e) {
      // IGNORE
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    final isConnecting =
        authState.isLoading || authState.status == AuthStatus.initial;

    if (isConnecting && authState.errorMessage == null) {
      return Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: kAppBackgroundDecoration,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 18),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          Color(0xFFE9D5FF),
                          kAccentPurple,
                          kFocusedButtonColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'IPTV',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 5.5,
                              height: 1.0,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'XTREAM',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.8,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: LoadingIndicator(),
                    ),
                    SizedBox(width: 16),
                    Text(
                      'Connecting to service...',
                      style: TextStyle(
                        color: kTextSecondary,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: kAppBackgroundDecoration,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 550),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 40,
                  ),
                  decoration: buildDialogDecoration(radius: 20, blurRadius: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/logo.png',
                            height: 60,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 16),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [
                                Color(0xFFE9D5FF),
                                kAccentPurple,
                                kFocusedButtonColor,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text(
                                  'IPTV',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 4.5,
                                    height: 1.0,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'XTREAM',
                                  style: TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 1.5,
                                    height: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 2,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              kFocusedButtonColor.withValues(alpha: 0.5),
                              kPrimaryButtonColor,
                              kFocusedButtonColor.withValues(alpha: 0.5),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (authState.errorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: kSemanticRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: kSemanticRed.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: kSemanticRed,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  authState.errorMessage!,
                                  style: const TextStyle(
                                    color: kSemanticRed,
                                    fontSize: 14,
                                    height: 1.3,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      AppButton(
                        focusNode: _loginButtonFocus,
                        autofocus: true,
                        label: 'Login',
                        icon: Icons.login_rounded,
                        primary: false,
                        onPressed: _showLoginDialog,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'With API Credentials',
                        style: TextStyle(
                          color: kTextSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: kTextDisabled.withValues(alpha: 0.2),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'OR',
                                style: TextStyle(
                                  color: kAccentPurple,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: kTextDisabled.withValues(alpha: 0.2),
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppButton(
                        focusNode: _m3uButtonFocus,
                        label: 'Load M3U Playlist',
                        icon: Icons.playlist_add_rounded,
                        primary: true,
                        onPressed: _pickLocalFile,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginWizardDialog extends ConsumerStatefulWidget {
  const LoginWizardDialog({super.key});

  @override
  ConsumerState<LoginWizardDialog> createState() => _LoginWizardDialogState();
}

class _LoginWizardDialogState extends ConsumerState<LoginWizardDialog> {
  LoginStep _currentStep = LoginStep.server;
  String? _inputError;

  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  final _inputFocus = FocusNode();
  final _closeFocus = FocusNode();
  final _nextFocus = FocusNode();
  final _backFocus = FocusNode();

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _inputFocus.dispose();
    _closeFocus.dispose();
    _nextFocus.dispose();
    _backFocus.dispose();
    super.dispose();
  }

  void _clearCurrent() {
    setState(() => _inputError = null);
    switch (_currentStep) {
      case LoginStep.server:
        _serverController.clear();
        break;
      case LoginStep.username:
        _usernameController.clear();
        break;
      case LoginStep.password:
        _passwordController.clear();
        break;
    }
    _inputFocus.requestFocus();
  }

  void _goNext() {
    if (_currentStep == LoginStep.server) {
      final text = _serverController.text.trim();
      if (text.isEmpty) {
        setState(() => _inputError = 'Server URL cannot be empty.');
        return;
      }
      if (!text.startsWith('http://') && !text.startsWith('https://')) {
        setState(
          () => _inputError = 'Server URL must start with http:// or https://',
        );
        return;
      }
      setState(() {
        _inputError = null;
        _currentStep = LoginStep.username;
      });
      _inputFocus.requestFocus();
    } else if (_currentStep == LoginStep.username) {
      if (_usernameController.text.trim().isEmpty) {
        setState(() => _inputError = 'Username cannot be empty.');
        return;
      }
      setState(() {
        _inputError = null;
        _currentStep = LoginStep.password;
      });
      _inputFocus.requestFocus();
    } else if (_currentStep == LoginStep.password) {
      if (_passwordController.text.trim().isEmpty) {
        setState(() => _inputError = 'Password cannot be empty.');
        return;
      }
      _loginXtream();
    }
  }

  void _goBack() {
    setState(() => _inputError = null);
    if (_currentStep == LoginStep.password) {
      setState(() => _currentStep = LoginStep.username);
      _inputFocus.requestFocus();
    } else if (_currentStep == LoginStep.username) {
      setState(() => _currentStep = LoginStep.server);
      _inputFocus.requestFocus();
    }
  }

  void _loginXtream() async {
    final server = _serverController.text.trim();
    final user = _usernameController.text.trim();
    final pass = _passwordController.text.trim();

    if (!server.startsWith('http://') && !server.startsWith('https://')) {
      setState(() {
        _currentStep = LoginStep.server;
        _inputError = 'Server URL must start with http:// or https://';
      });
      _inputFocus.requestFocus();
      return;
    }

    if (server.isEmpty || user.isEmpty || pass.isEmpty) return;

    Navigator.of(context).pop();

    await ref.read(authProvider.notifier).logout();
    ref
        .read(authProvider.notifier)
        .loginWithXtream(serverUrl: server, username: user, password: pass);
  }

  Widget _buildIconButton({
    required FocusNode focusNode,
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
    Color? overrideColor,
  }) {
    return Focus(
      focusNode: focusNode,
      onFocusChange: (focused) => setState(() {}),
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          return Tooltip(
            message: tooltip,
            child: GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 48,
                height: 48,
                decoration: buildGlassyPillDecoration(radius: 12).copyWith(
                  border: Border.all(
                    color: isFocused
                        ? (overrideColor ?? kAccentPurple)
                        : Colors.white.withValues(alpha: 0.08),
                    width: isFocused ? 2 : 1.5,
                  ),
                ),
                child: Icon(
                  icon,
                  color: isFocused
                      ? (overrideColor ?? kAccentPurple)
                      : (overrideColor ?? kTextSecondary),
                  size: 24,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    TextEditingController activeController;
    String activeLabel;
    String activeHint;
    bool isObscure = false;
    IconData stepIcon;

    switch (_currentStep) {
      case LoginStep.server:
        activeController = _serverController;
        activeLabel = 'Server URL';
        activeHint = 'http://provider.example.com';
        stepIcon = Icons.dns_rounded;
        break;
      case LoginStep.username:
        activeController = _usernameController;
        activeLabel = 'Username';
        activeHint = 'Username';
        stepIcon = Icons.person_rounded;
        break;
      case LoginStep.password:
        activeController = _passwordController;
        activeLabel = 'Password';
        activeHint = 'Password';
        isObscure = true;
        stepIcon = Icons.vpn_key_rounded;
        break;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: FocusTraversalGroup(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 550),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
            decoration: buildDialogDecoration(radius: 20, blurRadius: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(stepIcon, size: 24, color: kAccentPurple),
                    const SizedBox(width: 12),
                    Text(
                      'Step ${_currentStep.index + 1} of 3: $activeLabel',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kTextPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (_currentStep != LoginStep.server)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildIconButton(
                          focusNode: _backFocus,
                          icon: Icons.arrow_back_rounded,
                          onTap: _goBack,
                          tooltip: 'Back',
                        ),
                      ),
                    Expanded(
                      child: TextField(
                        focusNode: _inputFocus,
                        autofocus: true,
                        controller: activeController,
                        obscureText: isObscure,
                        textAlign: TextAlign.center,
                        textInputAction: TextInputAction.done,
                        style: const TextStyle(
                          fontSize: 16,
                          color: kTextPrimary,
                        ),
                        onChanged: (_) {
                          if (_inputError != null) {
                            setState(() => _inputError = null);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: activeLabel,
                          floatingLabelAlignment: FloatingLabelAlignment.center,
                          hintText: activeHint,
                          isDense: true,
                          errorText: _inputError != null ? '' : null,
                          errorStyle: const TextStyle(height: 0, fontSize: 0),
                        ),
                        onSubmitted: (_) => _goNext(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _buildIconButton(
                        focusNode: _closeFocus,
                        icon: Icons.close_rounded,
                        onTap: _clearCurrent,
                        tooltip: 'Clear Input',
                      ),
                    ),
                  ],
                ),
                if (_inputError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _inputError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: kSemanticRed,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                AppButton(
                  focusNode: _nextFocus,
                  label: _currentStep == LoginStep.password ? 'Login' : 'Next',
                  icon: _currentStep == LoginStep.password
                      ? Icons.login_rounded
                      : Icons.arrow_forward_rounded,
                  primary: true,
                  onPressed: _goNext,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
