// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:treffpunkt/core/platform/clipboard_image.dart';
import 'package:treffpunkt/core/presentation/copy_message_text.dart';
import 'package:treffpunkt/core/presentation/message_time.dart';
import 'package:treffpunkt/core/presentation/reactors_sheet.dart';
import 'package:treffpunkt/features/competitions/presentation/display_name.dart';
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

/// Key for the "attach image" action on the new-thread form (spec 0056).
const Key threadImageAttachKey = ValueKey<String>('threadImageAttach');

/// Key for the "image attached" indicator on the new-thread form.
const Key threadImageAttachedKey = ValueKey<String>('threadImageAttached');

/// Key for the "attach image" action in a thread's reply composer.
const Key forumReplyAttachKey = ValueKey<String>('forumReplyAttach');

/// Key for the attached image on thread or reply [id].
Key forumImageKey(String id) => ValueKey<String>('forumImage-$id');

/// Key for a thread's reply composer.
const Key forumReplyFieldKey = ValueKey<String>('forumReply');

/// Key for the reply send action.
const Key forumReplySendKey = ValueKey<String>('forumReplySend');

/// Key for the delete-thread action on the thread screen.
const Key deleteThreadButtonKey = ValueKey<String>('deleteThread');

/// Key for the "edit thread" action on your own thread (spec 0063).
const Key editThreadButtonKey = ValueKey<String>('editThread');

/// Key for the "Rediger" action in a reply's menu, used by tests.
const Key forumReplyEditKey = ValueKey<String>('forumReplyEdit');

/// Key for the "Slett" action in a reply's menu, used by tests.
const Key forumReplyDeleteKey = ValueKey<String>('forumReplyDelete');

/// Key for the "Kopier tekst" action in a reply's menu (spec 0069).
const Key forumReplyCopyKey = ValueKey<String>('forumReplyCopy');

/// Key for the "Kopier tekst" action on a thread's opening post (spec 0069).
const Key forumThreadCopyKey = ValueKey<String>('forumThreadCopy');

/// Key for the title field in the edit-thread dialog, used by tests.
const Key forumEditTitleFieldKey = ValueKey<String>('forumEditTitle');

/// Key for the body field in an edit dialog, used by tests.
const Key forumEditBodyFieldKey = ValueKey<String>('forumEditBody');

/// Key for the "Lagre" action in an edit dialog, used by tests.
const Key forumEditSaveKey = ValueKey<String>('forumEditSave');

/// Key for the post [id] in a thread.
Key forumPostKey(String id) => ValueKey<String>('forumPost-$id');

/// Key for the timestamp on a thread or reply [id] (spec 0065).
Key forumTimeKey(String id) => ValueKey<String>('forumTime-$id');

/// Key for the status badge on thread [id] (spec 0066).
Key forumStatusBadgeKey(String id) => ValueKey<String>('forumStatus-$id');

/// Key for the moderator's "set status" menu on the thread screen (spec 0066).
const Key forumStatusMenuKey = ValueKey<String>('forumStatusMenu');

