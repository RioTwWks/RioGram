import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/bot/bot_manager.dart';
import '../../core/call/call_manager.dart';
import '../../core/call/group_call_manager.dart';
import '../../core/chat/chat_manager.dart';
import '../../core/features/riogram_features_manager.dart';
import '../../core/user/profile_manager.dart';
import '../../core/secret/secret_chat_manager.dart';
import '../../core/theme/ui_customization_manager.dart';
import '../../widgets/message_swipe_wrapper.dart';
import '../../widgets/chat_wallpaper.dart';
import '../../widgets/scroll_to_bottom_button.dart';
import '../../widgets/message_bubble_grouping.dart';
import '../../widgets/date_separator.dart';
import '../../widgets/chat_app_bar_title.dart';
import '../../models/secret_chat_models.dart';
import '../../core/theme/telegram_icons.dart';
import '../../core/theme/telegram_theme.dart';
import '../../models/bot_models.dart';
import '../../models/message_enrichment.dart';
import '../../models/call_models.dart';
import '../../models/channel_models.dart';
import '../../models/chat_models.dart';
import '../../models/formatted_text.dart';
import '../../models/media_models.dart';
import '../../models/location_models.dart';
import '../../widgets/channel_status_bar.dart';
import '../../widgets/forward_messages_dialog.dart';
import '../../widgets/media_attach_sheet.dart';
import '../../widgets/location_picker_sheet.dart';
import '../../widgets/bot_command_menu.dart';
import '../../widgets/inline_query_results_sheet.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/message_input_bar.dart';
import '../../widgets/message_reactions_row.dart';
import '../../widgets/riogram_features_widgets.dart';
import '../../widgets/poll_message_body.dart';
import '../../widgets/voice_recorder_sheet.dart';
import 'media_viewer_screen.dart';
import 'chat_message_search_screen.dart';
import 'chat_info_screen.dart';
import 'message_thread_screen.dart';
import '../webapp/web_app_screen.dart';
import '../../core/navigation/telegram_routes.dart';

