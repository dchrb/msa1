// lib/pantallas/recordatorios.dart

import 'package:flutter/material.dart';
import 'package:msa/models/recordatorio.dart';
import 'package:msa/providers/recordatorio_provider.dart';
import 'package:msa/services/notification_service.dart';
import 'package:provider/provider.dart';

class Recordatorios extends StatefulWidget {
  const Recordatorios({super.key});

  @override
  State<Recordatorios> createState() => _RecordatoriosState();
}

class _RecordatoriosState extends State<Recordatorios> {
  @override
  Widget build(BuildContext context) {
    final recordatorioProvider = context.read<RecordatorioProvider>();

    return FutureBuilder(
      future: recordatorioProvider.initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Error al cargar recordatorios: ${snapshot.error}'),
            ),
          );
        } else {
          // Una vez inicializado, usamos `watch` para que la UI se reconstruya con los cambios.
          return _buildRecordatoriosList(context);
        }
      },
    );
  }

  Widget _buildRecordatoriosList(BuildContext context) {
    // Ahora usamos 'watch' para que la lista se actualice si se añade o elimina un recordatorio.
    final recordatorioProvider = context.watch<RecordatorioProvider>();
    final recordatorios = recordatorioProvider.recordatorios;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Recordatorios'),
      ),
      body: recordatorios.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'No tienes recordatorios.\n¡Añade uno para que no se te olvide nada!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: recordatorios.length,
              itemBuilder: (context, index) {
                final recordatorio = recordatorios[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 2.0,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    title: Text(
                      recordatorio.mensaje,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        decoration: !recordatorio.activado ? TextDecoration.lineThrough : null,
                        color: !recordatorio.activado ? Colors.grey : null,
                      ),
                    ),
                    subtitle: Text(
                      _formatearHora(recordatorio.timeOfDay),
                      style: TextStyle(
                        decoration: !recordatorio.activado ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    trailing: Switch(
                      value: recordatorio.activado,
                      onChanged: (value) {
                        final r = recordatorio;
                        r.activado = value;
                        // Aquí usamos `read` porque estamos en un callback, no en el `build`
                        context.read<RecordatorioProvider>().actualizarRecordatorio(r);
                      },
                    ),
                    onTap: () {
                      _mostrarDialogoEditar(context, recordatorio);
                    },
                    onLongPress: () {
                      _mostrarDialogoConfirmarEliminar(context, recordatorio.id);
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarDialogoAnadir(context),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          onPressed: _mostrarNotificacionDePrueba,
          icon: const Icon(Icons.notifications_active_outlined),
          label: const Text('Probar Notificación'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            backgroundColor: Theme.of(context).colorScheme.secondary,
            foregroundColor: Theme.of(context).colorScheme.onSecondary,
          ),
        ),
      ),
    );
  }

  // --- El resto de los métodos (_formatearHora, dialogos, etc.) permanecen sin cambios ---

  String _formatearHora(TimeOfDay hora) {
    final hour = hora.hourOfPeriod == 0 ? 12 : hora.hourOfPeriod;
    final period = hora.period == DayPeriod.am ? "AM" : "PM";
    return "$hour:${hora.minute.toString().padLeft(2, '0')} $period";
  }

  Future<TimeOfDay?> mostrarTimePickerAmPm(BuildContext context,
      {TimeOfDay? horaInicial}) async {
    int selectedHour = horaInicial?.hourOfPeriod ?? 12;
    int selectedMinute = horaInicial?.minute ?? 0;
    DayPeriod selectedPeriod = horaInicial?.period ?? DayPeriod.am;

    return showDialog<TimeOfDay>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Seleccionar Hora (AM/PM)'),
              content: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DropdownButton<int>(
                    value: selectedHour,
                    items: List.generate(12, (index) => index + 1)
                        .map((h) => DropdownMenuItem(value: h, child: Text(h.toString())))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => selectedHour = value);
                    },
                  ),
                  const Text(" : "),
                  DropdownButton<int>(
                    value: selectedMinute,
                    items: List.generate(60, (index) => index)
                        .map((m) => DropdownMenuItem(
                            value: m, child: Text(m.toString().padLeft(2, '0'))))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => selectedMinute = value);
                    },
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<DayPeriod>(
                    value: selectedPeriod,
                    items: const [
                      DropdownMenuItem(value: DayPeriod.am, child: Text('AM')),
                      DropdownMenuItem(value: DayPeriod.pm, child: Text('PM')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => selectedPeriod = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                TextButton(
                  child: const Text('Aceptar'),
                  onPressed: () {
                    final hour24 = selectedPeriod == DayPeriod.pm
                        ? (selectedHour == 12 ? 12 : selectedHour + 12)
                        : (selectedHour == 12 ? 0 : selectedHour);

                    Navigator.of(ctx).pop(TimeOfDay(hour: hour24, minute: selectedMinute));
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _mostrarNotificacionDePrueba() {
    NotificationService().mostrarNotificacionDePrueba();
  }

  void _mostrarDialogoAnadir(BuildContext context) async {
    TimeOfDay horaSeleccionada = TimeOfDay.now();
    final mensajeController = TextEditingController();
    final recordatorioProvider = context.read<RecordatorioProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final fueGuardado = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            return AlertDialog(
              title: const Text('Nuevo Recordatorio'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: mensajeController,
                    decoration: const InputDecoration(labelText: 'Mensaje', border: OutlineInputBorder()),
                    autofocus: true,
                  ),
                  const SizedBox(height: 20),
                  Text('Hora seleccionada: ${_formatearHora(horaSeleccionada)}'),
                  ElevatedButton(
                    onPressed: () async {
                      final TimeOfDay? horaElegida =
                          await mostrarTimePickerAmPm(context, horaInicial: horaSeleccionada);
                      if (horaElegida != null) {
                        setStateInDialog(() {
                           horaSeleccionada = horaElegida;
                        });
                      }
                    },
                    child: const Text('Cambiar Hora'),
                  ),
                ],
              ),
              actions: [
                TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(ctx).pop(false)),
                TextButton(
                  child: const Text('Guardar'),
                  onPressed: () {
                    if (mensajeController.text.isNotEmpty) {
                      recordatorioProvider.anadirRecordatorio(horaSeleccionada, mensajeController.text);
                      Navigator.of(ctx).pop(true);
                    }
                  },
                ),
              ],
            );
          }
        );
      }
    );

    if (mounted && (fueGuardado ?? false)) {
        scaffoldMessenger.showSnackBar(const SnackBar(content: Text("Recordatorio añadido")));
    }
  }

  void _mostrarDialogoEditar(BuildContext context, Recordatorio recordatorio) async {
    TimeOfDay horaSeleccionada = recordatorio.timeOfDay;
    final mensajeController = TextEditingController(text: recordatorio.mensaje);
    final recordatorioProvider = context.read<RecordatorioProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final fueGuardado = await showDialog<bool>(
      context: context,
       builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            return AlertDialog(
              title: const Text('Editar Recordatorio'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: mensajeController,
                    decoration: const InputDecoration(labelText: 'Mensaje', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                  Text('Hora seleccionada: ${_formatearHora(horaSeleccionada)}'),
                  ElevatedButton(
                    onPressed: () async {
                      final TimeOfDay? horaElegida =
                          await mostrarTimePickerAmPm(context, horaInicial: horaSeleccionada);
                      if (horaElegida != null) {
                        setStateInDialog(() {
                           horaSeleccionada = horaElegida;
                        });
                      }
                    },
                    child: const Text('Cambiar Hora'),
                  ),
                ],
              ),
              actions: [
                TextButton(child: const Text('Cancelar'),onPressed: () => Navigator.of(ctx).pop(false)),
                TextButton(
                  child: const Text('Guardar'),
                  onPressed: () {
                    recordatorio.hora = horaSeleccionada.hour;
                    recordatorio.minuto = horaSeleccionada.minute;
                    recordatorio.mensaje = mensajeController.text;
                    recordatorioProvider.actualizarRecordatorio(recordatorio);
                    Navigator.of(ctx).pop(true);
                  },
                ),
              ],
            );
          }
        );
      }
    );

     if (mounted && (fueGuardado ?? false)) {
        scaffoldMessenger.showSnackBar(const SnackBar(content: Text("Recordatorio actualizado")));
    }
  }

  void _mostrarDialogoConfirmarEliminar(BuildContext context, String id) async {
     final recordatorioProvider = context.read<RecordatorioProvider>();
     final scaffoldMessenger = ScaffoldMessenger.of(context);
     final fueEliminado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar Recordatorio?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(ctx).pop(false)),
          TextButton(
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
            onPressed: () {
              recordatorioProvider.eliminarRecordatorio(id);
              Navigator.of(ctx).pop(true);
            },
          ),
        ],
      ),
    );

    if (mounted && (fueEliminado ?? false)) {
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text("Recordatorio eliminado")));
    }
  }
}
