import 'package:flutter/widgets.dart';

import '../repositories/repository_bundle.dart';

class RepositoryScope extends InheritedWidget {
  const RepositoryScope({
    super.key,
    required this.repositories,
    required super.child,
  });

  final RepositoryBundle repositories;

  static RepositoryBundle read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<RepositoryScope>();
    assert(scope != null, 'RepositoryScope not found in widget tree');
    return scope!.repositories;
  }

  @override
  bool updateShouldNotify(RepositoryScope oldWidget) {
    return repositories != oldWidget.repositories;
  }
}
