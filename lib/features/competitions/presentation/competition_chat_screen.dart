// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Key for the empty-chat state.
const Key chatEmptyKey = ValueKey<String>('chatEmpty');

/// Key for the chat bubble of the message with the given [id].
Key chatMessageKey(String id) => ValueKey<String>('chatMessage-$id');

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

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
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
                            canDelete: mine || isOwner,
                            onDelete: () => unawaited(_confirmDelete(message)),
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
    required this.canDelete,
    required this.onDelete,
  });

  final CompetitionMessage message;
  final bool mine;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final author = message.profile?.displayName ?? 'Ukjent skytter';
    final colour = mine
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        key: chatMessageKey(message.id),
        onLongPress: canDelete ? onDelete : null,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
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
              Text(message.body, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: <Widget>[
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
