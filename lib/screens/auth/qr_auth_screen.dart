import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/auth/auth_manager.dart';

/// QR-вход: показ tg://-ссылки для сканирования с другого устройства.
class QrAuthScreen extends StatelessWidget {
  const QrAuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthManager>();
    final link = auth.qrConfirmationLink;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Вход по QR-коду'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Откройте Telegram на другом устройстве',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Настройки → Устройства → Подключить устройство → '
              'Отсканируйте этот QR-код.',
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Center(
                child: link == null || link.isEmpty
                    ? const CircularProgressIndicator()
                    : AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: QrImageView(
                            data: link,
                            version: QrVersions.auto,
                          ),
                        ),
                      ),
              ),
            ),
            if (auth.errorMessage != null) ...[
              Text(
                auth.errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton(
              onPressed: auth.isAuthRequestInProgress
                  ? null
                  : auth.requestQrCodeAuthentication,
              child: const Text('Обновить QR-код'),
            ),
          ],
        ),
      ),
    );
  }
}