/// Key for the status choice [wire] in the moderator's menu, used by tests.
Key forumStatusOptionKey(String wire) =>
    ValueKey<String>('forumStatusOption-$wire');

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
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  if (thread.status != ForumThreadStatus.open)
                                    _ThreadStatusBadge(
                                      thread.status,
                                      threadId: thread.id,
                                    ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
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
  String? _imagePath;
  StreamSubscription<PastedImage>? _pasteSub;

  @override
  void initState() {
    super.initState();
    // Paste an image (Ctrl/Cmd+V) to attach it, like picking one (spec 0062).
    _pasteSub = ref
        .read(clipboardImageWatcherProvider)
        .images
        .listen(_onImagePasted);
  }

  @override
  void dispose() {
    unawaited(_pasteSub?.cancel());
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _onImagePasted(PastedImage image) {
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
    unawaited(_attachImageBytes(image.bytes, isPng: image.isPng));
  }

  Future<void> _pickImage() async {
    final picked = await ref.read(forumImagePickerProvider)();
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    await _attachImageBytes(
      bytes,
      isPng: picked.name.toLowerCase().endsWith('.png'),
    );
  }

  /// Uploads [bytes] and stages it as the thread's image — shared by a picked
  /// and a pasted image (spec 0062).
  Future<void> _attachImageBytes(Uint8List bytes, {required bool isPng}) async {
    if (_saving) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final path = await ref
          .read(forumRepositoryProvider)
          .uploadForumImage(bytes, fileExtension: isPng ? 'png' : 'jpg');
      setState(() => _imagePath = path);
    } on ForumException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Kunne ikke laste opp bildet.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.isEmpty || _saving) return;
    if (!await ensureDisplayName(context, ref)) return;
    if (!mounted) return;
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
              imagePath: _imagePath,
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
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    OutlinedButton.icon(
                      key: threadImageAttachKey,
                      onPressed: _saving ? null : () => unawaited(_pickImage()),
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Legg ved bilde'),
                    ),
                    if (_imagePath != null)
                      const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Icon(
                          Icons.check_circle,
                          key: threadImageAttachedKey,
                          color: Colors.green,
                        ),
                      ),
                  ],
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
  StreamSubscription<PastedImage>? _pasteSub;

  @override
  void initState() {
    super.initState();
    // Paste an image (Ctrl/Cmd+V) to send it in a reply, like picking one
    // (spec 0062).
    _pasteSub = ref
        .read(clipboardImageWatcherProvider)
        .images
        .listen(_onImagePasted);
  }

  @override
  void dispose() {
    unawaited(_pasteSub?.cancel());
    _reply.dispose();
    super.dispose();
  }

  void _onImagePasted(PastedImage image) {
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
    unawaited(_sendImageBytes(image.bytes, isPng: image.isPng));
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty || _sending) return;
    if (!await ensureDisplayName(context, ref)) return;
    if (!mounted) return;
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

  Future<void> _pickAndSendImage() async {
    if (_sending) return;
    final picked = await ref.read(forumImagePickerProvider)();
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    await _sendImageBytes(
      bytes,
      isPng: picked.name.toLowerCase().endsWith('.png'),
    );
  }

  /// Uploads [bytes] and posts a reply with the image — shared by a picked and
  /// a pasted image (spec 0062).
  Future<void> _sendImageBytes(Uint8List bytes, {required bool isPng}) async {
    if (_sending) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      final repo = ref.read(forumRepositoryProvider);
      final path = await repo.uploadForumImage(
        bytes,
        fileExtension: isPng ? 'png' : 'jpg',
      );
      await repo.postReply(
        ForumPost(
          id: const Uuid().v4(),
          threadId: widget.thread.id,
          body: _reply.text.trim(),
          authorId: ref.read(forumCurrentUserIdProvider),
          imagePath: path,
        ),
      );
      _reply.clear();
    } on ForumException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Kunne ikke laste opp bildet.')),
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

  /// Long-pressing the opening post offers "Kopier tekst" (spec 0069).
  void _showThreadActions(String body) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                key: forumThreadCopyKey,
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Kopier tekst'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(copyMessageText(context, body));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sets the thread's lifecycle status — moderators only (spec 0066).
  Future<void> _setStatus(String threadId, ForumThreadStatus status) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(forumRepositoryProvider).setThreadStatus(threadId, status);
    } on ForumException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Kunne ikke sette status.')),
      );
    }
  }

  /// Opens an editor for your own thread (title + body), then saves it
  /// (spec 0063).
  Future<void> _editThread(ForumThread thread) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _EditThreadDialog(
        initialTitle: thread.title,
        initialBody: thread.body,
      ),
    );
    if (result == null) return;
    final (title, body) = result;
    // A thread needs a title; the body may be empty only with an image.
    if (title.isEmpty || (body.isEmpty && thread.imageUrl == null)) return;
    try {
      await ref
          .read(forumRepositoryProvider)
          .editThread(thread.id, title: title, body: body);
    } on ForumException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Kunne ikke lagre endringen.')),
      );
    }
  }

  /// Opens an editor for your own reply body, then saves it (spec 0063).
  Future<void> _editPost(ForumPost post) async {
    final messenger = ScaffoldMessenger.of(context);
    final newBody = await showDialog<String>(
      context: context,
      builder: (_) => _EditReplyDialog(initialBody: post.body),
    );
    if (newBody == null || (newBody.isEmpty && post.imageUrl == null)) return;
    try {
      await ref.read(forumRepositoryProvider).editPost(post.id, body: newBody);
    } on ForumException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Kunne ikke lagre endringen.')),
      );
    }
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
          if (isAdmin)
            PopupMenuButton<ForumThreadStatus>(
              key: forumStatusMenuKey,
              tooltip: 'Sett status',
              icon: const Icon(Icons.flag_outlined),
              initialValue: thread.status,
              onSelected: (status) => unawaited(_setStatus(thread.id, status)),
              itemBuilder: (context) => <PopupMenuEntry<ForumThreadStatus>>[
                for (final status in ForumThreadStatus.values)
                  PopupMenuItem<ForumThreadStatus>(
                    key: forumStatusOptionKey(status.wire),
                    value: status,
                    child: Text(status.label),
                  ),
              ],
            ),
          if (thread.authorId == uid)
            IconButton(
              key: editThreadButtonKey,
              tooltip: 'Rediger tråd',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => unawaited(_editThread(thread)),
            ),
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
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      _byline(
                                        thread.authorName,
                                        thread.category,
                                      ),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                  if (thread.status != ForumThreadStatus.open)
                                    _ThreadStatusBadge(
                                      thread.status,
                                      threadId: thread.id,
                                    ),
                                ],
                              ),
                              if (thread.body.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onLongPress: () =>
                                      _showThreadActions(thread.body),
                                  child: Text(
                                    thread.body,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                              if (thread.imageUrl case final url?) ...[
                                const SizedBox(height: 8),
                                _ForumImage(id: thread.id, url: url),
                              ],
                              if (thread.createdAt case final at?)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    formatMessageTime(at),
                                    key: forumTimeKey(thread.id),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              _ForumReactionBar(
                                target: 'thread:${thread.id}',
                                reactions: thread.reactions,
                                myUserId: uid,
                                mine: thread.authorId == uid,
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
                              canEdit: post.authorId == uid,
                              onEdit: () => unawaited(_editPost(post)),
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
                      IconButton(
                        key: forumReplyAttachKey,
                        tooltip: 'Legg ved bilde',
                        onPressed: _sending
                            ? null
                            : () => unawaited(_pickAndSendImage()),
                        icon: const Icon(Icons.image_outlined),
                      ),
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
    required this.canEdit,
    required this.onEdit,
    required this.canDelete,
    required this.onDelete,
    required this.onReact,
  });

  final ForumPost post;
  final String? myUserId;
  final bool canEdit;
  final VoidCallback onEdit;
  final bool canDelete;
  final VoidCallback onDelete;
  final void Function(String emoji) onReact;

  /// Offers Kopier tekst (spec 0069) and Rediger/Slett (spec 0063) for a reply.
  void _showActions(BuildContext context) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (post.body.isNotEmpty)
                ListTile(
                  key: forumReplyCopyKey,
                  leading: const Icon(Icons.copy_outlined),
                  title: const Text('Kopier tekst'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    unawaited(copyMessageText(context, post.body));
                  },
                ),
              if (canEdit)
                ListTile(
                  key: forumReplyEditKey,
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Rediger'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onEdit();
                  },
                ),
              if (canDelete)
                ListTile(
                  key: forumReplyDeleteKey,
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Slett'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onDelete();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Mirror the competition chat: your own replies sit on the right in an
    // accent bubble, others' on the left (spec 0063).
    final mine = post.authorId == myUserId;
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
            key: forumPostKey(post.id),
            behavior: HitTestBehavior.opaque,
            onLongPress: (canEdit || canDelete || post.body.isNotEmpty)
                ? () => _showActions(context)
                : null,
            child: Container(
              margin: const EdgeInsets.only(top: 6),
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
                      post.authorName ?? 'Ukjent',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (post.imageUrl case final url?) ...[
                    if (post.body.isNotEmpty || !mine)
                      const SizedBox(height: 4),
                    _ForumImage(id: post.id, url: url),
                  ],
                  if (post.body.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(
                        top: post.imageUrl != null ? 6 : 0,
                      ),
                      child: Text(post.body, style: theme.textTheme.bodyMedium),
                    ),
                  if (post.createdAt case final at?)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        formatMessageTime(at),
                        key: forumTimeKey(post.id),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          _ForumReactionBar(
            target: 'post:${post.id}',
            reactions: post.reactions,
            myUserId: myUserId,
            mine: mine,
            onReact: onReact,
          ),
        ],
      ),
    );
  }
}

