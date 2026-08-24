import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/call/call_manager.dart';
import '../../core/call/tdlib_call_parser.dart';
import '../../models/call_models.dart';
import '../../widgets/chat_avatar.dart';

/// Экран активного или входящего звонка.
class CallScreen extends StatelessWidget {
  const CallScreen({super.key});

  static String formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final callManager = context.watch<CallManager>();
    final call = callManager.activeCall;
    if (call == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final name = call.userDisplayName ??
        callManager.displayNameFor(call.userId);
    final status = call.uiPhase == CallUiPhase.active
        ? CallScreen.formatDuration(callManager.callDuration)
        : TdlibCallParser.statusLabel(call);

    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Text(
              call.isVideo ? 'Видеозвонок' : 'Звонок',
              style: theme.textTheme.titleMedium,
            ),
            const Spacer(),
            if (call.isVideo && call.uiPhase == CallUiPhase.active)
              _VideoPreview(enabled: callManager.isVideoEnabled)
            else
              ChatAvatar(
                title: name,
                radius: 56,
              ),
            const SizedBox(height: 24),
            Text(
              name,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              status,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (callManager.lastError != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  callManager.lastError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const Spacer(),
            if (call.isIncomingRinging)
              _IncomingControls(callManager: callManager)
            else if (!call.isEnded)
              _ActiveControls(
                callManager: callManager,
                call: call,
              )
            else
              const SizedBox(height: 96),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _VideoPreview extends StatelessWidget {
  const _VideoPreview({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  enabled ? Icons.videocam : Icons.videocam_off,
                  size: 48,
                  color: Colors.white70,
                ),
                const SizedBox(height: 8),
                Text(
                  enabled ? 'Камера включена' : 'Камера выключена',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Медиа через tgcalls/WebRTC',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IncomingControls extends StatelessWidget {
  const _IncomingControls({required this.callManager});

  final CallManager callManager;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RoundActionButton(
          icon: Icons.call_end,
          label: 'Отклонить',
          color: Colors.red,
          onPressed: callManager.declineCall,
        ),
        _RoundActionButton(
          icon: Icons.call,
          label: 'Принять',
          color: Colors.green,
          onPressed: callManager.acceptCall,
        ),
      ],
    );
  }
}

class _ActiveControls extends StatelessWidget {
  const _ActiveControls({
    required this.callManager,
    required this.call,
  });

  final CallManager callManager;
  final CallSummary call;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RoundActionButton(
          icon: callManager.isMuted ? Icons.mic_off : Icons.mic,
          label: callManager.isMuted ? 'Вкл. звук' : 'Без звука',
          onPressed: callManager.toggleMute,
        ),
        if (call.isVideo)
          _RoundActionButton(
            icon: callManager.isVideoEnabled
                ? Icons.videocam
                : Icons.videocam_off,
            label: callManager.isVideoEnabled ? 'Камера' : 'Без видео',
            onPressed: callManager.toggleVideo,
          ),
        _RoundActionButton(
          icon: Icons.call_end,
          label: 'Завершить',
          color: Colors.red,
          onPressed: callManager.hangUp,
        ),
      ],
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = color ?? theme.colorScheme.surfaceContainerHighest;
    final fg = color != null ? Colors.white : theme.colorScheme.onSurface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: bg,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: 64,
              height: 64,
              child: Icon(icon, color: fg),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: theme.textTheme.labelMedium),
      ],
    );
  }
}
