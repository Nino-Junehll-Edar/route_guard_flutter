import 'package:shared_preferences/shared_preferences.dart';
import 'package:route_guard/services/connectivity_service.dart';
import 'package:route_guard/services/local_cache_service.dart';
import 'package:route_guard/services/synchronized_database_service.dart';
import 'package:route_guard/services/database_service.dart';
import 'package:route_guard/services/location_service.dart';
import 'package:route_guard/services/notification_service.dart';
import 'package:route_guard/services/proximity_notification_service.dart';
import 'package:route_guard/routing/route_calculator.dart';

final class ServiceLocator {
  ServiceLocator._internal();

  static final ServiceLocator _instance = ServiceLocator._internal();

  factory ServiceLocator() => _instance;

  late final SharedPreferences sharedPreferences;
  late final ConnectivityService connectivityService;
  late final LocalCacheService localCacheService;
  late final SynchronizedDatabaseService synchronizedDatabaseService;
  late final DatabaseService databaseService; // Keep original for direct access if needed
  late final LocationService locationService;
  late final NotificationService notificationService;
  late final ProximityNotificationService proximityNotificationService;
  late final RouteCalculator routeCalculator;

  Future<void> initialize() async {
    sharedPreferences = await SharedPreferences.getInstance();
    connectivityService = ConnectivityService();
    localCacheService = LocalCacheService(sharedPreferences);
    synchronizedDatabaseService = SynchronizedDatabaseService(
      sharedPreferences,
      connectivityService,
    );
    databaseService = DatabaseService();
    locationService = LocationService();
    notificationService = NotificationService();
    proximityNotificationService = ProximityNotificationService();
    routeCalculator = RouteCalculator();
  }
}