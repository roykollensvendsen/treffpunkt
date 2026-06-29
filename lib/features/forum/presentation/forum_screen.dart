// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/features/forum/data/forum_repository.dart';
import 'package:treffpunkt/features/forum/domain/forum_post.dart';
import 'package:treffpunkt/features/forum/domain/forum_reaction.dart';
import 'package:treffpunkt/features/forum/domain/forum_thread.dart';
import 'package:treffpunkt/features/forum/presentation/forum_providers.dart';
import 'package:uuid/uuid.dart';

/// Key for the "Forum" action on the program picker (spec 0054).
const Key forumButtonKey = ValueKey<String>('forum');

/// Key for the "new thread" action.
const Key newThreadButtonKey = ValueKey<String>('newThread');

/// Key for the empty-forum state.
const Key forumEmptyKey = ValueKey<String>('forumEmpty');

/// Key for the card of thread [id] in the list.
Key forumThreadCardKey(String id) => ValueKey<String>('forumThread-$id');

/// Key for the category filter chip [wire] (`all` for no filter).
Key forumFilterKey(String wire) => ValueKey<String>('forumFilter-$wire');

/// Key for the new-thread title field.
const Key threadTitleFieldKey = ValueKey<String>('threadTitle');

/// Key for the new-thread body field.
const Key threadBodyFieldKey = ValueKey<String>('threadBody');

/// Key for the category choice [wire] on the new-thread form.
Key threadCategoryKey(String wire) => ValueKey<String>('threadCategory-$wire');

/// Key for the new-thread submit action.
const Key createThreadSubmitKey = ValueKey<String>('createThreadSubmit');

/// Key for a thread's reply composer.
const Key forumReplyFieldKey = ValueKey<String>('forumReply');

/// Key for the reply send action.
const Key forumReplySendKey = ValueKey<String>('forumReplySend');

/// Key for the delete-thread action on the thread screen.
const Key deleteThreadButtonKey = ValueKey<String>('deleteThread');

/// Key for the post [id] in a thread.
Key forumPostKey(String id) => ValueKey<String>('forumPost-$id');

/// Key for the "add reaction" action on a forum [target] (`thread:<id>` or
/// `post:<id>`).
Key forumAddReactionKey(String target) =>
    ValueKey<String>('forumAddReaction-$target');

/// Key for the [emoji] choice in the forum reaction palette.
Key forumPaletteEmojiKey(String emoji) =>
    ValueKey<String>('forumPaletteEmoji-$emoji');

/// Key for the reaction chip of [emoji] on a forum [target].
Key forumReactionKey(String target, String emoji) =>
    ValueKey<String>('forumReaction-$target-$emoji');

/// The emoji offered in the forum reaction palette (spec 0055).
const List<String> forumReactionPalette = <String>[
  '👍',
  '🎯',
  '🔥',
  '😂',
  '❤️',
  '👏',
  '😮',
  '😢',
];

const double _maxWidth = 700;

String _byline(String? author, ForumCategory category) =>
    '${category.label} · ${author ?? 'Ukjent'}';

/// The community forum (spec 0054): a live, filterable list of threads with a
/// way to start a new one. Any signed-in user can read and post.
class ForumScreen extends ConsumerStatefulWidget {
  /// Creates the forum.
  const ForumScreen({super.key});

