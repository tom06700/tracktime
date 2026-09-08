import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import 'providers.dart';

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(hasUnreadNotificationsProvider);
    return IconButton(
      tooltip: unread ? 'Notifications, nouveautés non lues' : 'Notifications',
      onPressed: () => context.push('/notifications'),
      icon: Badge(
        isLabelVisible: unread,
        backgroundColor: TtColors.amber,
        smallSize: 7,
        child: const Icon(Icons.notifications_none_rounded, size: 23),
      ),
    );
  }
}
