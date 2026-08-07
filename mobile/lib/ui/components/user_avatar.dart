import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../theme/checktap_colors.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    required this.name,
    this.radius = 18,
    this.backgroundColor,
    this.showOnlineDot = false,
    super.key,
  });

  factory UserAvatar.fromUser(
    AppUser user, {
    double radius = 18,
    bool showOnlineDot = false,
    Key? key,
  }) {
    return UserAvatar(
      key: key,
      name: user.name,
      radius: radius,
      showOnlineDot: showOnlineDot,
    );
  }

  final String name;
  final double radius;
  final Color? backgroundColor;
  final bool showOnlineDot;

  String get _initials {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .toList(growable: false);
    if (words.isEmpty) {
      return '?';
    }
    return words.map((word) => word[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: name,
      child: SizedBox.square(
        dimension: radius * 2,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            CircleAvatar(
              radius: radius,
              backgroundColor: backgroundColor ?? const Color(0xFFE8F0FF),
              foregroundColor: CheckTapColors.primary,
              child: Text(
                _initials,
                style: TextStyle(
                  fontSize: radius * 0.72,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (showOnlineDot)
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: radius * 0.58,
                  height: radius * 0.58,
                  decoration: BoxDecoration(
                    color: CheckTapColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class UserAvatarStack extends StatelessWidget {
  const UserAvatarStack({
    required this.users,
    this.maxVisible = 3,
    this.radius = 14,
    super.key,
  });

  final List<AppUser> users;
  final int maxVisible;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.groups_2_outlined,
            size: 18,
            color: Theme.of(context).hintColor,
          ),
          const SizedBox(width: 6),
          Text('Todo el equipo', style: Theme.of(context).textTheme.bodySmall),
        ],
      );
    }

    final visible = users.take(maxVisible).toList(growable: false);
    final overflow = users.length - visible.length;
    final avatarSize = radius * 2;
    final overlap = radius * 0.7;
    final width =
        avatarSize +
        (visible.length - 1) * (avatarSize - overlap) +
        (overflow > 0 ? avatarSize - overlap : 0);

    return SizedBox(
      width: width,
      height: avatarSize,
      child: Stack(
        children: <Widget>[
          for (var index = 0; index < visible.length; index++)
            Positioned(
              left: index * (avatarSize - overlap),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 2,
                  ),
                ),
                child: UserAvatar.fromUser(visible[index], radius: radius),
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: visible.length * (avatarSize - overlap),
              child: CircleAvatar(
                radius: radius,
                backgroundColor: CheckTapColors.navy,
                foregroundColor: Colors.white,
                child: Text(
                  '+$overflow',
                  style: TextStyle(
                    fontSize: radius * 0.7,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
