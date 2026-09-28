import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../widgets/app_theme.dart';
import '../widgets/page_scaffold.dart';
import '../widgets/status_badge.dart';

class PermissionPage extends StatelessWidget {
  const PermissionPage({super.key});

  @override
  Widget build(BuildContext context) {
    const roles = UserRole.values;
    const permissions = Permission.values;
    return PageScaffold(
      children: [
        Text(
          '角色权限矩阵',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        Text(
          '场长管理员、饲养员操作员、游客三种角色按岗位权限分级管理。',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFA7BDB5),
              ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppTheme.surfaceAlt),
            border:
                TableBorder.all(color: Colors.white.withValues(alpha: 0.08)),
            columns: const [
              DataColumn(label: Text('权限')),
              DataColumn(label: Text('场长')),
              DataColumn(label: Text('饲养员')),
              DataColumn(label: Text('游客')),
            ],
            rows: permissions.map((permission) {
              return DataRow(
                cells: [
                  DataCell(Text(permission.label)),
                  ...roles.map((role) {
                    final allowed = hasPermission(role, permission);
                    return DataCell(
                      Icon(
                        allowed
                            ? Icons.check_circle
                            : Icons.remove_circle_outline,
                        color: allowed
                            ? AppTheme.primary
                            : const Color(0xFF5F766F),
                        size: 20,
                      ),
                    );
                  }),
                ],
              );
            }).toList(),
          ),
        ),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusBadge(
              label: '场长管理员：全权限',
              color: AppTheme.primary,
              icon: Icons.admin_panel_settings_outlined,
            ),
            StatusBadge(
              label: '饲养员：运行操作',
              color: AppTheme.secondary,
              icon: Icons.engineering_outlined,
            ),
            StatusBadge(
              label: '游客：只读展示',
              color: Color(0xFFA78BFA),
              icon: Icons.visibility_outlined,
            ),
          ],
        ),
      ],
    );
  }
}
