import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'profile.dart';
import '../widgets/modern_controls.dart';

Future<void> editProfile(BuildContext context, Profile profile) =>
    showDialog<void>(
        context: context, builder: (_) => _IdentityEditor(profile: profile));

class _IdentityEditor extends ConsumerStatefulWidget {
  const _IdentityEditor({required this.profile});
  final Profile profile;
  @override
  ConsumerState<_IdentityEditor> createState() => _IdentityEditorState();
}

class _IdentityEditorState extends ConsumerState<_IdentityEditor> {
  late final _name = TextEditingController(text: widget.profile.name);
  late String _emoji = widget.profile.emoji;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(profileProvider.notifier)
          .saveIdentity(name: _name.text, emoji: _emoji);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Enregistrement impossible. Réessaie.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_busy,
      child: AlertDialog(
          backgroundColor: const Color(0xFF1D1922),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
          title: const Text('Ton profil'),
          content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    TextField(
                        controller: _name,
                        enabled: !_busy,
                        maxLength: 24,
                        decoration:
                            const InputDecoration(labelText: 'Ton prénom')),
                    const SizedBox(height: 12),
                    const Text('Ton avatar'),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final emoji in avatarChoices)
                        Semantics(
                            label: 'Avatar $emoji',
                            selected: _emoji == emoji,
                            child: IconButton(
                                onPressed: _busy
                                    ? null
                                    : () => setState(() => _emoji = emoji),
                                style: IconButton.styleFrom(
                                    backgroundColor: _emoji == emoji
                                        ? ModernPalette.lilac
                                        : const Color(0xFF30223C),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16))),
                                icon: Text(emoji,
                                    style: const TextStyle(fontSize: 24))))
                    ]),
                    if (_error != null)
                      Text(_error!,
                          style: const TextStyle(color: Colors.redAccent)),
                  ]))),
          actions: [
            TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: const Text('Annuler')),
            FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Enregistrement…' : 'Enregistrer'))
          ]));
}
