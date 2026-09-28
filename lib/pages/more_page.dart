import 'package:flutter/material.dart';

import '../widgets/page_scaffold.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = const [
      _MoreEntry('阈值设置', '配置环境与健康预警范围', Icons.rule_outlined, '/thresholds'),
      _MoreEntry('猪群管理', '查看猪只档案与个体状态', Icons.agriculture_outlined, '/herd'),
      _MoreEntry('数据报表', '查看养殖与环境趋势', Icons.show_chart_outlined, '/reports'),
      _MoreEntry('视频监控', '查看实时或本地监控画面', Icons.videocam_outlined, '/video-ai'),
      _MoreEntry(
          '权限管理', '查看不同角色访问范围', Icons.manage_accounts_outlined, '/permissions'),
      _MoreEntry('实时监控', '查看当前环境指标', Icons.monitor_heart_outlined, '/realtime'),
      _MoreEntry('远程控制', '设备控制流程与状态', Icons.tune_outlined, '/control'),
      _MoreEntry(
          '告警记录', '查看环境和猪只异常', Icons.notifications_active_outlined, '/alarms'),
    ];
    return PageScaffold(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 500 ? 2 : 4;
            final aspectRatio = switch (constraints.maxWidth) {
              < 500 => 1.05,
              < 650 => 0.9,
              < 900 => 1.25,
              < 1100 => 1.65,
              _ => 2.1,
            };
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: aspectRatio,
              ),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return Card(
                  key: Key('more-entry-${entry.route}'),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.of(context).pushNamed(entry.route),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(entry.icon, size: 26),
                          const SizedBox(height: 12),
                          Text(
                            entry.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _MoreEntry {
  const _MoreEntry(this.title, this.description, this.icon, this.route);

  final String title;
  final String description;
  final IconData icon;
  final String route;
}
