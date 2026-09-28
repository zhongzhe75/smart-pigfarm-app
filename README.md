# smart_pigfarm_app

智慧养猪场管理 App 预演版，用于创新创业大赛展示。当前项目使用 Flutter + Material Design，界面按真实 PLC 工控系统呈现，传感器数据、设备状态、告警、视频 AI 结果由本地展示数据源驱动，支持离线展示运行。

## 功能

- 三种角色：场长管理员、饲养员操作员、游客查看
- 首页仪表盘：猪舍 A01、环境评分、五类传感器、告警、存栏、耗料、设备联动状态
- 实时监控：温度、湿度、氨气、CO₂、光照度每 2 秒自动刷新
- 远程控制：风机、喷雾泵、加热风扇、LED 补光、喂料输送线，支持自动/手动模式
- 阈值设置：温湿度上下限、氨气上限、CO₂ 上限、光照下限
- 告警记录：环境超限、设备故障、料位不足、AI 异常事件，支持告警联动和处理状态
- 猪群管理：存栏、平均体重、采食量、料肉比、免疫记录、预计出栏、出栏统计
- 数据报表：温度、湿度、光照、耗料曲线，通风/喷雾时长和成本核算
- 视频 AI：摄像头占位、AI 看猪、咳嗽异常、仔猪防压、异常聚集、采食行为分析
- 权限管理：角色权限矩阵

## 项目结构

```text
smart_pigfarm_app/
  lib/
    main.dart
    database/
      app_database.dart         # Android SQLite v1 schema and seed transaction
    data_source/
      data_source.dart          # 数据源抽象层
      mock_data_source.dart     # 本地展示数据源
      api_data_source.dart      # PLC 网关 API 扩展接口
    models/
      ai_insight.dart
      alarm_record.dart
      device_status.dart
      operation_record.dart
      pig.dart
      pig_daily_stat.dart
      pig_detail.dart
      health_alert.dart
      immunization_record.dart
      environment_record.dart
      herd_daily_aggregate.dart
      ai_behavior_record.dart
      pig_house_profile.dart
      report_data.dart
      sensor_snapshot.dart
      threshold_settings.dart
      user_role.dart
    pages/
      alarm_records_page.dart
      app_shell.dart
      dashboard_page.dart
      herd_management_page.dart
      login_page.dart
      more_page.dart
      permission_page.dart
      realtime_monitor_page.dart
      remote_control_page.dart
      report_page.dart
      threshold_settings_page.dart
      video_ai_page.dart
    services/
      alarm_service.dart        # 告警判断与告警联动
      app_state.dart            # 全局状态、2 秒刷新、控制流转
      behavior_health_scoring_service.dart
      control_service.dart      # 远程控制权限与操作记录
      formatters.dart
      health_alert_service.dart
      pig_farm_seed_data_generator.dart
      simulation_service.dart   # 展示数据生成
    repositories/
      pig_repository.dart
      pig_metrics_repository.dart
      health_alert_repository.dart
      environment_repository.dart
      ai_behavior_repository.dart
      in_memory_repository_store.dart
      sqlite_repository_store.dart
      repository_bundle.dart
      repository_factory.dart
      repository_factory_memory.dart
      repository_factory_sqlite.dart
    widgets/
      app_state_scope.dart
      app_theme.dart
      device_status_tile.dart
      line_chart_card.dart
      metric_card.dart
      page_scaffold.dart
      repository_scope.dart
      status_badge.dart
  test/
    behavior_health_scoring_service_test.dart
    repository_test.dart
    seed_data_generator_test.dart
    smoke_test.dart
```

## 运行

当前项目源码已经就绪，但运行前需要电脑能识别 `flutter` 命令。可先执行：

```bash
flutter --version
```

如果提示找不到命令，请先安装 Flutter SDK，并把 Flutter SDK 的 `bin` 目录加入 Windows PATH。

安装好 Flutter 后，可以直接运行一键检查脚本：