  @override
  ConsumerState<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends ConsumerState<ForumScreen> {
  ForumCategory? _filter;

  @override
  Widget build(BuildContext context) {
    final threads = ref.watch(forumThreadsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Forum')),
      floatingActionButton: FloatingActionButton.extended(
        key: newThreadButtonKey,
        onPressed: () => unawaited(
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const NewThreadScreen()),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Ny tråd'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: Column(
              children: <Widget>[
                _Filters(
                  selected: _filter,
                  onSelect: (c) => setState(() => _filter = c),
                ),
                Expanded(
                  child: threads.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => const Center(
                      child: Text('Kunne ikke laste forumet.'),
                    ),
                    data: (all) {
                      final list = _filter == null
                          ? all
                          : all.where((t) => t.category == _filter).toList();
                      if (list.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Ingen tråder ennå. Start den første!',
                              key: forumEmptyKey,
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final thread = list[i];
                          return Card(
                            child: ListTile(
                              key: forumThreadCardKey(thread.id),
                              title: Text(thread.title),
                              subtitle: Text(
                                _byline(thread.authorName, thread.category),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => unawaited(
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        ForumThreadScreen(thread: thread),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.selected, required this.onSelect});

  final ForumCategory? selected;
  final void Function(ForumCategory?) onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              key: forumFilterKey('all'),
              label: const Text('Alle'),
              selected: selected == null,
              onSelected: (_) => onSelect(null),
            ),
          ),
          for (final category in ForumCategory.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                key: forumFilterKey(category.wire),
                label: Text(category.label),
                selected: selected == category,
                onSelected: (_) => onSelect(category),
              ),
            ),
        ],
      ),
    );
  }
}

/// The form to start a new thread (spec 0054): a title, a category and an
/// opening message.
class NewThreadScreen extends ConsumerStatefulWidget {
  /// Creates the new-thread form.
  const NewThreadScreen({super.key});

  @override
  ConsumerState<NewThreadScreen> createState() => _NewThreadScreenState();
}

class _NewThreadScreenState extends ConsumerState<NewThreadScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();
  ForumCategory _category = ForumCategory.bug;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.isEmpty || _saving) return;
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(forumRepositoryProvider)
          .createThread(
            ForumThread(
              id: const Uuid().v4(),
              category: _category,
              title: title,
              body: _body.text.trim(),
              authorId: ref.read(forumCurrentUserIdProvider),
            ),
          );
      navigator.pop();
    } on ForumException {
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Kunne ikke opprette tråden.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ny tråd')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                TextField(
                  key: threadTitleFieldKey,
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'Tittel',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: <Widget>[
                    for (final category in ForumCategory.values)
                      ChoiceChip(
                        key: threadCategoryKey(category.wire),
                        label: Text(category.label),
                        selected: _category == category,
                        onSelected: (_) => setState(() => _category = category),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  key: threadBodyFieldKey,
                  controller: _body,
                  minLines: 4,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: 'Melding',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: createThreadSubmitKey,
                  onPressed: _saving ? null : () => unawaited(_submit()),
                  child: const Text('Opprett'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One thread: its opening post, then its replies, and a reply composer
/// (spec 0054). The author or a moderator can delete the thread or a reply.
class ForumThreadScreen extends ConsumerStatefulWidget {
  /// Creates the thread view for [thread].
  const ForumThreadScreen({required this.thread, super.key});

  /// The thread being viewed.
  final ForumThread thread;

  @override
  ConsumerState<ForumThreadScreen> createState() => _ForumThreadScreenState();
}

class _ForumThreadScreenState extends ConsumerState<ForumThreadScreen> {
  final TextEditingController _reply = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(forumRepositoryProvider)
          .postReply(
            ForumPost(
              id: const Uuid().v4(),
              threadId: widget.thread.id,
              body: text,
              authorId: ref.read(forumCurrentUserIdProvider),
            ),
          );
      _reply.clear();
    } on ForumException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Kunne ikke sende svaret.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteThread() async {
    final navigator = Navigator.of(context);
    await ref.read(forumRepositoryProvider).deleteThread(widget.thread.id);
    navigator.pop();
  }

  Future<void> _deletePost(String postId) async {
    await ref.read(forumRepositoryProvider).deletePost(postId);
  }

  Future<void> _toggleReaction(
    String targetType,
    String targetId,
    String emoji,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(forumRepositoryProvider)
          .toggleReaction(
            targetType: targetType,
            targetId: targetId,
            emoji: emoji,
          );
    } on ForumException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Kunne ikke reagere.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Prefer the live thread (for live reaction updates on the opening post),
    // falling back to the one we navigated with.
    var thread = widget.thread;
    final allThreads = ref.watch(forumThreadsProvider).value;
    if (allThreads != null) {
      for (final t in allThreads) {
        if (t.id == widget.thread.id) {
          thread = t;
          break;
        }
      }
    }
    final posts = ref.watch(forumPostsProvider(thread.id));
    final uid = ref.watch(forumCurrentUserIdProvider);
    final isAdmin = ref.watch(forumIsAdminProvider).value ?? false;
    final canModerateThread = thread.authorId == uid || isAdmin;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(thread.title),
        actions: <Widget>[
          if (canModerateThread)
            IconButton(
              key: deleteThreadButtonKey,
              tooltip: 'Slett tråd',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => unawaited(_deleteThread()),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: Column(
              children: <Widget>[
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: <Widget>[
                      // The opening post.
                      Card(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _byline(thread.authorName, thread.category),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (thread.body.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  thread.body,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                              _ForumReactionBar(
                                target: 'thread:${thread.id}',
                                reactions: thread.reactions,
                                myUserId: uid,
                                onReact: (emoji) => unawaited(
                                  _toggleReaction('thread', thread.id, emoji),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...posts.when(
                        loading: () => const <Widget>[
                          Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ],
                        error: (_, _) => const <Widget>[
                          Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Kunne ikke laste svarene.'),
                          ),
                        ],
                        data: (replies) => <Widget>[
                          for (final post in replies)
                            _ReplyTile(
                              post: post,
                              myUserId: uid,
                              canDelete: post.authorId == uid || isAdmin,
                              onDelete: () => unawaited(_deletePost(post.id)),
                              onReact: (emoji) => unawaited(
                                _toggleReaction('post', post.id, emoji),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          key: forumReplyFieldKey,
                          controller: _reply,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => unawaited(_send()),
                          decoration: const InputDecoration(
                            hintText: 'Skriv et svar …',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        key: forumReplySendKey,
                        tooltip: 'Send',
                        onPressed: _sending ? null : () => unawaited(_send()),
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReplyTile extends StatelessWidget {
  const _ReplyTile({
    required this.post,
    required this.myUserId,
    required this.canDelete,
    required this.onDelete,
    required this.onReact,
  });

  final ForumPost post;
  final String? myUserId;
  final bool canDelete;
  final VoidCallback onDelete;
  final void Function(String emoji) onReact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      key: forumPostKey(post.id),
      onLongPress: canDelete ? onDelete : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              post.authorName ?? 'Ukjent',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(post.body, style: theme.textTheme.bodyMedium),
            _ForumReactionBar(
              target: 'post:${post.id}',
              reactions: post.reactions,
              myUserId: myUserId,
              onReact: onReact,
            ),
          ],
        ),
      ),
    );
  }
}

/// The reaction chips on a thread or reply plus an add-reaction button
/// (spec 0055). [target] is `thread:<id>` or `post:<id>`, used only for keys.
class _ForumReactionBar extends StatelessWidget {
  const _ForumReactionBar({
    required this.target,
    required this.reactions,
    required this.myUserId,
    required this.onReact,
  });

  final String target;
  final List<ForumReaction> reactions;
  final String? myUserId;
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
              for (final emoji in forumReactionPalette)
                IconButton(
                  key: forumPaletteEmojiKey(emoji),
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
    final counts = <String, int>{};
    final mine = <String>{};
    for (final reaction in reactions) {
      counts.update(reaction.emoji, (n) => n + 1, ifAbsent: () => 1);
      if (reaction.userId == myUserId) mine.add(reaction.emoji);
    }
    final theme = Theme.of(context);
    return Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        for (final entry in counts.entries)
          InkWell(
            key: forumReactionKey(target, entry.key),
            onTap: () => onReact(entry.key),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: mine.contains(entry.key)
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: mine.contains(entry.key)
                    ? Border.all(color: theme.colorScheme.primary)
                    : null,
              ),
              child: Text(
                '${entry.key} ${entry.value}',
                style: theme.textTheme.labelMedium,
              ),
            ),
          ),
        IconButton(
          key: forumAddReactionKey(target),
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          tooltip: 'Reager',
          onPressed: () => unawaited(_openPalette(context)),
          icon: const Icon(Icons.add_reaction_outlined),
        ),
      ],
    );
  }
}
