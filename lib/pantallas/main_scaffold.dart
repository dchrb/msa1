
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:msa/pantallas/pantalla_inicio.dart';
import 'package:msa/pantallas/pantalla_sincronizacion.dart';
import 'package:msa/widgets/app_drawer.dart';

class MainScaffold extends StatelessWidget {
  const MainScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
          IconButton(
            icon: CircleAvatar(
              radius: 18,
              backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
              child: user?.photoURL == null 
                  ? const Icon(Icons.person_outline, size: 22)
                  : null,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PantallaSincronizacion()),
              );
            },
            tooltip: 'Cuenta y Sincronización',
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: const AppDrawer(),
      body: const PantallaInicio(),
    );
  }
}
