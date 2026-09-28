import 'dart:async';

import 'package:flutter/material.dart';

import 'data_source/mock_data_source.dart';
import 'pages/alarm_records_page.dart';
import 'pages/app_shell.dart';
import 'pages/herd_management_page.dart';
import 'pages/login_page.dart';
import 'pages/permission_page.dart';
import 'pages/realtime_monitor_page.dart';
import 'pages/remote_control_page.dart';
import 'pages/report_page.dart';
import 'pages/threshold_settings_page.dart';
import 'pages/video_ai_page.dart';
import 'repositories/repository_bundle.dart';
import 'repositories/repository_factory.dart';
import 'services/app_state.dart';
import 'widgets/app_state_scope.dart';
import 'widgets/app_theme.dart';
import 'widgets/mobile_app_frame.dart';
import 'widgets/repository_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repositories = await createDefaultRepositoryBundle();
  final appState = AppState(dataSource: MockDataSource());
  runApp(SmartPigfarmApp(
    appState: appState,
    repositories: repositories,
  ));
  unawaited(appState.initialize());
}

class SmartPigfarmApp extends StatelessWidget {
  const SmartPigfarmApp({
    super.key,
    required this.appState,
    required this.repositories,
  });

  final AppState appState;
  final RepositoryBundle repositories;

  @override
  Widget build(BuildContext context) {
    return RepositoryScope(
      repositories: repositories,
      child: SmartPigfarmScope(
        notifier: appState,
        child: AnimatedBuilder(
          animation: appState,
          builder: (context, _) {
            return MaterialApp(
              title: '智慧养猪场',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.dark(),
              builder: (context, child) {
                return MobileAppFrame(child: child ?? const SizedBox.shrink());
              },
              home: appState.currentRole == null
                  ? const LoginPage()
                  : const AppShell(),
              routes: {
                '/realtime': (_) => const _StandalonePage(
                      title: '实时监控',
                      child: RealtimeMonitorPage(),
                    ),
                '/control': (_) => const _StandalonePage(
                      title: '远程控制',
                      child: RemoteControlPage(),
                    ),
                '/thresholds': (_) => const _StandalonePage(
                      title: '阈值设置',
                      child: ThresholdSettingsPage(),
                    ),
                '/alarms': (_) => const _StandalonePage(
                      title: '告警记录',
                      child: AlarmRecordsPage(),
                    ),
                '/herd': (_) => const _StandalonePage(
                      title: '猪群管理',
                      child: HerdManagementPage(),
                    ),
                '/reports': (_) => const _StandalonePage(
                      title: '数据报表',
                      child: ReportPage(),
                    ),
                '/video-ai': (_) => const _StandalonePage(
                      title: '猪舍智能视频监控',
                      child: VideoAiPage(),
                    ),
                '/permissions': (_) => const _StandalonePage(
                      title: '权限管理',
                      child: PermissionPage(),
                    ),
              },
            );
          },
        ),
      ),
    );
  }
}

class _StandalonePage extends StatelessWidget {
  const _StandalonePage({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: child,
    );
  }
}
