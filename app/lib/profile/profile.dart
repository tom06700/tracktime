import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _nameKey = 'profile_name';
const _emojiKey = 'profile_emoji';
const _sinceKey = 'profile_since';

const defaultAvatar = '🍿';

/// Palette d'avatars proposée (aucun upload : 100 % local, léger).
const avatarChoices = <String>[
  '🍿', '🎬', '📺', '🎭', '🦸', '👾', '🐉', '🚀',
  '🎃', '🕵️', '🧙', '🤖', '👽', '🧛', '🐺', '🌙',
  '⭐', '🔥', '🎯', '🎲', '🍕', '🎸', '🌈', '🦄',
];

class Profile {
  const Profile({required this.name, required this.emoji, required this.since});

  final String name;
  final String emoji;
  final DateTime since;

  /// Nom affiché, avec repli si l'utilisateur n'en a pas défini.
  String get displayName => name.isEmpty ? 'Cinéphile' : name;

  bool get hasName => name.isNotEmpty;
}

class ProfileNotifier extends AsyncNotifier<Profile> {
  @override
  Future<Profile> build() async {
    final prefs = await SharedPreferences.getInstance();
    // Fixe la date « membre depuis » au premier lancement.
    var sinceMs = prefs.getInt(_sinceKey);
    if (sinceMs == null) {
      sinceMs = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_sinceKey, sinceMs);
    }
    return Profile(
      name: prefs.getString(_nameKey) ?? '',
      emoji: prefs.getString(_emojiKey) ?? defaultAvatar,
      since: DateTime.fromMillisecondsSinceEpoch(sinceMs),
    );
  }

  Future<void> setName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = name.trim();
    await prefs.setString(_nameKey, trimmed);
    final current = state.value;
    if (current != null) {
      state = AsyncData(Profile(
          name: trimmed, emoji: current.emoji, since: current.since));
    }
  }

  Future<void> setEmoji(String emoji) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emojiKey, emoji);
    final current = state.value;
    if (current != null) {
      state = AsyncData(
          Profile(name: current.name, emoji: emoji, since: current.since));
    }
  }
}

final profileProvider =
    AsyncNotifierProvider<ProfileNotifier, Profile>(ProfileNotifier.new);
