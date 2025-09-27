// lib/services/notification_service.dart

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:msa/models/recordatorio.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:firebase_messaging/firebase_messaging.dart';

/// Servicio para gestionar todo tipo de notificaciones (locales y push).
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Canal para recordatorios locales (agua, comida, etc.)
  static const String channelId = 'recordatorios_channel';
  static const String channelName = 'Recordatorios de Actividad';
  static const String channelDescription = 'Canal para recordatorios de hidratación, comidas, etc.';

  // Canal para notificaciones de sincronización en segundo plano
  static const String syncChannelId = 'sync_channel';
  static const String syncChannelName = 'Sincronización de Datos';
  static const String syncChannelDescription = 'Notificaciones sobre el estado de la sincronización de datos.';

  /// Crea los canales de notificación necesarios para Android.
  /// En Android 8.0+ los canales son obligatorios.
  Future<void> _createNotificationChannels() async {
    const AndroidNotificationChannel recordatoriosChannel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    const AndroidNotificationChannel syncChannel = AndroidNotificationChannel(
      syncChannelId,
      syncChannelName,
      description: syncChannelDescription,
      importance: Importance.low,
      playSound: false,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(recordatoriosChannel);
    
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(syncChannel);
    debugPrint("Canales de notificación creados.");
  }


  /// Inicializa el servicio de notificaciones, los canales y solicita permisos.
  Future<void> initialize() async {
    // 1. Configuración de inicialización para cada plataforma
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    // 2. Inicializar el plugin y definir el callback para cuando se toca una notificación
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notificación tocada con payload: ${response.payload}');
        // Aquí puedes agregar navegación si lo necesitas
      }
    );

    // 3. Crear canales de notificación (solo para Android)
    await _createNotificationChannels();

    // 4. Solicitar permisos de notificación explícitamente en Android
    final androidImplementation = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }


    // 5. Inicializar las zonas horarias para la programación
    tz.initializeTimeZones();
    try {
      final String timeZoneName = tz.local.name;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint('Error al establecer la zona horaria local: $e');
    }
    
    // 6. Configuración de Firebase Cloud Messaging (FCM)
    await FirebaseMessaging.instance.requestPermission();
    final fcmToken = await FirebaseMessaging.instance.getToken();
    debugPrint('FCM Token: $fcmToken'); // Útil para testing de notificaciones push

    // Listener para notificaciones push recibidas mientras la app está en primer plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _showFirebaseNotification(message.notification!);
      }
    });
  }

  // --- MÉTODOS PARA RECORDATORIOS LOCALES ---

  Future<void> programarRecordatorioDiario(Recordatorio recordatorio) async {
    
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      recordatorio.hora,
      recordatorio.minuto,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      recordatorio.id.hashCode, 
      recordatorio.mensaje, 
      'Es hora de cuidarte. ¡No te olvides de registrar tu actividad!', 
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, 
    );
    debugPrint("Recordatorio '''{recordatorio.mensaje}''' programado para las ${recordatorio.hora}:${recordatorio.minuto} diariamente.");
  }

  Future<void> cancelarRecordatorio(String recordatorioId) async {
    await _flutterLocalNotificationsPlugin.cancel(recordatorioId.hashCode);
    debugPrint("Recordatorio con ID $recordatorioId cancelado.");
  }

  Future<void> cancelarTodosLosRecordatorios() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
     debugPrint("Todos los recordatorios han sido cancelados.");
  }

  Future<void> _showFirebaseNotification(RemoteNotification notification) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId, channelName, channelDescription: channelDescription,
      importance: Importance.max, priority: Priority.high,
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
    await _flutterLocalNotificationsPlugin.show(
      notification.hashCode, notification.title, notification.body, platformDetails,
    );
  }

  Future<void> showSyncNotification({required String title, required String body}) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      syncChannelId, syncChannelName, channelDescription: syncChannelDescription,
      importance: Importance.low, priority: Priority.low, playSound: false,
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
    await _flutterLocalNotificationsPlugin.show(1, title, body, platformDetails);
  }

  /// Muestra una notificación de prueba para verificar que el servicio funciona.
  Future<void> mostrarNotificacionDePrueba() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId, channelName, channelDescription: channelDescription,
      importance: Importance.max, priority: Priority.high,
    );
    // CORRECCIÓN: Corregido el error de tipeo 'androidolis' a 'androidDetails'
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
    await _flutterLocalNotificationsPlugin.show(
      0, '¡Notificación de Prueba!', 'Si puedes ver esto, el servicio de notificaciones está funcionando.', platformDetails,
    );
    debugPrint("Mostrando notificación de prueba.");
  }
}
