import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../providers.dart';
import '../widgets/media_image.dart';
import '../widgets/states.dart';
import 'feed.dart';
import 'providers.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _saving = false;

  Future<void> _read(Iterable<String> ids, {ReleaseNotification? open}) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(notificationReadProvider.notifier).markRead(ids);
      if (mounted && open != null) {
        context.push(open.location, extra: open.extra);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de marquer comme lu. Réessaie.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(releaseNotificationsProvider);
    final read = ref.watch(notificationReadProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        top: false,
        child: feed.when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _error(() {
            ref.invalidate(showsProvider);
            ref.invalidate(moviesProvider);
            ref.invalidate(notificationEpisodesProvider);
            ref.invalidate(releaseNotificationsProvider);
          }),
          data: (items) => read.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) =>
                _error(() => ref.invalidate(notificationReadProvider)),
            data: (readIds) {
              if (items.isEmpty) return const _EmptyNotifications();
              final unread = items.where((n) => !readIds.contains(n.id)).length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 8, 12, 12),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      children: [
                        Text(
                          unread == 0
                              ? 'Tu es à jour'
                              : '$unread non ${unread == 1 ? 'lue' : 'lues'}',
                          style: const TextStyle(
                            color: TtColors.dim,
                            fontSize: 13,
                          ),
                        ),
                        TextButton(
                          onPressed: unread == 0 || _saving
                              ? null
                              : () => _read(items.map((n) => n.id)),
                          child: const Text('Tout lire'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      itemCount: items.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        if (index == items.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 16,
                            ),
                            child: Text(
                              'Diffusions et sorties des 30 derniers jours.',
                              style: TextStyle(
                                color: TtColors.dim,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }
                        final item = items[index];
                        return _ReleaseTile(
                          item: item,
                          unread: !readIds.contains(item.id),
                          onTap: _saving
                              ? null
                              : () => _read([item.id], open: item),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _error(VoidCallback retry) => ErrorRetry(
    title: 'Notifications indisponibles',
    message: 'Réessaie pour retrouver les nouveautés de ta collection.',
    onRetry: retry,
  );
}

class _ReleaseTile extends StatelessWidget {
  const _ReleaseTile({
    required this.item,
    required this.unread,
    required this.onTap,
  });
  final ReleaseNotification item;
  final bool unread;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final episode = item.kind == ReleaseKind.episode;
    final color = episode ? TtColors.amber : const Color(0xFFCAB7FF);
    final date =
        '${item.day.day.toString().padLeft(2, '0')}/${item.day.month.toString().padLeft(2, '0')}/${item.day.year}';
    final status = episode ? 'Diffusion' : 'Sortie';
    return Semantics(
      label: unread ? 'Non lue' : 'Lue',
      child: Material(
        color: unread ? TtColors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 46,
                      height: 68,
                      child: MediaImage(
                        sources: [item.poster],
                        seed: item.title,
                        icon: episode
                            ? Icons.tv_outlined
                            : Icons.movie_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        episode ? 'NOUVEL ÉPISODE' : 'SORTIE FILM',
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .8,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.detail,
                        style: const TextStyle(
                          fontSize: 12,
                          color: TtColors.dim,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '$status · $date',
                        style: const TextStyle(
                          fontSize: 11,
                          color: TtColors.dim,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: unread
                      ? Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        )
                      : const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: TtColors.dim,
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

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              color: TtColors.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 34,
              color: TtColors.amber,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Rien de nouveau\npour le moment',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Les nouveaux épisodes et les sorties de ta collection apparaîtront ici.',
            textAlign: TextAlign.center,
            style: TextStyle(color: TtColors.dim, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    ),
  );
}
