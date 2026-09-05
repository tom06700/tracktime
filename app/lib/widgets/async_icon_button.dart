import 'package:flutter/material.dart';

/// Keeps a database action single-flight and reports failed persistence.
class AsyncIconButton extends StatefulWidget {
  const AsyncIconButton(
      {super.key,
      required this.icon,
      required this.tooltip,
      required this.onPressed,
      this.color});
  final Widget icon;
  final String tooltip;
  final Future<void> Function() onPressed;
  final Color? color;

  @override
  State<AsyncIconButton> createState() => _AsyncIconButtonState();
}

class _AsyncIconButtonState extends State<AsyncIconButton> {
  bool _busy = false;
  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onPressed();
    } catch (error, stack) {
      debugPrint('Action non enregistrée : $error\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Impossible d’enregistrer la modification. Réessaie.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: widget.tooltip,
        color: widget.color,
        onPressed: _busy ? null : _run,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : widget.icon,
      );
}