```powershell
cd D:\Abox\smart_pigfarm_app
powershell -ExecutionPolicy Bypass -File .\scripts\run_flutter_check.ps1
```

也可以手动执行：

```bash
cd smart_pigfarm_app
flutter create . --project-name smart_pigfarm_app --platforms=android,web
flutter pub get
flutter run
```

执行 `flutter create .` 的目的只是补齐 `android/`、`web/` 等平台运行壳；如果 Flutter 提示已有文件冲突，请保留当前 `lib/`、`pubspec.yaml`、`analysis_options.yaml` 和 `README.md`。

如果只想快速查看页面，也可以运行：

```bash
flutter run -d chrome
```

## 角色权限

- 场长管理员：全功能，包括阈值修改、告警联动、告警处理和远程控制。
- 饲养员操作员：可查看、远程控制、处理告警、查看报表和视频 AI，不可修改阈值。
- 游客查看：只读展示，不能远程控制、不能修改阈值、不能生成告警事件。

## PLC 网关接口扩展

项目已保留数据源抽象层，`lib/data_source/api_data_source.dart` 可用于实现传感器读取、设备状态读取、控制指令下发、阈值保存、告警同步和 AI 结果读取等接口。

## V2 数据底座

V2 第一阶段在不重写现有页面的前提下，增加了单猪数字档案、每日指标、健康风险评分、个体健康告警、免疫记录和环境历史的领域与 Repository 层。

- Android：使用版本化 SQLite 数据库 `smart_pigfarm_v2.db`。
- Web：使用相同 Repository 接口的内存实现，不强制在浏览器内运行 SQLite。
- 种子数据：180 头猪、90 天、16,200 条个体每日指标，以及三个猪舍每天 4 个采样点的环境历史。
- 数据生成使用固定 seed 和确定性噪声，包含连续异常与部分恢复趋势。
- `AppState` 仍只负责原有登录、环境、设备、告警和导航状态，不持有全量个体历史。
- `AiBehaviorRepository` 仅预留接口，当前返回空数据，不包含真实 AI 或摄像头集成。

健康分为 0-100 的行为风险评分，主要对比单猪自身过去 7 日的采食、活动和增重基线，并考虑连续异常。该分数用于饲养巡检排序，不是疾病诊断。
# Phase 4 runtime modes

The project uses one codebase and the compile-time `APP_RUNTIME_MODE` value:

- `auto`: Android resolves to `padLive`; Web resolves to `webLocal`.
- `webLocal`: local asset video on Web.
- `webLive`: H6c live video on Web through official `ezuikit-js` 9.0.15.
- `padLocal`: local asset video on Android without initializing EZVIZ.
- `padLive`: the existing H6c Android live-video path.

Build commands:

```text
flutter build web --release --dart-define=APP_RUNTIME_MODE=webLocal
flutter build web --release --dart-define=APP_RUNTIME_MODE=webLive --dart-define=EZVIZ_ACCESS_TOKEN=PLACEHOLDER --dart-define=EZVIZ_DEVICE_SERIAL=PLACEHOLDER --dart-define=EZVIZ_VERIFY_CODE=PLACEHOLDER
flutter build apk --release --dart-define=APP_RUNTIME_MODE=padLocal
flutter build apk --release --dart-define=APP_RUNTIME_MODE=padLive
```

`webLive` uses only the short-lived browser authorization values shown above.
Never pass the EZVIZ Secret to Flutter, JavaScript, `index.html`, or a Web build.
Values compiled with `--dart-define` are visible to browser users, so this setup
is for the competition prototype only. A production deployment must keep the
Secret on a backend and issue short-lived authorization to the browser.

Place the real local recording at
`assets/videos/pig_house_demo.mp4`, then rebuild. No Dart code changes are
required. Until that file is present, the video panel shows a configured
placeholder. After building Web, run `scripts\run_offline_web.bat` and open
`http://localhost:8080`.
