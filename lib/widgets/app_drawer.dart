import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:msa/providers/profile_provider.dart';
import 'package:msa/pantallas/pantallas.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final profile = profileProvider.profile;
    final theme = Theme.of(context);

    void navigateTo(Widget screen, {String? routeName}) {
      Navigator.pop(context); // Cierra el drawer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => screen,
          settings: RouteSettings(name: routeName),
        ),
      );
    }

    void goHome() {
      Navigator.pop(context); // Cierra el drawer
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          GestureDetector(
            onTap: () => navigateTo(const PantallaPerfil(), routeName: '/perfil'),
            child: UserAccountsDrawerHeader(
              accountName: Text(
                profile?.name ?? 'Nombre de Usuario',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              accountEmail: const Text(
                'Pulsa aquí para editar tu perfil',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  profile?.name.isNotEmpty == true ? profile!.name[0].toUpperCase() : 'U',
                  style: TextStyle(fontSize: 40.0, color: theme.primaryColor),
                ),
              ),
              decoration: BoxDecoration(
                color: theme.primaryColor,
              ),
            ),
          ),

          _buildDrawerItem(context, icon: Icons.home_outlined, text: 'Inicio', onTap: goHome),
          const Divider(),

          _buildSectionTitle(context, 'REGISTRO'),
          _buildDrawerItem(context, icon: Icons.water_drop_outlined, text: 'Registrar Agua', onTap: () => navigateTo(const PantallaRegistroTabs(initialIndex: 0), routeName: '/registro')),
          _buildDrawerItem(context, icon: Icons.restaurant_menu_outlined, text: 'Registrar Comidas', onTap: () => navigateTo(const PantallaRegistroTabs(initialIndex: 1), routeName: '/registro')),
          _buildDrawerItem(context, icon: Icons.straighten_outlined, text: 'Registrar Medidas', onTap: () => navigateTo(const PantallaRegistroTabs(initialIndex: 2), routeName: '/registro')),

          const Divider(),

          _buildSectionTitle(context, 'ACTIVIDAD FÍSICA'),
          _buildDrawerItem(context, icon: Icons.history, text: 'Historial de Entrenamientos', onTap: () => navigateTo(const PantallaActividadFisicaTabs(initialIndex: 0), routeName: '/actividad')),
          _buildDrawerItem(context, icon: Icons.book_outlined, text: 'Biblioteca de Ejercicios', onTap: () => navigateTo(const PantallaActividadFisicaTabs(initialIndex: 1), routeName: '/actividad')),

          const Divider(),

          _buildSectionTitle(context, 'CONFIGURACIÓN'),
          _buildDrawerItem(context, icon: Icons.notifications_outlined, text: 'Recordatorios', onTap: () => navigateTo(const PantallaConfiguracionTabs(initialIndex: 0), routeName: '/configuracion')),
          _buildDrawerItem(context, icon: Icons.palette_outlined, text: 'Temas y Configuración', onTap: () => navigateTo(const PantallaConfiguracionTabs(initialIndex: 1), routeName: '/configuracion')),
          
          const Divider(),

          _buildDrawerItem(context, icon: Icons.info_outline, text: 'Acerca de', onTap: () {
            Navigator.pop(context); 
            showAboutDialog(
              context: context,
              applicationName: 'Mi Salud Activa',
              applicationVersion: '1.0.0', 
              applicationLegalese: '© 2024 Mi Salud Activa',
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(top: 15),
                  child: Text('Una aplicación para ayudarte a llevar un estilo de vida más saludable.'),
                )
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, {required IconData icon, required String text, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).iconTheme.color?.withAlpha((255 * 0.7).round())),
      title: Text(text),
      onTap: onTap,
      dense: true,
    );
  }
}
