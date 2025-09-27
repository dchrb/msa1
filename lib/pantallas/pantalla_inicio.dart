import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:msa/providers/profile_provider.dart';
import 'package:msa/providers/consumo_provider.dart';
import 'package:msa/providers/water_provider.dart';
import 'package:msa/providers/entrenamiento_provider.dart';
import 'package:msa/widgets/anillos_progreso.dart';

class PantallaInicio extends StatelessWidget {
  const PantallaInicio({super.key});

  @override
  Widget build(BuildContext context) {
    // Get providers
    final profileProvider = context.watch<ProfileProvider>();
    final consumoProvider = context.watch<ConsumoProvider>();
    final waterProvider = context.watch<WaterProvider>();
    final entrenamientoProvider = context.watch<EntrenamientoProvider>();

    // Get data for rings
    final caloriasConsumidas = consumoProvider.caloriasConsumidasHoy.toDouble();
    final metaCalorias = consumoProvider.metaCaloricaDiaria.toDouble();
    final aguaConsumida = waterProvider.consumoTotalHoy;
    final metaAgua = waterProvider.metaDiaria;
    final minutosEjercicio = entrenamientoProvider.minutosEntrenadosHoy;
    final metaMinutosEjercicio = entrenamientoProvider.metaMinutosDiaria;

    // Get data for goals display
    final pesoActual = profileProvider.profile?.currentWeight;
    final metaPeso = profileProvider.profile?.weightGoal;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            AnillosProgreso(
              caloriasConsumidas: caloriasConsumidas,
              metaCalorias: metaCalorias,
              aguaConsumida: aguaConsumida,
              metaAgua: metaAgua,
              minutosEjercicio: minutosEjercicio.toInt(),
              metaMinutosEjercicio: metaMinutosEjercicio.toInt(),
            ),
            const SizedBox(height: 40),
            _buildResumenMetas(
              context,
              metaCalorias: metaCalorias,
              pesoActual: pesoActual,
              metaPeso: metaPeso,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumenMetas(BuildContext context, {
    required double metaCalorias,
    double? pesoActual,
    double? metaPeso,
  }) {
    final theme = Theme.of(context);
    
    // No mostrar el widget si no hay perfil para evitar datos vacíos
    if (pesoActual == null) {
      return const Center(
        child: Text('Crea un perfil para ver tus metas.'),
      );
    }
    
    return Column(
      children: [
        Text(
          'Resumen de Metas',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildMetaRow(
                  context,
                  icon: Icons.local_fire_department_outlined,
                  label: 'Meta Calórica',
                  value: '${metaCalorias.toStringAsFixed(0)} Kcal',
                ),
                if (metaPeso != null && metaPeso > 0) ...[
                  const Divider(height: 24, indent: 20, endIndent: 20),
                  _buildMetaRow(
                    context,
                    icon: Icons.monitor_weight_outlined,
                    label: 'Peso Actual',
                    value: '${pesoActual.toStringAsFixed(1)} kg',
                  ),
                  const SizedBox(height: 8),
                  _buildMetaRow(
                    context,
                    icon: Icons.flag_circle_outlined,
                    label: 'Meta de Peso',
                    value: '${metaPeso.toStringAsFixed(1)} kg',
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetaRow(BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 12),
            Text(label, style: theme.textTheme.bodyLarge),
          ],
        ),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
