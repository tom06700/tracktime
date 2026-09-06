import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _identityKey = 'profile_identity_v1';
const _nameKey = 'profile_name';
const _emojiKey = 'profile_emoji';
const _sinceKey = 'profile_since';

const defaultAvatar = '🍿';

/// Palette d'avatars proposée (aucun upload : 100 % local, léger).
const avatarChoices = <String>[
  '🍿',
  '🎬',
  '📺',
  '🎭',
  '🦸',
  '👾',
  '🐉',
  '🚀',
  '🎃',
  '🕵️',
  '🧙',
  '🤖',
  '👽',
  '🧛',
  '🐺',
  '🌙',
  '⭐',
  '🔥',
  '🎯',
  '🎲',
  '🍕',
  '🎸',
  '🌈',
  '🦄',
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
    final encoded = prefs.getString(_identityKey);
    Map<String, dynamic>? identity;
    if (encoded != null) {
      try {
        final parsed = jsonDecode(encoded);
        if (parsed is Map<String, dynamic> &&
            parsed['name'] is String &&
            parsed['emoji'] is String) {
          identity = parsed;
        }
      } catch (_) {}
    }
    return Profile(
      name: identity?['name'] as String? ?? prefs.getString(_nameKey) ?? '',
      emoji: identity?['emoji'] as String? ??
          prefs.getString(_emojiKey) ??
          defaultAvatar,
      since: DateTime.fromMillisecondsSinceEpoch(sinceMs),
    );
  }

  Future<void> saveIdentity(
      {required String name, required String emoji}) async {
    final current = state.value ?? await future;
    if (!avatarChoices.contains(emoji)) throw ArgumentError('Avatar inconnu');
    final trimmed = name.trim();
    if (trimmed.length > 24) throw ArgumentError('Prénom trop long');
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString(
        _identityKey, jsonEncode({'name': trimmed, 'emoji': emoji}));
    if (!ok) throw StateError('Enregistrement impossible');
    state =
        AsyncData(Profile(name: trimmed, emoji: emoji, since: current.since));
  }

  Future<void> setName(String name) async =>
      saveIdentity(name: name, emoji: (state.value ?? await future).emoji);
  Future<void> setEmoji(String emoji) async =>
      saveIdentity(name: (state.value ?? await future).name, emoji: emoji);
}

final profileProvider =
    AsyncNotifierProvider<ProfileNotifier, Profile>(ProfileNotifier.new);
