import 'package:flutter/material.dart';
import 'package:msa/pantallas/recordatorios.dart'; // <-- CAMBIO: Importamos Recordatorios
import 'package:msa/pantallas/pantalla_temas.dart';

class PantallaConfiguracionTabs extends StatefulWidget {
  final int initialIndex;
  const PantallaConfiguracionTabs({super.key, this.initialIndex = 0});

  @override
  State<PantallaConfiguracionTabs> createState() => _PantallaConfiguracionTabsState();
}

class _PantallaConfiguracionTabsState extends State<PantallaConfiguracionTabs> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- CAMBIO: Actualizamos las pestañas a las correctas ---
  static const List<Tab> _tabs = [
    Tab(text: 'Recordatorios', icon: Icon(Icons.notifications_outlined)),
    Tab(text: 'Temas', icon: Icon(Icons.palette_outlined)),
  ];

  // --- CAMBIO: Actualizamos las vistas de las pestañas ---
  final List<Widget> _tabViews = [
    const Recordatorios(),
    const PantallaTemas(),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this, initialIndex: widget.initialIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs,
          isScrollable: false,
          tabAlignment: TabAlignment.fill,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabViews,
      ),
    );
  }
}
