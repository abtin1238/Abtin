import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/routing_service.dart';
import 'graph_registry.dart';

/// سرویس تعویض گراف مسیریابی آفلاین بین استان‌ها.
class GraphPackageService {
  GraphPackageService(this._routing);
  final RoutingService _routing;

  String get activeId => _routing.activeGraphId;

  List<OfflineGraphPackage> get available => GraphRegistry.packages;

  Future<void> activate(String packageId) =>
      _routing.loadProvinceGraph(packageId);
}

final graphPackageServiceProvider = Provider<GraphPackageService>((ref) {
  return GraphPackageService(ref.watch(routingServiceProvider));
});
