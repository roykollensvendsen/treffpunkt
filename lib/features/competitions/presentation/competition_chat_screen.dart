// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/core/platform/clipboard_image.dart';
import 'package:treffpunkt/core/platform/image_format.dart';
import 'package:treffpunkt/core/presentation/confirm_dialog.dart';
import 'package:treffpunkt/core/presentation/copy_message_text.dart';
import 'package:treffpunkt/core/presentation/edit_text_dialog.dart';
import 'package:treffpunkt/core/presentation/frosted_bar.dart';
import 'package:treffpunkt/core/presentation/full_screen_image.dart';
import 'package:treffpunkt/core/presentation/image_send.dart';
import 'package:treffpunkt/core/presentation/layout.dart';
import 'package:treffpunkt/core/presentation/mention_picker.dart';
import 'package:treffpunkt/core/presentation/mention_text.dart';
import 'package:treffpunkt/core/presentation/message_actions_sheet.dart';
import 'package:treffpunkt/core/presentation/message_composer.dart';
import 'package:treffpunkt/core/presentation/message_time.dart';
import 'package:treffpunkt/core/presentation/reaction_widgets.dart';
import 'package:treffpunkt/core/presentation/snackbar_guard.dart';
import 'package:treffpunkt/features/competitions/data/competition_repository.dart';
import 'package:treffpunkt/features/competitions/domain/competition.dart';
import 'package:treffpunkt/features/competitions/domain/competition_message.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_providers.dart';
import 'package:treffpunkt/features/competitions/presentation/display_name.dart';
import 'package:uuid/uuid.dart';

/// Key for the "open chat" action on the competition detail (spec 0051).
const Key competitionChatButtonKey = ValueKey<String>('competitionChat');

/// Key for the chat message-composer text field.
const Key chatComposerFieldKey = ValueKey<String>('chatComposer');

/// Key for the chat send action.
const Key chatSendButtonKey = ValueKey<String>('chatSend');

/// Key for the "attach image" action in the composer (spec 0053).
const Key chatAttachImageKey = ValueKey<String>('chatAttachImage');

/// Key for the attached image on the message with the given [id].
Key chatImageKey(String id) => ValueKey<String>('chatImage-$id');

/// Key for the empty-chat state.
const Key chatEmptyKey = ValueKey<String>('chatEmpty');

/// Key for the chat bubble of the message with the given [id].
Key chatMessageKey(String id) => ValueKey<String>('chatMessage-$id');

/// Key for the "Kopier tekst" item in a message's action sheet (spec 0069).
const Key chatCopyKey = ValueKey<String>('chatCopy');

/// Key for the "Slett" item in a message's action sheet (spec 0069).
const Key chatDeleteKey = ValueKey<String>('chatDelete');

/// Key for the "Rediger" item in a message's action sheet (spec 0070).
const Key chatEditKey = ValueKey<String>('chatEdit');

/// Key for the body field in the edit-message dialog (spec 0070).
const Key chatEditBodyFieldKey = ValueKey<String>('chatEditBody');

/// Key for the "Lagre" action in the edit-message dialog (spec 0070).
const Key chatEditSaveKey = ValueKey<String>('chatEditSave');

/// Key for the "add reaction" action on the message with the given [id].
Key chatAddReactionKey(String id) => ValueKey<String>('chatAddReaction-$id');

/// Key for the timestamp on the message with the given [id] (spec 0065).
Key chatTimestampKey(String id) => ValueKey<String>('chatTimestamp-$id');

/// Key for the [emoji] choice in the reaction palette.
Key chatPaletteEmojiKey(String emoji) =>
    ValueKey<String>('chatPaletteEmoji-$emoji');

/// Key for the reaction chip of [emoji] on the message with the given [id].
Key chatReactionKey(String id, String emoji) =>
    ValueKey<String>('chatReaction-$id-$emoji');

/// The live chat for one competition (spec 0051): everyone who can see the
/// competition reads it; participants can post. Messages stream in via
/// Realtime; you can delete your own, and the owner can delete any.
class CompetitionChatScreen extends ConsumerStatefulWidget {
  /// Creates the chat for [competition].
  const CompetitionChatScreen({required this.competition, super.key});

  /// The competition whose chat this is.
  final Competition competition;

  @override
  ConsumerState<CompetitionChatScreen> createState() =>
      _CompetitionChatScreenState();
}

class _CompetitionChatScreenState extends ConsumerState<CompetitionChatScreen> {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _sending = false;
  StreamSubscription<PastedImage>? _pasteSub;

