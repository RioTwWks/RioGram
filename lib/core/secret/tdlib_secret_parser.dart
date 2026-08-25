import '../../models/secret_chat_models.dart';

/// Парсинг секретных чатов TDLib.
class TdlibSecretParser {
  static SecretChatSummary parseSecretChat(Map<String, dynamic> json) {
    return SecretChatJson.parseSecretChat(json);
  }
}
