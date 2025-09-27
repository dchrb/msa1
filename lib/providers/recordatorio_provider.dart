// lib/providers/recordatorio_provider.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:msa/models/recordatorio.dart';
import 'package:msa/providers/sync_provider.dart';
import 'package:msa/services/notification_service.dart';

class RecordatorioProvider with ChangeNotifier {
  SyncProvider? _syncProvider;
  late Box<Recordatorio> _recordatoriosBox;
  
  Future<void>? initializationFuture; // SEÑAL PÚBLICA

  RecordatorioProvider() {
    initializationFuture = _init(); // Inicia el proceso y guarda la señal
  }

  void updateSyncProvider(SyncProvider? syncProvider) {
    _syncProvider = syncProvider;
  }

  Future<void> _init() async {
    // Asegurarse de que la caja esté abierta antes de usarla.
    if (!Hive.isBoxOpen('recordatoriosBox')) {
      await Hive.openBox<Recordatorio>('recordatoriosBox');
    }
    _recordatoriosBox = Hive.box<Recordatorio>('recordatoriosBox');
    notifyListeners();

    // Al inicializar, asegurarse que las notificaciones estén sincronizadas con el estado de Hive
    await _rescheduleAllNotifications();
  }

  List<Recordatorio> get recordatorios => _recordatoriosBox.values.toList();

  Future<void> anadirRecordatorio(TimeOfDay hora, String mensaje) async {
    final nuevo = Recordatorio(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      hora: hora.hour,
      minuto: hora.minute,
      mensaje: mensaje,
      activado: true,
    );
    await _recordatoriosBox.put(nuevo.id, nuevo);
    await _syncProvider?.syncDocumentToFirestore('recordatorios', nuevo.id, nuevo.toJson());
    await NotificationService().programarRecordatorioDiario(nuevo);
    notifyListeners();
  }

  Future<void> eliminarRecordatorio(String id) async {
    final recordatorio = _recordatoriosBox.get(id);
    if(recordatorio != null) {
       await NotificationService().cancelarRecordatorio(recordatorio.id);
    }
    
    await _recordatoriosBox.delete(id);
    await _syncProvider?.deleteDocumentFromFirestore('recordatorios', id);
    notifyListeners();
  }

  Future<void> actualizarRecordatorio(Recordatorio recordatorio) async {
    await _recordatoriosBox.put(recordatorio.id, recordatorio);
    await _syncProvider?.syncDocumentToFirestore('recordatorios', recordatorio.id, recordatorio.toJson());
    
    if (recordatorio.activado) {
      await NotificationService().programarRecordatorioDiario(recordatorio);
    } else {
      await NotificationService().cancelarRecordatorio(recordatorio.id);
    }
    notifyListeners();
  }

  Future<void> replaceAllRecordatorios(List<Recordatorio> remoteRecordatorios) async {
    await _recordatoriosBox.clear();
    for (var recordatorio in remoteRecordatorios) {
      await _recordatoriosBox.put(recordatorio.id, recordatorio);
    }
    await _rescheduleAllNotifications();
    notifyListeners();
  }

  Future<void> _rescheduleAllNotifications() async {
    final notificationService = NotificationService();
    await notificationService.cancelarTodosLosRecordatorios(); 
    for (final recordatorio in _recordatoriosBox.values) {
      if (recordatorio.activado) {
        await notificationService.programarRecordatorioDiario(recordatorio);
      }
    }
  }
}
