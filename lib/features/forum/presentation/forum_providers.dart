// SPDX-FileCopyrightText: 2026 Roy Kollen Svendsen
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:treffpunkt/features/auth/domain/auth_status.dart';
import 'package:treffpunkt/features/auth/presentation/auth_providers.dart';
import 'package:treffpunkt/features/forum/data/forum_repository.dart';
import 'package:treffpunkt/features/forum/domain/forum_post.dart';
import 'package:treffpunkt/features/forum/domain/forum_thread.dart';

/// The app's [ForumRepository] (spec 0054). Defaults to in-memory; `main()`
/// overrides it with the Supabase-backed one.
final forumRepositoryProvider = Provider<ForumRepository>(
  (ref) => InMemoryForumRepository(),
);

/// The signed-in user's id, or `null` when signed out — stamps a new thread's
/// or reply's author and decides who may delete.
final forumCurrentUserIdProvider = Provider<String?>((ref) {
  final status = ref.watch(authStateChangesProvider).value;
  return status is SignedIn ? status.user.id : null;
});

/// Whether the signed-in user is a forum moderator (spec 0054).
final forumIsAdminProvider = FutureProvider<bool>(
  (ref) => ref.watch(forumRepositoryProvider).isAdmin(),
);

/// Robot Hood's last heartbeat (spec 0122), refreshed with the forum list.
final robotSeenAtProvider = FutureProvider<DateTime?>(
  (ref) => ref.watch(forumRepositoryProvider).robotSeenAt(),
);

/// The live list of all forum threads, newest first (spec 0054).
final forumThreadsProvider = StreamProvider<List<ForumThread>>(
  (ref) => ref.watch(forumRepositoryProvider).watchThreads(),
);

/// The live replies of one thread, oldest first (spec 0054).
// ignore: specify_nonobvious_property_types
final forumPostsProvider = StreamProvider.family<List<ForumPost>, String>(
  (ref, threadId) => ref.watch(forumRepositoryProvider).watchPosts(threadId),
);

/// Picks one image for a forum attachment, or `null` when cancelled (spec
/// 0056).
typedef ForumImagePicker = Future<XFile?> Function();

/// The image picker for a forum attachment — a seam so a widget test can inject
/// a canned file instead of the OS gallery (spec 0056).
final forumImagePickerProvider = Provider<ForumImagePicker>(
  (ref) =>
      () =>
          ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600),
);
