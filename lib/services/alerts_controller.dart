import 'package:flutter/foundation.dart';
import '../models/alert_model.dart';
import 'alerts_repository.dart';

class AlertsController extends ChangeNotifier {
  final AlertsRepository _repository = AlertsRepository();
  List<AlertModel> _alerts = [];
  bool _isLoading = true;

  AlertsController() {
    _init();
  }

  List<AlertModel> get alerts => _alerts;
  bool get isLoading => _isLoading;

  void _init() {
    _repository.alertsStream().listen((updatedAlerts) {
      _alerts = updatedAlerts;
      _isLoading = false;
      notifyListeners();
    });
  }

  List<AlertModel> getHomeView(String country) {
    return _alerts
        .where((a) => a.country.toLowerCase() == country.toLowerCase())
        .take(3)
        .toList();
  }
}