  @override
  void initState() {
    super.initState();
    // Paste an image (Ctrl/Cmd+V) to send it, just like picking one (spec 0062).
    _pasteSub = ref
        .read(clipboardImageWatcherProvider)
        .images
        .listen(_onImagePasted);
  }

  @override
  void dispose() {
    unawaited(_pasteSub?.cancel());
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onImagePasted(PastedImage image) {
    // Only the visible chat handles a paste, never a screen underneath it.
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
    unawaited(_sendImageBytes(image.bytes));
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _sending) return;
    if (!await ensureDisplayName(context, ref)) return;
    if (!mounted) return;
    setState(() => _sending = true);
    final message = CompetitionMessage(
      id: const Uuid().v4(),
      competitionId: widget.competition.id,
      body: text,
      userId: ref.read(currentUserIdProvider),
    );
    try {
      final ok = await guardWithSnackBar<CompetitionSyncException>(
        context,
        task: () =>
            ref.read(competitionRepositoryProvider).postMessage(message),
        failureMessage: 'Kunne ikke sende meldingen.',
      );
      if (ok) _composer.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_sending) return;
    await pickAndSendImage(
      context,
      pickBytes: () async {
        final picked = await ref.read(imagePickerProvider)();
        return picked?.readAsBytes();
      },
      send: _postImage,
      failureMessage: 'Kunne ikke laste opp bildet.',
    );
  }

  /// Sends a pasted image through the same guard-and-send pipeline as a
  /// picked one (spec 0062).
  Future<void> _sendImageBytes(Uint8List bytes) async {
    if (_sending) return;
    await sendImageBytes(
      context,
      bytes: bytes,
      send: _postImage,
      failureMessage: 'Kunne ikke laste opp bildet.',
    );
  }

  /// Uploads the image and posts a message carrying it — the shared tail of
  /// both the picked and the pasted path (spec 0062).
  Future<void> _postImage(Uint8List bytes, ImageFormat format) async {
    if (!await ensureDisplayName(context, ref)) return;
    if (!mounted) return;
    setState(() => _sending = true);
    try {
      final repo = ref.read(competitionRepositoryProvider);
      final path = await repo.uploadChatImage(
        widget.competition.id,
        bytes,
        fileExtension: format.extension,
      );
      await repo.postMessage(
        CompetitionMessage(
          id: const Uuid().v4(),
          competitionId: widget.competition.id,
          body: _composer.text.trim(),
          userId: ref.read(currentUserIdProvider),
          imagePath: path,
        ),
      );
      _composer.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmDelete(CompetitionMessage message) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Slett melding?',
      confirmLabel: 'Slett',
    );
    if (!ok || !mounted) return;
    await guardWithSnackBar<CompetitionSyncException>(
      context,
      task: () =>
          ref.read(competitionRepositoryProvider).deleteMessage(message.id),
      failureMessage: 'Kunne ikke slette meldingen.',
    );
  }

  /// Opens an editor for your own message, then saves the new text (spec 0070).
  Future<void> _editMessage(CompetitionMessage message) async {
    final newBody = await showEditTextDialog(
      context,
      title: 'Rediger melding',
      initialText: message.body,
      hint: 'Melding …',
      fieldKey: chatEditBodyFieldKey,
      saveKey: chatEditSaveKey,
    );
    if (newBody == null) return;
    // The text may be cleared only when the message still carries an image.
    if (newBody.isEmpty && message.imageUrl == null) return;
    if (!mounted) return;
    await guardWithSnackBar<CompetitionSyncException>(
      context,
      task: () => ref
          .read(competitionRepositoryProvider)
          .editMessage(message.id, body: newBody),
      failureMessage: 'Kunne ikke lagre endringen.',
    );
  }