/// Экран переписки: форматирование, ответ, пересылка, редактирование, удаление.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.chatId,
    this.closeOnDispose = true,
    this.forumTopicId,
    this.forumTopicName,
    this.onBackToTopics,
  });

  final int chatId;
  final bool closeOnDispose;
  final int? forumTopicId;
  final String? forumTopicName;
  final VoidCallback? onBackToTopics;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _typingTimer;
  var _isSubscribing = false;
  BotManager? _botManager;
  int _lastShownInlineQueryId = 0;
  static const _scrollBottomThreshold = 80.0;
  int _lastMessageCount = 0;
  int _newMessagesBelow = 0;
  bool _initialScrollDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final manager = context.read<ChatManager>();
      _botManager = context.read<BotManager>();
      _botManager!.addListener(_onBotManagerChanged);
      if (widget.forumTopicId != null) {
        if (manager.activeForumTopicId != widget.forumTopicId ||
            manager.activeChatId != widget.chatId) {
          manager.openForumTopic(
            widget.chatId,
            widget.forumTopicId!,
            topicName: widget.forumTopicName,
          );
        }
        return;
      }
      if (manager.activeChatId != widget.chatId) {
        manager.openChat(widget.chatId);
      }
      _loadCallCapabilities(manager);
      _loadPrivateUserProfile(manager);
      _loadSecretChatState(manager);
    });
    _controller.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);
  }

  void _loadSecretChatState(ChatManager chatManager) {
    final chat = chatManager.chatById(widget.chatId);
    if (chat?.kind != ChatKind.secret || chat?.secretChatId == null) {
      return;
    }
    context.read<SecretChatManager>().loadSecretChat(chat!.secretChatId!);
  }

  void _onBotManagerChanged() {
    final bot = _botManager;
    if (bot == null || !mounted) {
      return;
    }

    final answer = bot.lastCallbackAnswer;
    if (answer != null) {
      bot.clearLastCallbackAnswer();
      if (answer.showAlert && answer.text.isNotEmpty) {
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(answer.text),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else if (answer.text.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(answer.text)),
        );
      }
      if (answer.url.isNotEmpty) {
        TelegramRoutes.push(context, WebAppScreen(url: answer.url, launchId: 0, title: 'Бот'));
      }
    }

    final webUrl = bot.pendingWebAppUrl;
    final launchId = bot.pendingWebAppLaunchId;
    if (webUrl != null && launchId != null) {
      bot.clearPendingWebApp();
      TelegramRoutes.push(context, WebAppScreen(url: webUrl, launchId: launchId, title: 'Mini App'));
    }

    final inline = bot.inlineQueryState;
    if (inline.queryId != 0 &&
        inline.queryId != _lastShownInlineQueryId &&
        inline.isActive &&
        !inline.isLoading &&
        inline.results.isNotEmpty) {
      _lastShownInlineQueryId = inline.queryId;
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => InlineQueryResultsSheet(
          chatId: widget.chatId,
          state: inline,
        ),
      );
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _botManager?.removeListener(_onBotManagerChanged);
    _controller
      ..removeListener(_onTextChanged)
      ..dispose();
    _scrollController.dispose();
    if (widget.closeOnDispose) {
      context.read<ChatManager>().closeChat();
    }
    super.dispose();
  }

  void _loadCallCapabilities(ChatManager chatManager) {
    if (widget.forumTopicId != null) {
      return;
    }
    final chat = chatManager.activeChat;
    final userId = chat?.privateUserId;
    if (userId == null || chat?.kind != ChatKind.privateChat) {
      return;
    }
    context.read<CallManager>().loadUserCallCapabilities(userId);
  }

  void _loadPrivateUserProfile(ChatManager chatManager) {
    if (widget.forumTopicId != null) {
      return;
    }
    final chat = chatManager.activeChat;
    final userId = chat?.privateUserId;
    if (userId == null ||
        (chat?.kind != ChatKind.privateChat && chat?.kind != ChatKind.bot)) {
      return;
    }
    context.read<ProfileManager>().loadUserProfile(userId);
  }

  Future<void> _startCall({required bool isVideo}) async {
    final chatManager = context.read<ChatManager>();
    final callManager = context.read<CallManager>();
    final chat = chatManager.activeChat;
    final userId = chat?.privateUserId;
    if (userId == null) {
      return;
    }
    await callManager.startOutgoingCall(
      userId: userId,
      isVideo: isVideo,
      displayName: chat?.title,
    );
  }

  Future<void> _startGroupCall({required bool isVideo}) async {
    final chatManager = context.read<ChatManager>();
    final groupCallManager = context.read<GroupCallManager>();
    final chat = chatManager.activeChat;
    if (chat == null) {
      return;
    }
    await groupCallManager.startVideoChat(
      chatId: widget.chatId,
      title: chat.title,
      isVideo: isVideo,
    );
  }

  void _onTextChanged() {
    final text = _controller.text;
    final chatManager = context.read<ChatManager>();
    final botManager = context.read<BotManager>();
    final profileManager = context.read<ProfileManager>();

    botManager.handleComposerText(
      text: text,
      chatId: widget.chatId,
    );

    final chat = chatManager.activeChat;
    final userId = chat?.privateUserId;
    if (userId != null && chat?.kind == ChatKind.bot) {
      final user = profileManager.userById(userId);
      if (user?.username != null) {
        botManager.registerUsername(user!.username!, userId);
      }
      final fullInfo = profileManager.fullInfoFor(userId);
      if (fullInfo != null) {
        botManager.cacheBotInfo(userId, fullInfo.botInfo);
      }
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(milliseconds: 400), () {
      if (_controller.text.trim().isNotEmpty &&
          context.read<ChatManager>().editingMessage == null) {
        context.read<ChatManager>().sendTypingAction();
      }
    });
  }

  void _sendMessage() {
    final text = _controller.text;
    if (text.trim().isEmpty) {
      return;
    }
    context.read<ChatManager>().sendText(text);
    _controller.clear();
    _scrollToBottom();
  }

  void _handleInlineButton({
    required ChatManager chatManager,
    required BotManager botManager,
    required ChatMessage message,
    required InlineKeyboardButtonModel button,
  }) {
    final chat = chatManager.activeChat;
    final botUserId = chat?.privateUserId ?? message.senderUserId ?? 0;
    botManager.pressInlineButton(
      chatId: widget.chatId,
      messageId: message.id,
      button: button,
      botUserId: botUserId,
    );
  }

  void _clearComposer({bool clearText = true}) {
    if (clearText) {
      _controller.clear();
    }
    final manager = context.read<ChatManager>();
    manager.cancelEditing();
    manager.clearReply();
    manager.clearScheduledSendAt();
  }

  Future<void> _attachMedia() async {
    final action = await MediaAttachSheet.show(context);
    if (action == null || !mounted) {
      return;
    }

    final manager = context.read<ChatManager>();
    switch (action) {
      case MediaAttachAction.photoCompressed:
        final photo = await FilePicker.platform.pickFiles(type: FileType.image);
        final photoPath = photo?.files.single.path;
        if (photoPath != null) {
          await manager.sendPhoto(photoPath);
        }
      case MediaAttachAction.photoAsFile:
        final photoFile = await FilePicker.platform.pickFiles(type: FileType.image);
        final photoFilePath = photoFile?.files.single.path;
        if (photoFilePath != null) {
          await manager.sendDocument(photoFilePath);
        }
      case MediaAttachAction.videoCompressed:
        final video = await FilePicker.platform.pickFiles(type: FileType.video);
        final videoPath = video?.files.single.path;
        if (videoPath != null) {
          await manager.sendVideo(videoPath);
        }
      case MediaAttachAction.videoAsFile:
        final videoFile = await FilePicker.platform.pickFiles(type: FileType.video);
        final videoFilePath = videoFile?.files.single.path;
        if (videoFilePath != null) {
          await manager.sendDocument(videoFilePath);
        }
      case MediaAttachAction.videoNote:
        final note = await FilePicker.platform.pickFiles(type: FileType.video);
        final notePath = note?.files.single.path;
        if (notePath != null) {
          await manager.sendVideoNote(notePath);
        }
      case MediaAttachAction.album:
        final album = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          type: FileType.media,
        );
        final paths = album?.files
                .map((file) => file.path)
                .whereType<String>()
                .toList() ??
            [];
        if (paths.isNotEmpty) {
          await manager.sendMediaAlbum(paths);
        }
      case MediaAttachAction.document:
        final doc = await FilePicker.platform.pickFiles();
        final docPath = doc?.files.single.path;
        if (docPath != null) {
          await manager.sendDocument(docPath);
        }
      case MediaAttachAction.audio:
        final audio = await FilePicker.platform.pickFiles(type: FileType.audio);
        final audioPath = audio?.files.single.path;
        if (audioPath != null) {
          await manager.sendAudio(audioPath);
        }
      case MediaAttachAction.location:
        await _sendLocation(LocationSendMode.staticPoint);
      case MediaAttachAction.liveLocation:
        await _sendLocation(LocationSendMode.liveLocation);
      case MediaAttachAction.venue:
        await _sendLocation(LocationSendMode.venue);
    }
  }

  Future<void> _sendLocation(LocationSendMode mode) async {
    final request = await LocationPickerSheet.show(
      context,
      initialMode: mode,
    );
    if (request == null || !mounted) {
      return;
    }
    await context.read<ChatManager>().sendLocationRequest(request);
  }

  void _onStickerPanelChanged(bool open) {
    final chatManager = context.read<ChatManager>();
    if (open) {
      chatManager.sendChatAction(OutgoingChatAction.choosingSticker);
    } else {
      chatManager.sendChatAction(OutgoingChatAction.cancel);
    }
  }

  Future<void> _recordVoice() async {
    final manager = context.read<ChatManager>();
    manager.sendChatAction(OutgoingChatAction.recordingVoice);
    final result = await VoiceRecorderSheet.show(context);
    manager.sendChatAction(OutgoingChatAction.cancel);
    if (result == null || !mounted) {
      return;
    }
    await manager.sendVoiceNote(
      path: result.path,
      durationSeconds: result.durationSeconds,
      waveform: result.waveform,
    );
  }

  void _openMediaViewer(ChatMessage anchor) {
    final manager = context.read<ChatManager>();
    manager.openMessageContentIfAllowed(anchor.chatId, anchor.id);
    final items = manager.messages
        .where((message) => MediaAlbumGrouper.isMediaKind(message.content.kind))
        .map(MediaViewerItem.fromMessage)
        .where((item) => item.hasLocalFile)
        .toList();
    if (items.isEmpty) {
      return;
    }

    var initialIndex = items.indexWhere((item) => item.messageId == anchor.id);
    if (initialIndex < 0) {
      initialIndex = 0;
    }

    TelegramRoutes.fade(context, MediaViewerScreen(items: items, initialIndex: initialIndex));
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) {
      return;
    }

    final scheduled = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    context.read<ChatManager>().setScheduledSendAt(scheduled);
  }

  Future<void> _createPoll() async {
    final data = await PollComposeDialog.show(context);
    if (data == null || !mounted) {
      return;
    }
    context.read<ChatManager>().sendPoll(
          question: data.question,
          options: data.options,
          kind: data.kind,
          correctOptionId: data.correctOptionId,
        );
  }

  Future<void> _addReactionToMessage(ChatMessage message) async {
    final emoji = await ReactionPickerSheet.show(context);
    if (emoji == null || !mounted) {
      return;
    }
    context.read<ChatManager>().addMessageReaction(message.id, emoji);
  }

  Future<void> _showMessageMenu(ChatMessage message) async {
    final manager = context.read<ChatManager>();
    final canEdit = message.canEditText || message.canEditCaption;
    final hasMedia = message.mediaFileId != null;
    final hasLocalMedia = message.localFilePath != null;
    final locationInfo = message.content.locationInfo;
    final isActiveLiveBroadcast =
        manager.activeLiveLocationMessageId == message.id;
    final canManageLiveLocation = message.isOutgoing &&
        message.content.kind == MessageKind.liveLocation &&
        locationInfo != null &&
        !locationInfo.isExpired;

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.content.kind == MessageKind.text ||
                (message.content.caption?.isNotEmpty ?? false))
              ListTile(
                leading: const Icon(Icons.translate),
                title: const Text('Перевести'),
                onTap: () => Navigator.pop(context, 'translate'),
              ),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Ответить'),
              onTap: () => Navigator.pop(context, 'reply'),
            ),
            ListTile(
              leading: const Icon(Icons.add_reaction_outlined),
              title: const Text('Реакция'),
              onTap: () => Navigator.pop(context, 'react'),
            ),
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.edit),
                title: Text(
                  message.canEditCaption && !message.canEditText
                      ? 'Редактировать подпись'
                      : 'Редактировать',
                ),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
            ListTile(
              leading: const Icon(Icons.forward),
              title: const Text('Переслать'),
              onTap: () => Navigator.pop(context, 'forward'),
            ),
            ListTile(
              leading: const Icon(Icons.checklist),
              title: const Text('Выбрать'),
              onTap: () => Navigator.pop(context, 'select'),
            ),
            if (hasMedia && !hasLocalMedia)
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Скачать'),
                onTap: () => Navigator.pop(context, 'download'),
              ),
            if (hasLocalMedia)
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined),
                title: const Text('Удалить из кэша'),
                onTap: () => Navigator.pop(context, 'delete_cache'),
              ),
            if (message.canBePinned)
              ListTile(
                leading: Icon(
                  message.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                ),
                title: Text(message.isPinned ? 'Открепить' : 'Закрепить'),
                onTap: () => Navigator.pop(
                  context,
                  message.isPinned ? 'unpin' : 'pin',
                ),
              ),
            if (message.canBeDeletedOnlyForSelf)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Удалить у себя'),
                onTap: () => Navigator.pop(context, 'delete_self'),
              ),
            if (message.canBeDeletedForAllUsers)
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined),
                title: const Text('Удалить для всех'),
                onTap: () => Navigator.pop(context, 'delete_all'),
              ),
            if (message.schedulingInfo != null)
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Изменить время отправки'),
                onTap: () => Navigator.pop(context, 'reschedule'),
              ),
            if (canManageLiveLocation && !isActiveLiveBroadcast)
              ListTile(
                leading: const Icon(Icons.my_location),
                title: const Text('Транслировать GPS'),
                onTap: () => Navigator.pop(context, 'live_start'),
              ),
            if (canManageLiveLocation && isActiveLiveBroadcast)
              ListTile(
                leading: const Icon(Icons.location_disabled),
                title: const Text('Остановить трансляцию'),
                onTap: () => Navigator.pop(context, 'live_stop'),
              ),
            if (canManageLiveLocation)
              ListTile(
                leading: const Icon(Icons.stop_circle_outlined),
                title: const Text('Прекратить sharing'),
                onTap: () => Navigator.pop(context, 'live_end'),
              ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case 'translate':
        final targetLanguage =
            context.read<RioGramMediaFeaturesManager>().translatorTargetLanguage;
        await MessageTranslationSheet.show(
          context,
          message: message,
          targetLanguage: targetLanguage,
        );
      case 'reply':
        _clearComposer();
        manager.setReplyToMessage(message);
      case 'react':
        await _addReactionToMessage(message);
      case 'edit':
        _clearComposer(clearText: false);
        _controller.text = message.editableComposerText ?? '';
        _controller.selection = TextSelection.collapsed(
          offset: _controller.text.length,
        );
        manager.startEditingMessage(message);
      case 'forward':
        manager.enterSelectionMode(initialMessageId: message.id);
        await _forwardSelected();
      case 'select':
        manager.enterSelectionMode(initialMessageId: message.id);
      case 'download':
        manager.downloadMessageMedia(message);
      case 'delete_cache':
        manager.deleteMessageFromCache(message);
      case 'pin':
        manager.pinChatMessage(widget.chatId, message.id);
      case 'unpin':
        manager.unpinChatMessage(widget.chatId, message.id);
      case 'delete_self':
        manager.deleteMessage(message.id, revoke: false);
      case 'delete_all':
        final confirmed = await _confirmDeleteForAll(1);
        if (confirmed && mounted) {
          manager.deleteMessage(message.id, revoke: true);
        }
      case 'reschedule':
        await _rescheduleMessage(message);
      case 'live_start':
        final started = await manager.startLiveLocationBroadcast(message.id);
        if (mounted && !started) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось начать трансляцию GPS')),
          );
        }
      case 'live_stop':
        manager.stopLiveLocationBroadcast();
      case 'live_end':
        manager.stopLiveLocation(message.id);
    }
  }

  Future<bool> _confirmDeleteForAll(int count) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить для всех?'),
        content: Text(
          count == 1
              ? 'Сообщение будет удалено у всех участников чата.'
              : 'Выбранные сообщения ($count) будут удалены у всех участников.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteSelected() async {
    final manager = context.read<ChatManager>();
    if (manager.selectedMessageCount == 0) {
      return;
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (manager.canDeleteSelectedForSelf)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Удалить у себя'),
                onTap: () => Navigator.pop(context, 'self'),
              ),
            if (manager.canDeleteSelectedForAll)
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined),
                title: const Text('Удалить для всех'),
                onTap: () => Navigator.pop(context, 'all'),
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Отмена'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) {
      return;
    }

    if (action == 'all') {
      final confirmed = await _confirmDeleteForAll(manager.selectedMessageCount);
      if (!confirmed || !mounted) {
        return;
      }
      manager.deleteSelectedMessages(revoke: true);
    } else if (action == 'self') {
      manager.deleteSelectedMessages(revoke: false);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сообщения удалены')),
      );
    }
  }

  Future<void> _rescheduleMessage(ChatMessage message) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: message.schedulingInfo is MessageSchedulingAtDate
          ? (message.schedulingInfo! as MessageSchedulingAtDate).sendAt
          : now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) {
      return;
    }

    final scheduled = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    context.read<ChatManager>().rescheduleMessage(
          message.chatId,
          message.id,
          scheduled,
        );
  }

  Future<void> _forwardSelected() async {
    final manager = context.read<ChatManager>();
    if (manager.selectedMessageCount == 0) {
      return;
    }

    final targetChatId = await ForwardMessagesDialog.show(
      context,
      messageCount: manager.selectedMessageCount,
    );
    if (targetChatId == null || !mounted) {
      return;
    }

    final options = await ForwardOptionsDialog.show(context);
    if (options == null || !mounted) {
      manager.exitSelectionMode();
      return;
    }

    manager.forwardSelectedMessages(
      toChatId: targetChatId,
      withoutAuthor: options.withoutAuthor,
      removeCaption: options.removeCaption,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сообщения пересланы')),
      );
    }
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final pos = _scrollController.position;
    return pos.maxScrollExtent - pos.pixels < _scrollBottomThreshold;
  }
  void _onScroll() {
    if (_isNearBottom() && _newMessagesBelow > 0) setState(() => _newMessagesBelow = 0);
  }
  void _handleMessageCountChange(int count) {
    if (count == 0) { _lastMessageCount = 0; _initialScrollDone = false; return; }
    if (!_initialScrollDone) { _initialScrollDone = true; _lastMessageCount = count; _scrollToBottom(); return; }
    if (count > _lastMessageCount) {
      if (_isNearBottom()) _scrollToBottom();
      else setState(() => _newMessagesBelow += count - _lastMessageCount);
    }
    _lastMessageCount = count;
  }
  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final t = _scrollController.position.maxScrollExtent;
      if (animated) _scrollController.animateTo(t, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
      else _scrollController.jumpTo(t);
      if (_newMessagesBelow > 0) setState(() => _newMessagesBelow = 0);
    });
  }
  void _openChatInfo() {
    TelegramRoutes.push(context, ChatInfoScreen(chatId: widget.chatId));
  }
  void _openChatMenu() {
    showModalBottomSheet<void>(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.info_outline), title: const Text('Информация о чате'), onTap: () { Navigator.pop(ctx); _openChatInfo(); }),
      ListTile(leading: const Icon(Icons.search), title: const Text('Поиск в чате'), onTap: () {
        Navigator.pop(ctx);
        final chat = context.read<ChatManager>().activeChat;
        TelegramRoutes.push(context, ChatMessageSearchScreen(chatId: widget.chatId, chatTitle: chat?.title, forumTopicId: widget.forumTopicId));
      }),
    ])));
  }
  Widget? _buildAppBarKindSubtitle({required bool isSecretChat, required bool isBotChat, required ChatSummary? chat, required SecretChatSummary? secretChat}) {
    if (isSecretChat) return ChatAppBarKindSubtitle(icon: Icons.lock, label: secretChat?.isReady == true ? 'E2E шифрование' : 'Секретный чат');
    if (isBotChat) return const ChatAppBarKindSubtitle(icon: Icons.smart_toy_outlined, label: 'Бот');
    if (widget.forumTopicId != null && chat != null) return ChatAppBarKindSubtitle(icon: Icons.forum_outlined, label: chat.title);
    return null;
  }
  List<ChatMessage>? _albumMessagesFor(List<ChatMessageListItem> items, ChatMessage m) {
    for (final item in items) {
      if (item is AlbumChatMessageItem && item.albumMessages.any((x) => x.id == m.id)) {
        return item.albumMessages.length > 1 ? item.albumMessages : null;
      }
    }
    return null;
  }

  Future<void> _openComments(ChatMessage message) async {
    await TelegramRoutes.push(context, MessageThreadScreen(channelChatId: widget.chatId, channelMessageId: message.id, postPreview: message.content.preview));
  }

  Future<void> _subscribeToChannel(ChatManager manager, ChatSummary chat) async {
    setState(() => _isSubscribing = true);
    try {
      await manager.subscribeToChannel(chat.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Вы подписались на «${chat.title}»')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubscribing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatManager = context.watch<ChatManager>();
    final callManager = context.watch<CallManager>();
    final profileManager = context.watch<ProfileManager>();
    final botManager = context.watch<BotManager>();
    final secretManager = context.watch<SecretChatManager>();
    final chat = chatManager.activeChat;
    final messages = chatManager.messages;
    final listItems = MediaAlbumGrouper.group(messages);
    final typing = chatManager.typingStatus;
    final selectionMode = chatManager.isSelectionMode;
    final editing = chatManager.editingMessage;
    final showViewCount = chat?.kind == ChatKind.channel;
    final membership = chatManager.channelMembershipFor(widget.chatId);
    final showSubscribeBanner =
        chat?.kind == ChatKind.channel &&
        membership == ChannelMembershipKind.notSubscribed;
    final showReadOnlyBar =
        chat?.kind == ChatKind.channel &&
        !showSubscribeBanner &&
        !chatManager.canSendInActiveChat;
    final showComments = chat?.kind == ChatKind.channel;
    final showSenderName =
        chat?.kind == ChatKind.group || (chat?.isForum ?? false);
    final privateUserId = chat?.privateUserId;
    final privateUser =
        privateUserId != null ? profileManager.userById(privateUserId) : null;
    final callCaps = privateUserId != null
        ? callManager.capabilitiesFor(privateUserId)
        : UserCallCapabilities.none;
    final showCallActions =
        !selectionMode &&
        widget.forumTopicId == null &&
        chat?.kind == ChatKind.privateChat &&
        privateUserId != null &&
        callCaps.canBeCalled;
    final isBotChat = chat?.kind == ChatKind.bot;
    final isSecretChat = chat?.kind == ChatKind.secret;
    final botUserId = isBotChat ? privateUserId : null;
    final botCommands = botUserId != null
        ? botManager.commandsFor(botUserId)
        : const <BotCommandModel>[];
    final filteredCommands = _controller.text.startsWith('/')
        ? botCommands
            .where(
              (cmd) => cmd.slashCommand.startsWith(
                _controller.text.split(' ').first,
              ),
            )
            .toList()
        : const <BotCommandModel>[];
    final secretChat = chat?.secretChatId != null
        ? secretManager.secretChatForId(chat!.secretChatId!)
        : null;
    final showGroupCallActions =
        !selectionMode &&
        widget.forumTopicId == null &&
        (chat?.kind == ChatKind.group || chat?.kind == ChatKind.channel) &&
        chatManager.canSendInActiveChat;

    _handleMessageCountChange(messages.length);

    final tg = context.telegramTheme;
    final ui = context.watch<UiCustomizationManager>();
    final listEntries = MessageBubbleGrouping.buildListEntries(messages: messages, showSenderNamesInGroups: showSenderName);

    return Scaffold(
      backgroundColor: tg.chatBackground,
      appBar: AppBar(
        backgroundColor: tg.chatListBackground,
        surfaceTintColor: Colors.transparent,
        foregroundColor: tg.textPrimary,
        iconTheme: IconThemeData(color: tg.accent),
        title: selectionMode
            ? Text('Выбрано: ${chatManager.selectedMessageCount}', style: TextStyle(color: tg.textPrimary))
            : ChatAppBarTitle(
                title: widget.forumTopicName ?? chat?.title ?? 'Чат',
                avatarLocalPath: chat?.avatarLocalPath,
                userStatus: privateUser?.status,
                typingStatus: typing != null && !selectionMode && editing == null ? typing : null,
                subtitle: _buildAppBarKindSubtitle(isSecretChat: isSecretChat, isBotChat: isBotChat, chat: chat, secretChat: secretChat),
                onTap: widget.forumTopicId == null ? _openChatInfo : null,
              ),
        automaticallyImplyLeading:
            !selectionMode && widget.forumTopicId == null,
        actions: [
          if (showGroupCallActions) ...[
            IconButton(
              tooltip: 'Video chat',
              icon: const Icon(TelegramIcons.groupCall),
              onPressed: () => _startGroupCall(isVideo: false),
            ),
            IconButton(
              tooltip: 'Video chat с камерой',
              icon: const Icon(TelegramIcons.videoChat),
              onPressed: () => _startGroupCall(isVideo: true),
            ),
          ],
          if (showCallActions) ...[
            IconButton(
              tooltip: 'Аудиозвонок',
              icon: const Icon(TelegramIcons.call),
              onPressed: () => _startCall(isVideo: false),
            ),
            if (callCaps.supportsVideoCalls)
              IconButton(
                tooltip: 'Видеозвонок',
                icon: const Icon(TelegramIcons.videocam),
                onPressed: () => _startCall(isVideo: true),
              ),
          ],
          if (!selectionMode && widget.forumTopicId == null)
            IconButton(
              tooltip: 'Поиск в чате',
              icon: const Icon(TelegramIcons.search),
              onPressed: () {
                TelegramRoutes.push(context, ChatMessageSearchScreen(chatId: widget.chatId, chatTitle: chat?.title, forumTopicId: widget.forumTopicId));
              },
            ),
          if (!selectionMode && widget.forumTopicId == null)
            IconButton(
              tooltip: 'Меню',
              icon: const Icon(TelegramIcons.moreVert),
              onPressed: _openChatMenu,
            ),
          if (selectionMode) ...[
            IconButton(
              tooltip: 'Удалить',
              icon: const Icon(TelegramIcons.delete),
              onPressed: chatManager.selectedMessageCount > 0 &&
                      (chatManager.canDeleteSelectedForSelf ||
                          chatManager.canDeleteSelectedForAll)
                  ? _deleteSelected
                  : null,
            ),
            IconButton(
              tooltip: 'Переслать',
              icon: const Icon(TelegramIcons.forward),
              onPressed: chatManager.selectedMessageCount > 0
                  ? _forwardSelected
                  : null,
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          if (showSubscribeBanner && chat != null)
            ChannelSubscribeBanner(
              channelTitle: chat.title,
              isLoading: _isSubscribing,
              onSubscribe: () => _subscribeToChannel(chatManager, chat),
            ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ChatWallpaper(),
                if (chatManager.isLoadingMessages)
                  const Center(child: CircularProgressIndicator())
                else if (chatManager.messagesError != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        chatManager.messagesError!,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else if (listEntries.isEmpty)
                  const Center(child: Text('Нет сообщений'))
                else
                  Stack(children: [ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: listEntries.length,
                            itemBuilder: (context, index) {
                              final entry = listEntries[index];
                              if (entry is ChatListDateEntry) return DateSeparator(date: entry.date);
                              final msgEntry = entry as ChatListMessageEntry;
                              final message = msgEntry.message;
                              final album = _albumMessagesFor(listItems, message);
                              final bubble = MessageBubble(
                                message: message,
                                albumMessages: album,
                                groupPosition: msgEntry.groupPosition,
                                showSenderName: msgEntry.showSenderName,
                                replyPreview:
                                    chatManager.replyPreviewFor(message),
                                selectionMode: selectionMode,
                                showViewCount: showViewCount,
                                isSelected: chatManager.selectedMessageIds
                                    .contains(message.id),
                                onTap: selectionMode
                                    ? () => chatManager
                                        .toggleMessageSelection(message.id)
                                    : null,
                                onLongPress: selectionMode
                                    ? null
                                    : () => _showMessageMenu(message),
                                onReactionTap: (emoji) => chatManager
                                    .toggleMessageReaction(message.id, emoji),
                                onAddReaction: () =>
                                    _addReactionToMessage(message),
                                onPollVote: (optionId) => chatManager
                                    .setPollAnswer(message.id, [optionId]),
                                onInlineButtonTap: (button) {
                                  _handleInlineButton(
                                    chatManager: chatManager,
                                    botManager: botManager,
                                    message: message,
                                    button: button,
                                  );
                                },
                                onInlineWebAppTap: (button) {
                                  _handleInlineButton(
                                    chatManager: chatManager,
                                    botManager: botManager,
                                    message: message,
                                    button: button,
                                  );
                                },
                                onInlineSwitchTap: (button) {
                                  if (button.switchInlineQuery != null) {
                                    _controller.text =
                                        '@bot ${button.switchInlineQuery}';
                                  }
                                },
                                onMediaTap: selectionMode
                                    ? null
                                    : _openMediaViewer,
                                onCancelTransfer: message.fileTransfer != null
                                    ? () => chatManager
                                        .cancelMessageTransfer(message)
                                    : null,
                                showComments: showComments &&
                                    message.canGetMessageThread,
                                onCommentsTap: message.canGetMessageThread
                                    ? () => _openComments(message)
                                    : null,
                                activeLiveLocationMessageId:
                                    chatManager.activeLiveLocationMessageId,
                              );
                              if (selectionMode || message.isServiceMessage) {
                                return bubble;
                              }
                              return MessageSwipeWrapper(
                                message: message,
                                endToStartAction: ui.messageSwipeEndToStart,
                                startToEndAction: ui.messageSwipeStartToEnd,
                                onReply: () {
                                  chatManager.setReplyToMessage(message);
                                },
                                onForward: () {
                                  chatManager.enterSelectionMode(
                                    initialMessageId: message.id,
                                  );
                                  _forwardSelected();
                                },
                                onDelete: () => chatManager.deleteMessage(
                                  message.id,
                                  revoke: false,
                                ),
                                child: bubble,
                              );
                            },
                          ), if (_newMessagesBelow > 0) Positioned(bottom: 12, left: 0, right: 0, child: Center(child: ScrollToBottomButton(newMessageCount: _newMessagesBelow, onPressed: () => _scrollToBottom()))), ],),
              ],
            ),
          ),
          if (!selectionMode) ...[
            if (showReadOnlyBar)
              const ChannelReadOnlyBar()
            else ...[
              if (isBotChat && filteredCommands.isNotEmpty)
                BotCommandMenu(
                  commands: filteredCommands,
                  onCommandSelected: (command) {
                    _controller.text = '${command.slashCommand} ';
                    _controller.selection = TextSelection.collapsed(
                      offset: _controller.text.length,
                    );
                  },
                ),
              MessageInputBar(
              chatId: widget.chatId,
              controller: _controller,
              onSend: _sendMessage,
              onAttach: _attachMedia,
              onPoll: _createPoll,
              onSchedule: _pickSchedule,
              replyDraft: chatManager.pendingReply,
              onClearReply: chatManager.clearReply,
              editDraft: editing,
              onClearEdit: () {
                chatManager.cancelEditing();
                _controller.clear();
              },
              scheduledAt: chatManager.scheduledSendAt,
              onClearSchedule: chatManager.clearScheduledSendAt,
              onFormatBold: () =>
                  ComposerFormatting.wrapSelection(_controller, '**', '**'),
              onFormatItalic: () =>
                  ComposerFormatting.wrapSelection(_controller, '*', '*'),
              onFormatCode: () =>
                  ComposerFormatting.wrapSelection(_controller, '`', '`'),
              onFormatLink: () =>
                  ComposerFormatting.insertLink(context, _controller),
              onVoiceAction: _recordVoice,
              onStickerPanelChanged: _onStickerPanelChanged,
            ),
            ],
          ],
        ],
      ),
    );
  }
}
