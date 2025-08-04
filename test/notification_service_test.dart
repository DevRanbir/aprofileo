import 'package:flutter_test/flutter_test.dart';
import 'package:aprofileo/services/notification_service.dart';

void main() {
  group('NotificationService Tests', () {
    test('NotificationService can be instantiated', () {
      final notificationService = NotificationService();
      expect(notificationService, isNotNull);
    });

    test('NotificationService is singleton', () {
      final service1 = NotificationService();
      final service2 = NotificationService();
      expect(service1, equals(service2));
    });
  });
}
