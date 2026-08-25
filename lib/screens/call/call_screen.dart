import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';

import '../../core/call/call_manager.dart';
import '../../core/call/group_call_manager.dart';
import '../../core/call/tdlib_call_parser.dart';
import '../../core/chat/chat_manager.dart';
import '../../core/theme/telegram_theme.dart';
import '../../core/user/profile_manager.dart';
import '../../models/call_models.dart';
import '../../models/group_call_models.dart';
import '../../widgets/call_incoming_background.dart';
import '../../widgets/chat_avatar.dart';
import '../../widgets/call_device_picker_sheet.dart';

/// Экран активного или входящего звонка (§9.8).
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

    final name = call.userDisplayName ?? callManager.displayNameFor(call.userId);
    final status = call.uiPhase == CallUiPhase.active
        ? CallScreen.formatDuration(callManager.callDuration)
        : TdlibCallParser.statusLabel(call);
    final engine = callManager.signalingBridge.mediaEngine;
    final isIncoming = call.isIncomingRinging;

    final avatarPath = isIncoming ? _avatarPathForUser(context, call.userId) : null;
    return Stack(fit: StackFit.expand, children: [
      if (isIncoming) CallIncomingBackground(title: name, avatarLocalPath: avatarPath, colorKey: '${call.userId}') else const ColoredBox(color: TelegramColors.callBackground),
      SafeArea(
        child: Column(
          children: [
            if (!isIncoming) ...[
              const SizedBox(height: 24),
              Text(
                call.isVideo ? 'Видеозвонок' : 'Звонок',
                style: TextStyle(
                  color: TelegramColors.callTextSecondary,
                  fontSize: TelegramFontSizes.preview,
                ),
              ),
            ],
            const Spacer(),
            if (call.isVideo && call.uiPhase == CallUiPhase.active)
              _VideoPreview(
                enabled: callManager.isVideoEnabled,
                localRenderer: engine?.localRenderer,
                remoteRenderer: engine?.remoteRenderer,
              )
            else
              ChatAvatar(title: name, localPath: avatarPath, colorKey: '${call.userId}', radius: TelegramSpacing.callAvatarRadius),
            const SizedBox(height: 24),
            Text(
              name,
              style: const TextStyle(
                color: TelegramColors.callTextPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              status,
              style: const TextStyle(
                color: TelegramColors.callTextSecondary,
                fontSize: TelegramFontSizes.preview,
              ),
            ),
            if (callManager.lastError != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  callManager.lastError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: TelegramFontSizes.chatSubtitle,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const Spacer(),
            if (isIncoming)
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
    ]);
  }
  static String? _avatarPathForUser(BuildContext c, int id) {
    final p = c.read<ProfileManager>().userById(id);
    if (p?.avatarLocalPath?.isNotEmpty == true) return p!.avatarLocalPath;
    for (final chat in c.read<ChatManager>().chats) { if (chat.privateUserId == id) return chat.avatarLocalPath; }
    return null;
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
    final engine = context.read<CallManager>().signalingBridge.mediaEngine;

    return Stack(fit: StackFit.expand, children: [
      const ColoredBox(color: TelegramColors.callBackground),
      SafeArea(
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
                        Text(
                          call.title,
                          style: const TextStyle(
                            color: TelegramColors.callTextPrimary,
                            fontSize: TelegramFontSizes.chatTitle,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${call.participantCount} участников',
                          style: const TextStyle(
                            color: TelegramColors.callTextSecondary,
                            fontSize: TelegramFontSizes.preview,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (manager.lastError != null)
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                ],
              ),
            ),
            if (engine != null && manager.isVideoEnabled)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(TelegramRadii.mediaPreview),
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
                        backgroundColor: TelegramColors.callControlBackground,
                        foregroundColor: TelegramColors.callTextPrimary,
                        child: Text('${participant.userId % 10}'),
                      ),
                      title: Text(
                        participant.displayName ??
                            'Участник ${participant.userId}',
                        style: const TextStyle(
                          color: TelegramColors.callTextPrimary,
                        ),
                      ),
                      subtitle: Text(
                        participant.isSpeaking
                            ? 'Говорит'
                            : participant.isMuted
                                ? 'Без звука'
                                : 'На линии',
                        style: const TextStyle(
                          color: TelegramColors.callTextSecondary,
                        ),
                      ),
                      trailing: participant.isHandRaised
                          ? const Icon(
                              Icons.front_hand,
                              color: TelegramColors.callTextPrimary,
                            )
                          : null,
                    );
                  },
                ),
              ),
            _GroupCallControlsRow(call: call, manager: manager),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ]);
  }
}

class _GroupCallControlsRow extends StatelessWidget {
  const _GroupCallControlsRow({required this.call, required this.manager});

  final GroupCallSummary call;
  final GroupCallManager manager;

