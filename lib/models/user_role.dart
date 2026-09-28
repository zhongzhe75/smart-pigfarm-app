enum UserRole {
  manager,
  operator,
  visitor,
}

extension UserRoleText on UserRole {
  String get title {
    switch (this) {
      case UserRole.manager:
        return '场长管理员';
      case UserRole.operator:
        return '饲养员操作员';
      case UserRole.visitor:
        return '游客查看';
    }
  }

  String get subtitle {
    switch (this) {
      case UserRole.manager:
        return '全场管理、阈值配置、告警处理';
      case UserRole.operator:
        return '日常巡检、远程控制、告警确认';
      case UserRole.visitor:
        return '只读浏览，适合评委查看';
    }
  }

  String get accountName {
    switch (this) {
      case UserRole.manager:
        return 'manager@A01';
      case UserRole.operator:
        return 'operator@A01';
      case UserRole.visitor:
        return 'guest@A01';
    }
  }
}

enum Permission {
  dashboard,
  realtime,
  remoteControl,
  thresholdEdit,
  alarmHandle,
  alarmSimulate,
  herdManagement,
  reports,
  videoAi,
  permissionMatrix,
}

extension PermissionText on Permission {
  String get label {
    switch (this) {
      case Permission.dashboard:
        return '首页仪表盘';
      case Permission.realtime:
        return '实时监控';
      case Permission.remoteControl:
        return '远程控制';
      case Permission.thresholdEdit:
        return '阈值修改';
      case Permission.alarmHandle:
        return '告警处理';
      case Permission.alarmSimulate:
        return '告警联动';
      case Permission.herdManagement:
        return '猪群管理';
      case Permission.reports:
        return '数据报表';
      case Permission.videoAi:
        return '视频 AI';
      case Permission.permissionMatrix:
        return '权限矩阵';
    }
  }
}

const Map<UserRole, Set<Permission>> rolePermissionMap = {
  UserRole.manager: {
    Permission.dashboard,
    Permission.realtime,
    Permission.remoteControl,
    Permission.thresholdEdit,
    Permission.alarmHandle,
    Permission.alarmSimulate,
    Permission.herdManagement,
    Permission.reports,
    Permission.videoAi,
    Permission.permissionMatrix,
  },
  UserRole.operator: {
    Permission.dashboard,
    Permission.realtime,
    Permission.remoteControl,
    Permission.alarmHandle,
    Permission.alarmSimulate,
    Permission.herdManagement,
    Permission.reports,
    Permission.videoAi,
    Permission.permissionMatrix,
  },
  UserRole.visitor: {
    Permission.dashboard,
    Permission.realtime,
    Permission.herdManagement,
    Permission.reports,
    Permission.videoAi,
    Permission.permissionMatrix,
  },
};

bool hasPermission(UserRole? role, Permission permission) {
  if (role == null) {
    return false;
  }
  return rolePermissionMap[role]?.contains(permission) ?? false;
}
