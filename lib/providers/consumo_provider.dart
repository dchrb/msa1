import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:msa/models/comida_consumida.dart';
import 'package:msa/models/profile.dart';
import 'package:msa/providers/profile_provider.dart';
import 'package:uuid/uuid.dart';

class ConsumoProvider with ChangeNotifier {
  final Box<ComidaConsumida> _consumoBox;
  ProfileProvider? _profileProvider;

  ConsumoProvider() : _consumoBox = Hive.box<ComidaConsumida>('comidasConsumidasBox');

  void update(ProfileProvider profileProvider) {
    _profileProvider = profileProvider;
    notifyListeners();
  }

  int get metaCaloricaDiaria {
    if (_profileProvider?.profile?.calorieGoal != null && _profileProvider!.profile!.calorieGoal > 0) {
      return _profileProvider!.profile!.calorieGoal.round();
    }
    return calcularCaloriasRecomendadas().round();
  }

  double calcularCaloriasRecomendadas() {
    if (_profileProvider?.profile == null) {
      return 2000; 
    }

    final profile = _profileProvider!.profile!;
    final peso = profile.currentWeight;
    final altura = profile.height;
    final edad = profile.age;
    final sexo = profile.sex;
    final nivelActividad = profile.activityLevel;

    if (peso == 0 || altura == 0 || edad == 0) {
      return 2000;
    }

    double bmr;
    if (sexo == Sexo.masculino) {
      bmr = 88.362 + (13.397 * peso) + (4.799 * altura) - (5.677 * edad);
    } else {
      bmr = 447.593 + (9.247 * peso) + (3.098 * altura) - (4.330 * edad);
    }

    double multiplicador = 1.2; // Sedentario por defecto
    switch (nivelActividad) {
      case NivelActividad.sedentario:
        multiplicador = 1.2;
        break;
      case NivelActividad.ligero:
        multiplicador = 1.375;
        break;
      case NivelActividad.moderado:
        multiplicador = 1.55;
        break;
      case NivelActividad.activo:
        multiplicador = 1.725;
        break;
      case NivelActividad.muyActivo:
        multiplicador = 1.9;
        break;
    }
  
    return bmr * multiplicador;
  }

  int get caloriasConsumidasHoy {
    final ahora = DateTime.now();
    final inicioHoy = DateTime(ahora.year, ahora.month, ahora.day);
    final finHoy = DateTime(ahora.year, ahora.month, ahora.day + 1);

    return _consumoBox.values
        .where((consumo) =>
            !consumo.fecha.isBefore(inicioHoy) && consumo.fecha.isBefore(finHoy))
        .fold(0, (sum, item) => sum + item.calorias);
  }

  Future<void> registrarComida(String nombre, int calorias) async {
    final nuevoConsumo = ComidaConsumida(
      id: const Uuid().v4(),
      nombre: nombre,
      calorias: calorias,
      fecha: DateTime.now(),
    );
    await _consumoBox.put(nuevoConsumo.id, nuevoConsumo);
    notifyListeners();
  }

  List<ComidaConsumida> get todosLosConsumos => _consumoBox.values.toList();
}
