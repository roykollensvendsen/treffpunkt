// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/core/platform/clipboard_image.dart';
import 'package:treffpunkt/core/presentation/reactors_sheet.dart';
import 'package:treffpunkt/features/competitions/data/competition_repository.dart';
import 'package:treffpunkt/features/competitions/domain/competition.dart';
import 'package:treffpunkt/features/competitions/domain/competition_message.dart';
import 'package:treffpunkt/features/competitions/presentation/competition_providers.dart';
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

/// Key for the "add reaction" action on the message with the given [id].
Key chatAddReactionKey(String id) => ValueKey<String>('chatAddReaction-$id');

/// Key for the [emoji] choice in the reaction palette.
Key chatPaletteEmojiKey(String emoji) =>
    ValueKey<String>('chatPaletteEmoji-$emoji');

/// Key for the reaction chip of [emoji] on the message with the given [id].
Key chatReactionKey(String id, String emoji) =>
    ValueKey<String>('chatReaction-$id-$emoji');

/// The emoji offered in the reaction palette (spec 0052).
const List<String> chatReactionPalette = <String>[
  '👍',
  '🎯',
  '🔥',
  '😂',
  '❤️',
  '👏',
  '😮',
  '😢',
];

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
    unawaited(_sendImageBytes(image.bytes, isPng: image.isPng));
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _sending) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    final message = CompetitionMessage(
      id: const Uuid().v4(),
      competitionId: widget.competition.id,
      body: text,
      userId: ref.read(currentUserIdProvider),
    );
    try {
      await ref.read(competitionRepositoryProvider).postMessage(message);
      _composer.clear();
    } on CompetitionSyncException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Kunne ikke sende meldingen.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_sending) return;
    final picked = await ref.read(imagePickerProvider)();
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    await _sendImageBytes(
      bytes,
      isPng: picked.name.toLowerCase().endsWith('.png'),
    );
  }

  /// Uploads [bytes] and posts a message with the image — the shared path for
  /// both a picked and a pasted image (spec 0062).
  Future<void> _sendImageBytes(Uint8List bytes, {required bool isPng}) async {
    if (_sending) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      final repo = ref.read(competitionRepositoryProvider);
      final path = await repo.uploadChatImage(
        widget.competition.id,
        bytes,
        fileExtension: isPng ? 'png' : 'jpg',
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
    } on CompetitionSyncException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Kunne ikke laste opp bildet.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmDelete(CompetitionMessage message) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Slett melding?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Slett'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(competitionRepositoryProvider).deleteMessage(message.id);
    } on CompetitionSyncException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Kunne ikke slette meldingen.')),
      );
    }
  }

  Future<void> _toggleReaction(String messageId, String emoji) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(competitionRepositoryProvider)
          .toggleReaction(messageId, emoji);
    } on CompetitionSyncException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Kunne ikke reagere.')),
      );
    }
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
    final isOwner = uid == widget.competition.ownerId;

    return Scaffold(
      appBar: AppBar(title: Text('Chat · ${widget.competition.name}')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
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
                            onReact: (emoji) =>
                                unawaited(_toggleReaction(message.id, emoji)),
                          );
                        },
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                _Composer(
                  controller: _composer,
                  sending: _sending,
                  onSend: () => unawaited(_send()),
                  onAttach: () => unawaited(_pickAndSendImage()),
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
    required this.onReact,
  });

  final CompetitionMessage message;
  final bool mine;
  final String? myUserId;
  final bool canDelete;
  final VoidCallback onDelete;
  final void Function(String emoji) onReact;

  Future<void> _openPalette(BuildContext context) async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final emoji in chatReactionPalette)
                IconButton(
                  key: chatPaletteEmojiKey(emoji),
                  onPressed: () => Navigator.of(sheetContext).pop(emoji),
                  icon: Text(emoji, style: const TextStyle(fontSize: 24)),
                ),
            ],
          ),
        ),
      ),
    );
    if (emoji != null) onReact(emoji);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final author = message.profile?.displayName ?? 'Ukjent skytter';
    final colour = mine
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    // Aggregate reactions: count per emoji, and which ones I gave.
    final counts = <String, int>{};
    final mineEmojis = <String>{};
    for (final reaction in message.reactions) {
      counts.update(reaction.emoji, (n) => n + 1, ifAbsent: () => 1);
      if (reaction.userId == myUserId) mineEmojis.add(reaction.emoji);
    }
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: <Widget>[
          GestureDetector(
            key: chatMessageKey(message.id),
            onLongPress: canDelete ? onDelete : null,
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
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          key: chatImageKey(message.id),
                          height: 180,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox(
                            height: 180,
                            child: Center(child: Icon(Icons.broken_image)),
                          ),
                        ),
                      ),
                    ),
                  if (message.body.isNotEmpty)
                    Text(message.body, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          // You react to OTHER people's messages, not your own: on your own
          // message the chips are display-only and there is no add button.
          Wrap(
            spacing: 4,
            children: <Widget>[
              for (final entry in counts.entries)
                _ReactionChip(
                  key: chatReactionKey(message.id, entry.key),
                  emoji: entry.key,
                  count: entry.value,
                  mine: mineEmojis.contains(entry.key),
                  onTap: mine ? null : () => onReact(entry.key),
                  // Hold a reaction to see who reacted with it (spec 0059).
                  onLongPress: () => showReactors(
                    context,
                    entry.key,
                    <String>[
                      for (final r in message.reactions)
                        if (r.emoji == entry.key)
                          r.userName ?? 'Ukjent skytter',
                    ],
                  ),
                ),
              if (!mine)
                IconButton(
                  key: chatAddReactionKey(message.id),
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  tooltip: 'Reager',
                  onPressed: () => unawaited(_openPalette(context)),
                  icon: const Icon(Icons.add_reaction_outlined),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.mine,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  final String emoji;
  final int count;
  final bool mine;
  final VoidCallback? onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: mine
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: mine ? Border.all(color: theme.colorScheme.primary) : null,
        ),
        child: Text('$emoji $count', style: theme.textTheme.labelMedium),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onAttach,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: <Widget>[
          IconButton(
            key: chatAttachImageKey,
            onPressed: sending ? null : onAttach,
            icon: const Icon(Icons.image_outlined),
            tooltip: 'Legg ved bilde',
          ),
          Expanded(
            child: TextField(
              key: chatComposerFieldKey,
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(
                hintText: 'Skriv en melding …',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            key: chatSendButtonKey,
            onPressed: sending ? null : onSend,
            icon: const Icon(Icons.send),
            tooltip: 'Send',
          ),
        ],
      ),
    );
  }
}
