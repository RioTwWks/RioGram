import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/security/app_lock_manager.dart';

/// Экран разблокировки поверх приложения.
class AppLockOverlay extends StatefulWidget {
  const AppLockOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<AppLockOverlay> createState() => _AppLockOverlayState();
}

class _AppLockOverlayState extends State<AppLockOverlay> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<AppLockManager>();

    return Listener(
      onPointerDown: (_) => lock.recordActivity(),
      child: Stack(
        children: [
          widget.child,
          if (lock.passcodeEnabled && lock.isLocked)
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'RioGram заблокирован',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _controller,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'PIN',
                          errorText: _error,
                          border: const OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _unlockWithPin(lock),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => _unlockWithPin(lock),
                        child: const Text('Разблокировать'),
                      ),
                      if (lock.canUseBiometrics) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final ok = await lock.unlockWithBiometrics();
                            if (!ok && mounted) {
                              setState(() => _error = 'Биометрия не сработала');
                            }
                          },
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('Биометрия'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _unlockWithPin(AppLockManager lock) async {
    final ok = await lock.unlockWithPasscode(_controller.text);
    if (!mounted) {
      return;
    }
    if (ok) {
      setState(() {
        _error = null;
        _controller.clear();
      });
    } else {
      setState(() => _error = 'Неверный PIN');
    }
  }
}
