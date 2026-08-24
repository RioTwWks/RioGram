import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';

import '../../core/call/call_manager.dart';
import '../../core/call/group_call_manager.dart';
import '../../core/call/tdlib_call_parser.dart';
import '../../models/call_models.dart';
import '../../models/group_call_models.dart';
import '../../widgets/chat_avatar.dart';
import '../../widgets/call_device_picker_sheet.dart';

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
    final groupCallManager = context.watch<GroupCallManager>();
    final call = callManager.activeCall;
    final groupCall = groupCallManager.activeCall;

    if (groupCall != null && groupCall.hasActiveCall) {
      return GroupCallScreen(
        call: groupCall,
        manager: groupCallManager,
      );
    }

    if (call == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final name = call.userDisplayName ??
        callManager.displayNameFor(call.userId);
    final status = call.uiPhase == CallUiPhase.active
        ? CallScreen.formatDuration(callManager.callDuration)
        : TdlibCallParser.statusLabel(call);
    final engine = callManager.signalingBridge.mediaEngine;

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
              _VideoPreview(
                enabled: callManager.isVideoEnabled,
                localRenderer: engine?.localRenderer,
                remoteRenderer: engine?.remoteRenderer,
              )
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

class GroupCallScreen extends StatelessWidget {
  const GroupCallScreen({
    super.key,
    required this.call,
    required this.manager,
  });

  final GroupCallSummary call;
  final GroupCallManager manager;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final engine = context.read<CallManager>().signalingBridge.mediaEngine;

    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(call.title, style: theme.textTheme.titleLarge),
                        Text(
                          '${call.participantCount} участников',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  if (manager.lastError != null)
                    Icon(Icons.error_outline, color: theme.colorScheme.error),
                ],
              ),
            ),
            if (engine != null && manager.isVideoEnabled)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: RTCVideoView(engine.localRenderer, mirror: true),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: manager.participants.length,
                  itemBuilder: (context, index) {
                    final participant = manager.participants[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text('${participant.userId % 10}'),
                      ),
                      title: Text(
                        participant.displayName ??
                            'Участник ${participant.userId}',
                      ),
                      subtitle: Text(
                        participant.isSpeaking
                            ? 'Говорит'
                            : participant.isMuted
                                ? 'Без звука'
                                : 'На линии',
                      ),
                      trailing: participant.isHandRaised
                          ? const Icon(Icons.front_hand)
                          : null,
                    );
                  },
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _RoundActionButton(
                  icon: manager.isMuted ? Icons.mic_off : Icons.mic,
                  label: manager.isMuted ? 'Вкл. звук' : 'Без звука',
                  onPressed: manager.toggleMute,
                ),
                if (call.canEnableVideo)
                  _RoundActionButton(
                    icon: manager.isVideoEnabled
                        ? Icons.videocam
                        : Icons.videocam_off,
                    label: manager.isVideoEnabled ? 'Камера' : 'Без видео',
                    onPressed: () => manager.toggleVideo(),
                  ),
                _RoundActionButton(
                  icon: Icons.settings_voice,
                  label: 'Аудио',
                  onPressed: () => CallDevicePickerSheet.show(context),
                ),
                _RoundActionButton(
                  icon: Icons.call_end,
                  label: 'Выйти',
                  color: Colors.red,
                  onPressed: () => manager.leaveGroupCall(),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _VideoPreview extends StatelessWidget {
  const _VideoPreview({
    required this.enabled,
    this.localRenderer,
    this.remoteRenderer,
  });

  final bool enabled;
  final RTCVideoRenderer? localRenderer;
  final RTCVideoRenderer? remoteRenderer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: Colors.black,
                child: remoteRenderer != null &&
                        remoteRenderer!.srcObject != null
                    ? RTCVideoView(remoteRenderer!)
                    : const Center(
                        child: Icon(Icons.person, color: Colors.white24),
                      ),
              ),
              if (enabled && localRenderer != null)
                Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: 96,
                      height: 128,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: RTCVideoView(localRenderer!, mirror: true),
                      ),
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
          onPressed: () => callManager.toggleMute(),
        ),
        if (call.isVideo)
          _RoundActionButton(
            icon: callManager.isVideoEnabled
                ? Icons.videocam
                : Icons.videocam_off,
            label: callManager.isVideoEnabled ? 'Камера' : 'Без видео',
            onPressed: () => callManager.toggleVideo(),
          ),
        _RoundActionButton(
          icon: Icons.settings_voice,
          label: 'Аудио',
          onPressed: () => CallDevicePickerSheet.show(context),
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