  Future<void> _toggleReaction(String messageId, String emoji) async {
    await guardWithSnackBar<CompetitionSyncException>(
      context,
      task: () => ref
          .read(competitionRepositoryProvider)
          .toggleReaction(messageId, emoji),
      failureMessage: 'Kunne ikke reagere.',
    );
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(competitionChatProvider(widget.competition.id));
    final uid = ref.watch(currentUserIdProvider);
    // Who @ can tag here (spec 0120): the members and the owner by display
    // name, yourself excluded. Robot Hood is forum-only by design. Watched
    // so the list is warm before the first @ is typed.
    final members =
        ref.watch(competitionMembersProvider(widget.competition.id)).value ??
        const [];
    final mentionNames = <String>{
      for (final member in members)
        if (member.userId != uid) ?member.profile?.displayName,
    }.toList()..sort();
    final isOwner = uid == widget.competition.ownerId;

    return Scaffold(
      appBar: FrostedAppBar(title: Text('Chat · ${widget.competition.name}')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
            child: Column(
              children: <Widget>[
                Expanded(
                  child: chat.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Kunne ikke laste chatten.'),
                      ),
                    ),
                    data: (messages) {
                      if (messages.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Ingen meldinger ennå. Skriv den første!',
                              key: chatEmptyKey,
                            ),
                          ),
                        );
                      }
                      _scrollToBottomSoon();
                      return ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(12),
                        itemCount: messages.length,
                        itemBuilder: (context, i) {
                          final message = messages[i];
                          final mine = message.userId == uid;
                          return _MessageBubble(
                            message: message,
                            mine: mine,
                            myUserId: uid,
                            canDelete: mine || isOwner,
                            onDelete: () => unawaited(_confirmDelete(message)),
                            onEdit: () => unawaited(_editMessage(message)),
                            onReact: (emoji) =>
                                unawaited(_toggleReaction(message.id, emoji)),
                          );
                        },
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                MessageComposer(
                  controller: _composer,
                  hint: 'Skriv en melding …',
                  sending: _sending,
                  onSend: () => unawaited(_send()),
                  onAttach: () => unawaited(_pickAndSendImage()),
                  // Typing @ offers the competition's members (spec 0120);
                  // Robot Hood is forum-only by design.
                  onChanged: (_) => unawaited(
                    maybeOfferMentions(context, _composer, mentionNames),
                  ),
                  fieldKey: chatComposerFieldKey,
                  sendKey: chatSendButtonKey,
                  attachKey: chatAttachImageKey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.myUserId,
    required this.canDelete,
    required this.onDelete,
    required this.onEdit,
    required this.onReact,
  });

  final CompetitionMessage message;
  final bool mine;
  final String? myUserId;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final void Function(String emoji) onReact;

  /// Folds the message's raw reaction rows into the shared per-emoji view
  /// (spec 0052) — the chat's data model stays its own.
  List<ReactionView> _reactionViews() {
    final views = <String, ReactionView>{};
    for (final reaction in message.reactions) {
      final view = views[reaction.emoji];
      views[reaction.emoji] = ReactionView(
        emoji: reaction.emoji,
        count: (view?.count ?? 0) + 1,
        mine: (view?.mine ?? false) || reaction.userId == myUserId,
        reactorNames: [
          ...?view?.reactorNames,
          reaction.userName ?? 'Ukjent skytter',
        ],
      );
    }
    return views.values.toList();
  }

  /// Offers "Kopier tekst" (spec 0069), "Rediger" your own message (spec 0070)
  /// and, where allowed, "Slett" (spec 0051).
  void _showActions(BuildContext context) {
    unawaited(
      showMessageActions(
        context,
        canCopy: message.body.isNotEmpty,
        canEdit: mine,
        canDelete: canDelete,
        onCopy: () => unawaited(copyMessageText(context, message.body)),
        onEdit: onEdit,
        onDelete: onDelete,
        copyKey: chatCopyKey,
        editKey: chatEditKey,
        deleteKey: chatDeleteKey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final author = message.profile?.displayName ?? 'Ukjent skytter';
    final colour = mine
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: <Widget>[
          GestureDetector(
            key: chatMessageKey(message.id),
            onLongPress: (message.body.isNotEmpty || canDelete)
                ? () => _showActions(context)
                : null,
            child: Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              constraints: const BoxConstraints(maxWidth: 460),
              decoration: BoxDecoration(
                color: colour,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (!mine)
                    Text(
                      author,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (message.imageUrl case final url?)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: message.body.isEmpty ? 0 : 6,
                      ),
                      child: TappableNetworkImage(
                        url: url,
                        heroTag: 'chatImage-${message.id}',
                        thumbnailKey: chatImageKey(message.id),
                      ),
                    ),
                  if (message.body.isNotEmpty)
                    Text.rich(
                      TextSpan(
                        children: mentionSpans(
                          message.body,
                          accent: mine
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.primary,
                        ),
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                  if (message.createdAt case final at?)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        formatMessageTime(at),
                        key: chatTimestampKey(message.id),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // You react to OTHER people's messages, not your own: on your own
          // message the chips are display-only and there is no add button.
          ReactionBar(
            reactions: _reactionViews(),
            onToggle: onReact,
            canReact: !mine,
            chipKeyFor: (emoji) => chatReactionKey(message.id, emoji),
            addKey: chatAddReactionKey(message.id),
            paletteKeyFor: chatPaletteEmojiKey,
          ),
        ],
      ),
    );
  }
}
