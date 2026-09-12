import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../bindings/bindings.dart';
import 'network_console.dart';
import 'network_password_prompt.dart';

/// Security choices supported by the manual profile boundary.
enum PersonalSecurity { open, personal }

sealed class _Step {
  const _Step();
}

final class _Name extends _Step {
  const _Name([this.error]);
  final String? error;
}

final class _Password extends _Step {
  const _Password([this.error]);
  final String? error;
}

final class _Submitting extends _Step {
  const _Submitting(this.ssid);
  final String ssid;
}

/// The name → credential → confirmation flow for a manually entered network.
///
/// A submission stays pending until a matching active SSID arrives. Native
/// failures and a bounded confirmation deadline return to the editable form.
class NetworkJoinForm extends StatefulWidget {
  const NetworkJoinForm({
    super.key,
    required this.result,
    required this.activeSsid,
    required this.onJoin,
    required this.onCancel,
    required this.onConnected,
  });
  final NetworkCommandResult? result;
  final String? activeSsid;
  final ValueChanged<NetworkJoinRequest> onJoin;
  final VoidCallback onCancel;
  final VoidCallback onConnected;

  @override
  State<NetworkJoinForm> createState() => _NetworkJoinFormState();
}

class _NetworkJoinFormState extends State<NetworkJoinForm> {
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _nameFocus = FocusNode(debugLabel: 'network-name');
  final _passwordFocus = FocusNode(debugLabel: 'manual-network-password');
  _Step _step = const _Name();
  PersonalSecurity _security = PersonalSecurity.personal;
  bool _hidden = true;
  bool _autoConnect = true;
  bool _visible = false;
  Timer? _deadline;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocus.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant NetworkJoinForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_step case _Submitting(:final ssid)) {
      if (widget.activeSsid == ssid) {
        _deadline?.cancel();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onConnected();
        });
      } else if (!identical(oldWidget.result, widget.result)) {
        if (widget.result case NetworkCommandResultFailed(
          command: NetworkCommandConnect(ssid: final target),
          :final message,
        ) when target == ssid) {
          _fail(message);
        }
      }
    }
  }

  void _fail(String message) {
    _deadline?.cancel();
    setState(
      () => _step = _security == PersonalSecurity.open
          ? _Name(message)
          : _Password(message),
    );
  }

  void _continue() {
    final bytes = utf8.encode(_name.text).length;
    if (bytes == 0 || bytes > 32) {
      setState(
        () =>
            _step = const _Name('Network name must contain 1–32 UTF-8 bytes.'),
      );
    } else if (_security == PersonalSecurity.open) {
      _submit();
    } else {
      setState(() => _step = const _Password());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _passwordFocus.requestFocus();
      });
    }
  }

  void _submit() {
    final attempt = _Submitting(_name.text);
    setState(() => _step = attempt);
    _deadline?.cancel();
    _deadline = Timer(const Duration(seconds: 45), () {
      if (mounted && identical(_step, attempt)) {
        _fail(
          'Connection not confirmed. Check the network name and credentials.',
        );
      }
    });
    widget.onJoin(
      NetworkJoinRequest(
        ssid: _name.text,
        hidden: _hidden,
        autoConnect: _autoConnect,
        security: _security == PersonalSecurity.open
            ? const NetworkSecurityOpen()
            : NetworkSecurityPersonal(password: _password.text),
      ),
    );
  }

  @override
  void dispose() {
    _deadline?.cancel();
    _name.dispose();
    _password.dispose();
    _nameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => switch (_step) {
    _Submitting(:final ssid) => NetworkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Connecting to $ssid…',
            style: NetworkConsole.body.copyWith(color: NetworkConsole.text),
          ),
          const SizedBox(height: 12),
          const LinearProgressIndicator(
            minHeight: 2,
            color: NetworkConsole.download,
            backgroundColor: NetworkConsole.line,
          ),
          const SizedBox(height: 8),
          NetworkAction(label: 'Back to networks', onPressed: widget.onCancel),
        ],
      ),
    ),
    _Password(:final error) => NetworkPasswordPrompt(
      leading: Align(
        alignment: Alignment.centerLeft,
        child: NetworkAction(
          label: 'Network name',
          icon: Icons.arrow_back_rounded,
          compact: true,
          onPressed: () => setState(() => _step = const _Name()),
        ),
      ),
      ssid: _name.text,
      subtitle: '${_hidden ? "Hidden network" : "Wi-Fi"} · WPA / WPA2 Personal',
      controller: _password,
      focusNode: _passwordFocus,
      showPassword: _visible,
      connecting: false,
      errorMessage: error,
      onToggleVisibility: () => setState(() => _visible = !_visible),
      onCancel: widget.onCancel,
      onSubmit: _submit,
      policy: NetworkCheck(
        label: 'Auto-connect',
        checked: _autoConnect,
        onChanged: (enabled) => setState(() => _autoConnect = enabled),
      ),
    ),
    _Name(:final error) => NetworkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Join other network',
            style: NetworkConsole.body.copyWith(
              fontSize: 14,
              color: NetworkConsole.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 9),
          const Text('Network name (SSID)'),
          const SizedBox(height: 3),
          TextField(
            controller: _name,
            focusNode: _nameFocus,
            onSubmitted: (_) => _continue(),
            style: NetworkConsole.body.copyWith(color: NetworkConsole.text),
            decoration: InputDecoration(
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
                borderSide: const BorderSide(color: NetworkConsole.download),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Security'),
          const SizedBox(height: 3),
          _SecurityField(
            value: _security,
            onChanged: (security) => setState(() => _security = security),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: NetworkCheck(
                  label: 'Hidden network',
                  checked: _hidden,
                  onChanged: (hidden) => setState(() => _hidden = hidden),
                ),
              ),
              NetworkAction(
                label: 'Cancel',
                compact: true,
                onPressed: widget.onCancel,
              ),
              const SizedBox(width: 4),
              NetworkAction(
                label: _security == PersonalSecurity.open
                    ? 'Connect'
                    : 'Continue',
                trailing: Icons.arrow_forward_rounded,
                primary: true,
                onPressed: _continue,
              ),
            ],
          ),
          if (error != null)
            Text(
              error,
              style: NetworkConsole.body.copyWith(
                color: const Color(0xFFFFAC97),
              ),
            ),
        ],
      ),
    ),
  };
}

/// Inline disclosure keeps every option inside the native popover hit region.
class _SecurityField extends StatefulWidget {
  const _SecurityField({required this.value, required this.onChanged});
  final PersonalSecurity value;
  final ValueChanged<PersonalSecurity> onChanged;
  @override
  State<_SecurityField> createState() => _SecurityFieldState();
}

class _SecurityFieldState extends State<_SecurityField> {
  bool _expanded = false;
  String _label(PersonalSecurity value) => switch (value) {
    PersonalSecurity.personal => 'WPA / WPA2 Personal',
    PersonalSecurity.open => 'Open network',
  };
  @override
  Widget build(BuildContext context) => NetworkCard(
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NetworkAction(
          label: _label(widget.value),
          trailing: _expanded
              ? Icons.expand_less_rounded
              : Icons.expand_more_rounded,
          onPressed: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded)
          for (final security in PersonalSecurity.values)
            NetworkAction(
              label: _label(security),
              icon: security == widget.value ? Icons.check_rounded : null,
              onPressed: () {
                widget.onChanged(security);
                setState(() => _expanded = false);
              },
            ),
      ],
    ),
  );
}