/// An attached forum image rendered from its signed URL (spec 0056).
class _ForumImage extends StatelessWidget {
  const _ForumImage({required this.id, required this.url});

  final String id;
  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        key: forumImageKey(id),
        height: 180,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox(
          height: 180,
          child: Center(child: Icon(Icons.broken_image)),
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
    required this.mine,
    required this.onReact,
  });

  final String target;
  final List<ForumReaction> reactions;
  final String? myUserId;

  /// Whether the current user authored this thread/reply — you react to other
  /// people's posts, not your own (spec 0055).
  final bool mine;
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
    final mineEmojis = <String>{};
    for (final reaction in reactions) {
      counts.update(reaction.emoji, (n) => n + 1, ifAbsent: () => 1);
      if (reaction.userId == myUserId) mineEmojis.add(reaction.emoji);
    }
    final theme = Theme.of(context);
    // You react to OTHER people's posts, not your own: on your own thread/reply
    // the chips are display-only and there is no add button (spec 0055).
    return Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        for (final entry in counts.entries)
          InkWell(
            key: forumReactionKey(target, entry.key),
            onTap: mine ? null : () => onReact(entry.key),
            // Hold a reaction to see who reacted with it (spec 0059).
            onLongPress: () => showReactors(
              context,
              entry.key,
              <String>[
                for (final r in reactions)
                  if (r.emoji == entry.key) r.userName ?? 'Ukjent',
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: mineEmojis.contains(entry.key)
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: mineEmojis.contains(entry.key)
                    ? Border.all(color: theme.colorScheme.primary)
                    : null,
              ),
              child: Text(
                '${entry.key} ${entry.value}',
                style: theme.textTheme.labelMedium,
              ),
            ),
          ),
        if (!mine)
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

