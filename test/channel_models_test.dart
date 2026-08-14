import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/chat/tdlib_chat_info_parser.dart';
import 'package:riogram/models/channel_models.dart';
import 'package:riogram/models/chat_info_models.dart';
import 'package:riogram/models/chat_models.dart';
import 'package:riogram/models/message_enrichment.dart';

void main() {
  group('Channel models and parsers', () {
    test('ChatSummary.isChannelReadOnly для подписчика канала', () {
      const chat = ChatSummary(
        id: 1,
        title: 'News',
        kind: ChatKind.channel,
        canSendMessages: false,
      );
      expect(chat.isChannelReadOnly, isTrue);
    });

    test('ChatDetailInfo.isSubscribed и canSendInChannel', () {
      const adminInfo = ChatDetailInfo(
        chatId: 1,
        myStatus: ChatMemberStatusKind.administrator,
        canPostMessages: true,
        permissions: ChatPermissionsInfo(canSendBasicMessages: false),
      );
      expect(adminInfo.isSubscribed, isTrue);
      expect(adminInfo.canSendInChannel, isTrue);

      const leftInfo = ChatDetailInfo(
        chatId: 1,
        myStatus: ChatMemberStatusKind.left,
      );
      expect(leftInfo.isSubscribed, isFalse);
    });

    test('MessageInteractionInfo парсит reply_count', () {
      final info = MessageInteractionInfo.fromTdlib({
        '@type': 'messageInteractionInfo',
        'view_count': 100,
        'forward_count': 2,
        'reply_info': {
          '@type': 'messageReplyInfo',
          'reply_count': 15,
        },
      });
      expect(info.replyCount, 15);
    });

    test('parseMessageThreadInfo создаёт контекст обсуждения', () {
      final context = TdlibChatInfoParser.parseMessageThreadInfo(
        {
          '@type': 'messageThreadInfo',
          'chat_id': -100200,
          'message_thread_id': 42,
          'unread_message_count': 0,
          'messages': [],
        },
        channelChatId: -100100,
        channelMessageId: 7,
        postPreview: 'Post text',
      );

      expect(context?.discussionChatId, -100200);
      expect(context?.messageThreadId, 42);
      expect(context?.channelMessageId, 7);
      expect(context?.postPreview, 'Post text');
    });

    test('parseSupergroup сохраняет linked chat и canPostMessages', () {
      final info = TdlibChatInfoParser.parseSupergroup(
        {
          '@type': 'supergroup',
          'member_count': 1000,
          'has_linked_chat': true,
          'status': {
            '@type': 'chatMemberStatusAdministrator',
            'can_be_edited': true,
            'rights': {
              '@type': 'chatAdministratorRights',
              'can_post_messages': true,
            },
          },
        },
        chatId: 10,
      );

      expect(info.hasLinkedChat, isTrue);
      expect(info.canPostMessages, isTrue);
    });

    test('ChannelMembershipKind.isSubscribed', () {
      expect(ChannelMembershipKind.subscribed.isSubscribed, isTrue);
      expect(ChannelMembershipKind.notSubscribed.isSubscribed, isFalse);
    });
  });
}
