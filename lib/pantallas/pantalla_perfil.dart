import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:msa/models/profile.dart';
import 'package:msa/providers/profile_provider.dart';

class PantallaPerfil extends StatefulWidget {
  const PantallaPerfil({super.key});

  @override
  State<PantallaPerfil> createState() => _PantallaPerfilState();
}

class _PantallaPerfilState extends State<PantallaPerfil> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nombreController;
  late TextEditingController _edadController;
  late TextEditingController _alturaController;
  late TextEditingController _pesoController;
  late TextEditingController _metaPesoController;
  late TextEditingController _metaCaloriasController;
  
  Sexo? _sexoSeleccionado;
  NivelActividad? _actividadSeleccionada;

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileProvider>().profile;
    
    _nombreController = TextEditingController(text: profile?.name ?? '');
    _edadController = TextEditingController(text: profile?.age.toString() ?? '0');
    _alturaController = TextEditingController(text: profile?.height.toString() ?? '0');
    _pesoController = TextEditingController(text: profile?.currentWeight.toString() ?? '0');
    _metaPesoController = TextEditingController(text: profile?.weightGoal?.toString() ?? '');
    _metaCaloriasController = TextEditingController(text: profile?.calorieGoal.toString() ?? '');
    
    _sexoSeleccionado = profile?.sex;
    _actividadSeleccionada = profile?.activityLevel;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _edadController.dispose();
    _alturaController.dispose();
    _pesoController.dispose();
    _metaPesoController.dispose();
    _metaCaloriasController.dispose();
    super.dispose();
  }

  Future<void> _guardarPerfil() async {
    if (_formKey.currentState?.validate() ?? false) {
      final profileProvider = context.read<ProfileProvider>();
      await profileProvider.guardarPerfil(
        nombre: _nombreController.text,
        edad: int.tryParse(_edadController.text) ?? 0,
        altura: double.tryParse(_alturaController.text) ?? 0,
        peso: double.tryParse(_pesoController.text) ?? 0,
        sexo: _sexoSeleccionado,
        nivelActividad: _actividadSeleccionada,
      );
      
      await profileProvider.guardarMetas(
        metaPeso: double.tryParse(_metaPesoController.text),
        metaCalorias: double.tryParse(_metaCaloriasController.text),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil guardado con éxito'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_alt_outlined),
            onPressed: _guardarPerfil,
            tooltip: 'Guardar Perfil',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text('Información Personal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildTextField(_nombreController, 'Nombre', Icons.person_outline),
              const SizedBox(height: 16),
              _buildTextField(_edadController, 'Edad', Icons.cake_outlined, keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              _buildTextField(_alturaController, 'Altura (cm)', Icons.height_outlined, keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              _buildTextField(_pesoController, 'Peso (kg)', Icons.monitor_weight_outlined, keyboardType: TextInputType.number),
              const SizedBox(height: 24),
              _buildSexoDropdown(),
              const SizedBox(height: 24),
              _buildActividadDropdown(),
              const Divider(height: 40),
              const Text('Mis Metas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildTextField(_metaPesoController, 'Meta de Peso (kg)', Icons.flag_circle_outlined, keyboardType: TextInputType.number, isRequired: false),
              const SizedBox(height: 16),
              _buildTextField(_metaCaloriasController, 'Meta de Calorías (Kcal)', Icons.local_fire_department_outlined, keyboardType: TextInputType.number, isRequired: false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType keyboardType = TextInputType.text, bool isRequired = true}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        icon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
      keyboardType: keyboardType,
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return 'Este campo es obligatorio';
        }
        if (keyboardType == TextInputType.number && value != null && value.isNotEmpty && (double.tryParse(value) ?? -1) < 0) {
          return 'Debe ser un número positivo';
        }
        return null;
      },
    );
  }

  Widget _buildSexoDropdown() {
    return DropdownButtonFormField<Sexo>(
      initialValue: _sexoSeleccionado,
      decoration: InputDecoration(
        labelText: 'Sexo',
        icon: const Icon(Icons.wc_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
      items: Sexo.values.map((sexo) {
        return DropdownMenuItem<Sexo>(
          value: sexo,
          child: Text(sexo.name[0].toUpperCase() + sexo.name.substring(1)),
        );
      }).toList(),
      onChanged: (value) => setState(() => _sexoSeleccionado = value),
      validator: (value) => value == null ? 'Selecciona una opción' : null,
    );
  }

  Widget _buildActividadDropdown() {
    final Map<NivelActividad, String> actividadLabels = {
      NivelActividad.sedentario: 'Sedentario (poco o nada de ejercicio)',
      NivelActividad.ligero: 'Ligero (ejercicio 1-3 días/semana)',
      NivelActividad.moderado: 'Moderado (ejercicio 3-5 días/semana)',
      NivelActividad.activo: 'Activo (ejercicio 6-7 días/semana)',
      NivelActividad.muyActivo: 'Muy Activo (trabajo físico o 2x día)',
    };

    return DropdownButtonFormField<NivelActividad>(
      initialValue: _actividadSeleccionada,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Nivel de Actividad Física',
        icon: const Icon(Icons.directions_run_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
      items: NivelActividad.values.map((nivel) {
        return DropdownMenuItem<NivelActividad>(
          value: nivel,
          child: Text(actividadLabels[nivel]!, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (value) => setState(() => _actividadSeleccionada = value),
      validator: (value) => value == null ? 'Selecciona una opción' : null,
    );
  }
}