/// Dialog to edit your own thread's title and body (spec 0063). Owns its
/// controllers so they outlive the dialog's dismiss animation. Returns
/// `(title, body)` on save, or null on cancel.
class _EditThreadDialog extends StatefulWidget {
  const _EditThreadDialog({
    required this.initialTitle,
    required this.initialBody,
  });

  final String initialTitle;
  final String initialBody;

  @override
  State<_EditThreadDialog> createState() => _EditThreadDialogState();
}

class _EditThreadDialogState extends State<_EditThreadDialog> {
  late final TextEditingController _title = TextEditingController(
    text: widget.initialTitle,
  );
  late final TextEditingController _body = TextEditingController(
    text: widget.initialBody,
  );

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Rediger tråd'),
    content: SizedBox(
      width: double.maxFinite,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            key: forumEditTitleFieldKey,
            controller: _title,
            decoration: const InputDecoration(labelText: 'Tittel'),
          ),
          const SizedBox(height: 8),
          TextField(
            key: forumEditBodyFieldKey,
            controller: _body,
            minLines: 1,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'Tekst'),
          ),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Avbryt'),
      ),
      FilledButton(
        key: forumEditSaveKey,
        onPressed: () =>
            Navigator.of(context).pop((_title.text.trim(), _body.text.trim())),
        child: const Text('Lagre'),
      ),
    ],
  );
}

/// Dialog to edit your own reply's body (spec 0063). Returns the new body on
/// save, or null on cancel.
class _EditReplyDialog extends StatefulWidget {
  const _EditReplyDialog({required this.initialBody});

  final String initialBody;

  @override
  State<_EditReplyDialog> createState() => _EditReplyDialogState();
}

class _EditReplyDialogState extends State<_EditReplyDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialBody,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Rediger svar'),
    content: SizedBox(
      width: double.maxFinite,
      child: TextField(
        key: forumEditBodyFieldKey,
        controller: _controller,
        autofocus: true,
        minLines: 1,
        maxLines: 6,
        decoration: const InputDecoration(hintText: 'Svar …'),
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Avbryt'),
      ),
      FilledButton(
        key: forumEditSaveKey,
        onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
        child: const Text('Lagre'),
      ),
    ],
  );
}

/// A small coloured badge for a thread's lifecycle status (spec 0066). Shown
/// only for non-open statuses.
class _ThreadStatusBadge extends StatelessWidget {
  const _ThreadStatusBadge(this.status, {this.threadId});

  final ForumThreadStatus status;
  final String? threadId;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (Color background, Color foreground) = switch (status) {
      ForumThreadStatus.planned => (
        dark ? Colors.blue.shade900 : Colors.blue.shade100,
        dark ? Colors.blue.shade100 : Colors.blue.shade900,
      ),
      ForumThreadStatus.done => (
        dark ? Colors.green.shade900 : Colors.green.shade100,
        dark ? Colors.green.shade100 : Colors.green.shade900,
      ),
      ForumThreadStatus.rejected => (
        dark ? Colors.grey.shade700 : Colors.grey.shade300,
        dark ? Colors.grey.shade200 : Colors.grey.shade800,
      ),
      ForumThreadStatus.open => (Colors.transparent, Colors.transparent),
    };
    return Container(
      key: threadId == null ? null : forumStatusBadgeKey(threadId!),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
