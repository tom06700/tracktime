import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import '../../theme.dart';
import '../../widgets/media_image.dart';
import '../../widgets/modern_controls.dart';
import '../feed.dart';

/// Image, title and actions are one scrolling card, as in reference 03.
class ContinueWatchingHero extends ConsumerWidget {
  const ContinueWatchingHero(
      {super.key,
      required this.next,
      required this.onOpen,
      required this.onOpenShow,
      required this.onMarkWatched,
      this.confirmed = false});
  final NextUp next;
  final VoidCallback onOpen, onOpenShow;
  final Future<void> Function() onMarkWatched;
  final bool confirmed;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = next;
    final detail = ref.watch(seriesDetailProvider(n.show.id)).value;
    final shows = ref.watch(showsProvider).value ?? const [];
    final matches = shows.where((s) => s.show.id == n.show.id);
    final progress = matches.isEmpty ? null : matches.first;
    final total = n.show.totalEpisodes;
    final known = total != null && total > 0 && progress != null;
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(29),
            child: ColoredBox(
                color: const Color(0xFF14171E),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                          height: MediaQuery.sizeOf(context).width < 380
                              ? 275
                              : 302,
                          child: Stack(fit: StackFit.expand, children: [
                            MediaImage(sources: [
                              detail?.poster,
                              n.show.poster,
                              detail?.backdrop,
                              n.still
                            ], seed: n.show.name),
                            const DecoratedBox(
                                decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                  Color(0x22101113),
                                  Colors.transparent,
                                  Color(0x8814171E),
                                  Color(0xFF14171E)
                                ],
                                        stops: [
                                  0,
                                  .48,
                                  .8,
                                  1
                                ]))),
                            Positioned(
                                left: 21,
                                right: 21,
                                bottom: 20,
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(n.code.replaceAll(' | ', ' · '),
                                          style: const TextStyle(
                                              color: ModernPalette.lime,
                                              fontSize: 12,
                                              letterSpacing: 1)),
                                      const SizedBox(height: 6),
                                      Semantics(
                                          button: true,
                                          label:
                                              'Ouvrir la série ${n.show.name}',
                                          child: GestureDetector(
                                              onTap: onOpenShow,
                                              child: Text(n.show.name,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 28,
                                                      height: 1.1,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Colors.white)))),
                                      const SizedBox(height: 6),
                                      Text(
                                          n.episodeName?.isNotEmpty == true
                                              ? n.episodeName!
                                              : 'La suite t’attend.',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFFDDDFE6))),
                                    ])),
                          ])),
                      Padding(
                          padding: const EdgeInsets.fromLTRB(16, 3, 16, 17),
                          child: Column(children: [
                            Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                      child: Text(
                                          known
                                              ? '${progress.watchedCount} / $total épisodes'
                                              : 'Prochain épisode à voir',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: TtColors.dim))),
                                  if (known)
                                    Text(
                                        '${(progress.progress * 100).round()} %',
                                        style: const TextStyle(
                                            fontSize: 12, color: TtColors.dim)),
                                ]),
                            if (known) ...[
                              const SizedBox(height: 10),
                              Semantics(
                                  label: 'Progression',
                                  value:
                                      '${progress.watchedCount} sur $total épisodes',
                                  child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                          value: progress.progress,
                                          minHeight: 4,
                                          backgroundColor:
                                              const Color(0xFF34383F),
                                          color: ModernPalette.lime)))
                            ],
                            const SizedBox(height: 16),
                            LayoutBuilder(builder: (context, c) {
                              final open = ModernCommand(
                                  shape: CommandShape.nextUp,
                                  compact: true,
                                  label: 'Ouvrir',
                                  onPressed: onOpen);
                              final watched = ModernCommand(
                                  shape: CommandShape.softCheck,
                                  compact: true,
                                  label: confirmed ? 'Vu !' : 'Marquer vu',
                                  selected: confirmed,
                                  onPressed: confirmed ? null : onMarkWatched);
                              if (c.maxWidth < 310 ||
                                  MediaQuery.textScalerOf(context).scale(13) >
                                      18) {
                                return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      open,
                                      const SizedBox(height: 9),
                                      watched
                                    ]);
                              }
                              return Row(children: [
                                Expanded(child: open),
                                const SizedBox(width: 9),
                                Expanded(child: watched)
                              ]);
                            }),
                          ])),
                    ]))));
  }
}