  @override
  Widget build(BuildContext context) {
    final controls = <Widget>[
      _CallRoundButton(
        icon: manager.isMuted ? Icons.mic_off : Icons.mic,
        label: manager.isMuted ? 'Вкл. звук' : 'Без звука',
        onPressed: manager.toggleMute,
      ),
      if (call.canEnableVideo)
        _CallRoundButton(
          icon: manager.isVideoEnabled ? Icons.videocam : Icons.videocam_off,
          label: manager.isVideoEnabled ? 'Камера' : 'Без видео',
          onPressed: () => manager.toggleVideo(),
        ),
      _CallRoundButton(
        icon: Icons.settings_voice,
        label: 'Аудио',
        onPressed: () => CallDevicePickerSheet.show(context),
      ),
      _CallRoundButton(
        icon: Icons.call_end,
        label: 'Выйти',
        backgroundColor: TelegramColors.callDeclineRed,
        iconColor: TelegramColors.callTextPrimary,
        onPressed: () => manager.leaveGroupCall(),
      ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < controls.length; i++) ...[
          if (i > 0) const SizedBox(width: TelegramSpacing.callControlSpacing),
          controls[i],
        ],
      ],
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
          borderRadius: BorderRadius.circular(TelegramRadii.bubble),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: TelegramColors.callBackground,
                child: remoteRenderer != null &&
                        remoteRenderer!.srcObject != null
                    ? RTCVideoView(remoteRenderer!)
                    : const Center(
                        child: Icon(
                          Icons.person,
                          color: TelegramColors.callControlBackground,
                          size: 64,
                        ),
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
                        borderRadius:
                            BorderRadius.circular(TelegramRadii.mediaPreview),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CallRoundButton(
            icon: Icons.call_end,
            label: 'Отклонить',
            backgroundColor: TelegramColors.callDeclineRed,
            iconColor: TelegramColors.callTextPrimary,
            size: TelegramSpacing.callPrimaryButtonSize,
            onPressed: callManager.declineCall,
          ),
          const SizedBox(width: TelegramSpacing.callControlSpacing * 2),
          _PulsingAcceptButton(onPressed: callManager.acceptCall),
        ],
      ),
    );
  }
}

class _PulsingAcceptButton extends StatefulWidget {
  const _PulsingAcceptButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_PulsingAcceptButton> createState() => _PulsingAcceptButtonState();
}

class _PulsingAcceptButtonState extends State<_PulsingAcceptButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1 + (_controller.value * 0.35);
        final opacity = 0.45 * (1 - _controller.value);
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: TelegramSpacing.callPrimaryButtonSize * scale,
              height: TelegramSpacing.callPrimaryButtonSize * scale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TelegramColors.callAcceptGreen.withValues(alpha: opacity),
              ),
            ),
            child!,
          ],
        );
      },
      child: _CallRoundButton(
        icon: Icons.call,
        label: 'Принять',
        backgroundColor: TelegramColors.callAcceptGreen,
        iconColor: TelegramColors.callTextPrimary,
        size: TelegramSpacing.callPrimaryButtonSize,
        onPressed: widget.onPressed,
      ),
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
    final buttons = <Widget>[
      _CallRoundButton(
        icon: callManager.isMuted ? Icons.mic_off : Icons.mic,
        label: callManager.isMuted ? 'Вкл. звук' : 'Без звука',
        onPressed: () => callManager.toggleMute(),
      ),
      if (call.isVideo)
        _CallRoundButton(
          icon: callManager.isVideoEnabled
              ? Icons.videocam
              : Icons.videocam_off,
          label: callManager.isVideoEnabled ? 'Камера' : 'Без видео',
          onPressed: () => callManager.toggleVideo(),
        ),
      _CallRoundButton(
        icon: Icons.settings_voice,
        label: 'Аудио',
        onPressed: () => CallDevicePickerSheet.show(context),
      ),
      _CallRoundButton(
        icon: Icons.call_end,
        label: 'Завершить',
        backgroundColor: TelegramColors.callDeclineRed,
        iconColor: TelegramColors.callTextPrimary,
        onPressed: callManager.hangUp,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: TelegramSpacing.callControlSpacing),
            buttons[i],
          ],
        ],
      ),
    );
  }
}

class _CallRoundButton extends StatelessWidget {
  const _CallRoundButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.size,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final buttonSize = size ?? TelegramSpacing.callControlButtonSize;
    final bg = backgroundColor ?? TelegramColors.callControlBackground;
    final fg = iconColor ?? TelegramColors.callTextPrimary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: bg,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: buttonSize,
              height: buttonSize,
              child: Icon(icon, color: fg, size: buttonSize * 0.4),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: TelegramColors.callTextSecondary,
            fontSize: TelegramFontSizes.chatSubtitle,
          ),
        ),
      ],
    );
  }
}
