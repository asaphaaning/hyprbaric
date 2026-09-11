import 'package:flutter/material.dart';

import 'network_console.dart';

/// Focused join form shared by the production panel and catalog previews.
class NetworkPasswordPrompt extends StatelessWidget {
  const NetworkPasswordPrompt({
    super.key,
    required this.ssid,
    this.subtitle = 'Secured network',
    this.policy,
    this.leading,
    required this.controller,
    required this.focusNode,
    required this.showPassword,
    required this.connecting,
    required this.errorMessage,
    required this.onToggleVisibility,
    required this.onCancel,
    required this.onSubmit,
  });

  final String ssid;
  final String subtitle;
  final Widget? policy;
  final Widget? leading;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool showPassword;
  final bool connecting;
  final String? errorMessage;
  final VoidCallback onToggleVisibility;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => NetworkCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?leading,
        Text(
          'Join $ssid',
          style: NetworkConsole.body.copyWith(
            fontSize: 13,
            color: NetworkConsole.text,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(subtitle),
        const SizedBox(height: 10),
        Text('Password', style: NetworkConsole.body.copyWith(fontSize: 11)),
        const SizedBox(height: 3),
        TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: !showPassword,
          enabled: !connecting,
          enableSuggestions: false,
          autocorrect: false,
          onSubmitted: (_) {
            if (controller.text.isNotEmpty) onSubmit();
          },
          style: NetworkConsole.body.copyWith(
            color: NetworkConsole.text,
            fontSize: 12,
          ),
          decoration: InputDecoration(
            hintText: 'Password for $ssid',
            hintStyle: NetworkConsole.body.copyWith(
              color: NetworkConsole.muted.withValues(alpha: .5),
            ),
            isDense: true,
            filled: true,
            fillColor: const Color(0x88070812),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: const BorderSide(color: NetworkConsole.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: const BorderSide(
                color: NetworkConsole.download,
                width: 1,
              ),
            ),
            suffixIconConstraints: const BoxConstraints(
              maxHeight: 30,
              minWidth: 35,
            ),
            suffixIcon: IconButton(
              tooltip: showPassword ? 'Hide password' : 'Show password',
              icon: Icon(
                showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 17,
                color: NetworkConsole.muted,
              ),
              onPressed: onToggleVisibility,
            ),
          ),
        ),
        const SizedBox(height: 9),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => Column(
            children: [
              _PasswordEstimate(password: value.text),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (policy != null)
                    Expanded(child: policy!)
                  else
                    const Spacer(),
                  NetworkAction(label: 'Cancel', onPressed: onCancel),
                  const SizedBox(width: 8),
                  NetworkAction(
                    key: const ValueKey('network-connect-submit'),
                    label: connecting ? 'Connecting…' : 'Connect',
                    primary: true,
                    enabled: value.text.isNotEmpty && !connecting,
                    onPressed: onSubmit,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              errorMessage!,
              style: NetworkConsole.body.copyWith(
                color: const Color(0xFFFFAC97),
              ),
            ),
          ),
      ],
    ),
  );
}

class _PasswordEstimate extends StatelessWidget {
  const _PasswordEstimate({required this.password});
  final String password;

  @override
  Widget build(BuildContext context) {
    final count = password.isEmpty
        ? 0
        : password.length < 8
        ? 1
        : password.length < 12
        ? 2
        : password.length < 16
        ? 3
        : 4;
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              for (var index = 0; index < 4; index++)
                Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: index == 3 ? 0 : 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: const Color(0xFF292D50),
                      gradient: index < count
                          ? const LinearGradient(
                              colors: [Color(0xFF8546FA), Color(0xFFE0ADFF)],
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 9),
        Text(
          'Password length · ${password.length}',
          style: NetworkConsole.body.copyWith(fontSize: 9),
        ),
      ],
    );
  }
}
