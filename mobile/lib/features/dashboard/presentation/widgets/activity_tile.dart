import 'package:flutter/material.dart';

import '../../../../models/app_user.dart';
import '../../../../ui/components/user_avatar.dart';
import '../../../../ui/theme/checktap_colors.dart';
import '../../../../ui/theme/checktap_spacing.dart';
import '../../domain/dashboard_snapshot.dart';

class ActivityTile extends StatelessWidget {
  const ActivityTile({required this.activity, super.key});

  final DashboardActivity activity;

  String _relativeTime(DateTime value) {
    final difference = DateTime.now().difference(value.toLocal());
    if (difference.inMinutes < 1) {
      return 'Ahora';
    }
    if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} min';
    }
    if (difference.inHours < 24) {
      return 'Hace ${difference.inHours} h';
    }
    return 'Hace ${difference.inDays} d';
  }

  @override
  Widget build(BuildContext context) {
    final user = AppUser(id: activity.actor, name: activity.actor, email: '');
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CheckTapSpacing.md,
        vertical: CheckTapSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(CheckTapRadius.md),
        border: Border.all(color: CheckTapColors.borderFor(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          UserAvatar.fromUser(user, radius: 18),
          const SizedBox(width: CheckTapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text.rich(
                  TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium,
                    children: <InlineSpan>[
                      TextSpan(
                        text: activity.actor,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(text: ' ${activity.action} '),
                      TextSpan(
                        text: '“${activity.taskTitle}”',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  _relativeTime(activity.at),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CheckTapColors.textMutedFor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
