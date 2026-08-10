import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../theme/checktap_colors.dart';
import '../theme/checktap_spacing.dart';
import 'checktap_logo.dart';
import 'user_avatar.dart';

class CheckTapTopBar extends StatelessWidget implements PreferredSizeWidget {
  const CheckTapTopBar({
    required this.title,
    required this.onMenu,
    required this.connectionIcon,
    required this.connectionTooltip,
    required this.onSync,
    this.syncing = false,
    this.pendingOperations = 0,
    super.key,
  });

  final Widget title;
  final VoidCallback onMenu;
  final IconData connectionIcon;
  final String connectionTooltip;
  final VoidCallback onSync;
  final bool syncing;
  final int pendingOperations;

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 68,
      leadingWidth: 64,
      leading: Padding(
        padding: const EdgeInsets.only(left: CheckTapSpacing.sm),
        child: IconButton(
          tooltip: 'Abrir menú',
          onPressed: onMenu,
          icon: const Icon(Icons.menu_rounded),
        ),
      ),
      title: title,
      actions: <Widget>[
        if (pendingOperations > 0)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Badge(
              label: Text('$pendingOperations'),
              child: const Icon(Icons.sync_problem_rounded),
            ),
          ),
        IconButton(
          tooltip: 'Sincronizar ahora',
          onPressed: syncing ? null : onSync,
          icon: syncing
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync_rounded),
        ),
        Tooltip(
          message: connectionTooltip,
          child: Padding(
            padding: const EdgeInsets.only(right: CheckTapSpacing.md),
            child: Icon(connectionIcon),
          ),
        ),
      ],
    );
  }
}

class CheckTapDrawer extends StatelessWidget {
  const CheckTapDrawer({
    required this.user,
    required this.onAccessRequests,
    required this.onUsers,
    required this.onDepartments,
    required this.onReports,
    required this.onNotifications,
    required this.onLogout,
    required this.pendingOperations,
    this.isAdmin = false,
    super.key,
  });

  final AppUser user;
  final VoidCallback onAccessRequests;
  final VoidCallback onUsers;
  final VoidCallback onDepartments;
  final VoidCallback onReports;
  final VoidCallback onNotifications;
  final VoidCallback onLogout;
  final int pendingOperations;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.sizeOf(context).width.clamp(280, 340).toDouble(),
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
              decoration: const BoxDecoration(
                gradient: CheckTapColors.brandGradient,
                borderRadius: BorderRadius.only(
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      UserAvatar.fromUser(
                        user,
                        radius: 28,
                        showOnlineDot: true,
                      ),
                      const SizedBox(width: CheckTapSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              user.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.86),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CheckTapSpacing.lg),
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.circle,
                        size: 9,
                        color: Color(0xFF61E6BA),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'En línea',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      const CheckTapWordmark(fontSize: 15),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  vertical: CheckTapSpacing.sm,
                ),
                children: <Widget>[
                  _DrawerItem(
                    icon: Icons.person_outline_rounded,
                    label: 'Perfil',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  if (isAdmin)
                    _DrawerItem(
                      icon: Icons.how_to_reg_outlined,
                      label: 'Solicitudes de acceso',
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                      ),
                      onTap: onAccessRequests,
                    ),
                  if (isAdmin)
                    _DrawerItem(
                      icon: Icons.apartment_rounded,
                      label: 'Departamentos',
                      onTap: onDepartments,
                    ),
                  if (isAdmin)
                    _DrawerItem(
                      icon: Icons.group_outlined,
                      label: 'Usuarios',
                      onTap: onUsers,
                    ),
                  _DrawerItem(
                    icon: Icons.notifications_none_rounded,
                    label: 'Notificaciones',
                    trailing: const Badge(label: Text('')),
                    onTap: onNotifications,
                  ),
                  _DrawerItem(
                    icon: Icons.picture_as_pdf_outlined,
                    label: 'Informes',
                    onTap: onReports,
                  ),
                  _DrawerItem(
                    icon: Icons.sync_rounded,
                    label: 'Sincronización',
                    trailing: pendingOperations > 0
                        ? Text(
                            '$pendingOperations pendiente(s)',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: CheckTapColors.warning),
                          )
                        : const Icon(
                            Icons.check_circle_outline_rounded,
                            color: CheckTapColors.success,
                            size: 20,
                          ),
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Divider(),
                  ),
                  _DrawerItem(
                    icon: Icons.help_outline_rounded,
                    label: 'Ayuda y soporte',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: CheckTapColors.danger,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Cerrar sesión'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 52,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(icon, color: CheckTapColors.textMutedFor(context)),
      title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
