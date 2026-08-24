import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/call/call_manager.dart';
import '../../models/call_media_models.dart';

/// Выбор аудиоустройств (desktop + mobile).
class CallDevicePickerSheet extends StatelessWidget {
  const CallDevicePickerSheet({super.key});

  static bool get isSupported =>
      !kIsWeb &&
      (Platform.isLinux || Platform.isMacOS || Platform.isWindows);

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (_) => const CallDevicePickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.read<CallManager>();

    return SafeArea(
      child: FutureBuilder<List<CallAudioDevice>>(
        future: manager.listAudioDevices(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final devices = snapshot.data ?? const [];
          final inputs = devices
              .where((device) => device.kind == CallAudioDeviceKind.input)
              .toList();
          final outputs = devices
              .where((device) => device.kind == CallAudioDeviceKind.output)
              .toList();

          return ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text('Аудиоустройства'),
                subtitle: Text('WebRTC / tgcalls'),
              ),
              if (inputs.isEmpty && outputs.isEmpty)
                const ListTile(title: Text('Устройства не найдены')),
              if (inputs.isNotEmpty) ...[
                const ListTile(title: Text('Микрофон')),
                ...inputs.map(
                  (device) => ListTile(
                    leading: const Icon(Icons.mic),
                    title: Text(device.label),
                    onTap: () async {
                      await manager.selectAudioInput(device.id);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
              ],
              if (outputs.isNotEmpty) ...[
                const ListTile(title: Text('Динамики')),
                ...outputs.map(
                  (device) => ListTile(
                    leading: const Icon(Icons.speaker),
                    title: Text(device.label),
                    onTap: () async {
                      await manager.selectAudioOutput(device.id);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
