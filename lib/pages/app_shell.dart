import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../widgets/app_state_scope.dart';
import '../widgets/app_theme.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/status_badge.dart';
import 'alarm_records_page.dart';
import 'dashboard_page.dart';
import 'herd_management_page.dart';
import 'more_page.dart';
import 'realtime_monitor_page.dart';
import 'remote_control_page.dart';
import 'report_page.dart';
import 'video_ai_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _desktopIndex = 0;
  int _mobileIndex = 0;

  static const _desktopDestinations = <_ShellDestination>[
    _ShellDestination(
        '首页', '智慧养殖概览', Icons.space_dashboard_outlined, Icons.space_dashboard),
    _ShellDestination(
        '实时监测', '实时环境监测', Icons.monitor_heart_outlined, Icons.monitor_heart),
    _ShellDestination('设备控制', '设备控制终端', Icons.tune_outlined, Icons.tune),
    _ShellDestination('猪群管理', '猪群管理', Icons.pets_outlined, Icons.pets),
    _ShellDestination(
        '健康告警', '健康告警', Icons.notifications_outlined, Icons.notifications),
    _ShellDestination(
        '数据报表', '数据报表', Icons.insert_chart_outlined, Icons.insert_chart),
    _ShellDestination('视频监控', '视频监控', Icons.videocam_outlined, Icons.videocam),
    _ShellDestination('更多', '设置与管理', Icons.grid_view_outlined, Icons.grid_view),
  ];

  static const _mobileDestinationIndexes = <int>[0, 1, 2, 4, 7];

  Widget _pageFor(int index) => switch (index) {
        0 => const DashboardPage(),
        1 => const RealtimeMonitorPage(),
        2 => const RemoteControlPage(),
        3 => const HerdManagementPage(),
        4 => const AlarmRecordsPage(),
        5 => const ReportPage(),
        6 => const VideoAiPage(showHeader: false),
        _ => const MorePage(),
      };

  @override
  Widget build(BuildContext context) {
    final state = SmartPigfarmScope.watch(context);
    final role = state.currentRole;
    return LayoutBuilder(
      builder: (context, constraints) {
        final useNavigationRail = constraints.maxWidth >= AppBreakpoints.tablet;
        final selectedIndex = useNavigationRail
            ? _desktopIndex
            : _mobileDestinationIndexes[_mobileIndex];
        final title = _desktopDestinations[selectedIndex].pageTitle;
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: useNavigationRail ? 64 : 58,
            title: Text(title),
            actions: [
              if (useNavigationRail && role != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(
                    child: StatusBadge(
                      label: role.title,
                      color: _roleColor(role),
                      icon: Icons.verified_user_outlined,
                    ),
                  ),
                ),
              IconButton(
                tooltip: '退出登录',
                onPressed: state.logout,
                icon: const Icon(Icons.logout, size: 21),
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: useNavigationRail
              ? Row(
                  children: [
                    Container(
                      width: 104,
                      decoration: const BoxDecoration(
                        color: AppTheme.surface,
                        border: Border(
                          right: BorderSide(color: AppTheme.borderSoft),
                        ),
                      ),
                      child: NavigationRail(
                        minWidth: 104,
                        groupAlignment: -0.92,
                        selectedIndex: _desktopIndex,
                        onDestinationSelected: (value) {
                          setState(() => _desktopIndex = value);
                        },
                        labelType: NavigationRailLabelType.all,
                        leading: const Padding(
                          padding: EdgeInsets.only(bottom: 18),
                          child: _FarmMark(),
                        ),
                        destinations: _desktopDestinations
                            .map(
                              (item) => NavigationRailDestination(
                                icon: Icon(item.icon),
                                selectedIcon: Icon(item.selectedIcon),
                                label: Text(item.label),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        child: KeyedSubtree(
                          key: ValueKey(_desktopIndex),
                          child: _pageFor(_desktopIndex),
                        ),
                      ),
                    ),
                  ],
                )
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 140),
                  child: KeyedSubtree(
                    key: ValueKey(selectedIndex),
                    child: _pageFor(selectedIndex),
                  ),
                ),
          bottomNavigationBar: useNavigationRail
              ? null
              : NavigationBar(
                  selectedIndex: _mobileIndex,
                  onDestinationSelected: (value) {
                    setState(() => _mobileIndex = value);
                  },
                  destinations: _mobileDestinationIndexes.map((index) {
                    final item = _desktopDestinations[index];
                    return NavigationDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.selectedIcon),
                      label: item.label == '健康告警' ? '告警' : item.label,
                    );
                  }).toList(growable: false),
                ),
        );
      },
    );
  }

  Color _roleColor(UserRole role) => switch (role) {
        UserRole.manager => AppTheme.primary,
        UserRole.operator => AppTheme.secondary,
        UserRole.visitor => AppTheme.textSecondary,
      };
}

class _FarmMark extends StatelessWidget {
  const _FarmMark();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '智慧养殖管理终端',
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.24)),
        ),
        child: const Icon(Icons.agriculture_outlined,
            color: AppTheme.primary, size: 24),
      ),
    );
  }
}

class _ShellDestination {
  const _ShellDestination(
    this.label,
    this.pageTitle,
    this.icon,
    this.selectedIcon,
  );

  final String label;
  final String pageTitle;
  final IconData icon;
  final IconData selectedIcon;
}
