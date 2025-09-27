import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:msa/models/models.dart';
import 'package:msa/providers/providers.dart';
import 'package:msa/services/notification_service.dart';

import 'package:msa/pantallas/pantallas.dart';
import 'package:msa/pantallas/main_scaffold.dart'; // <-- CAMBIO: Importamos el nuevo scaffold
import 'firebase_options.dart'; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions
          .currentPlatform, 
    );
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
    );

    await NotificationService().initialize();

    await Hive.initFlutter();

    Hive.registerAdapter(MedidaAdapter());
    Hive.registerAdapter(PlatoAdapter());
    Hive.registerAdapter(AlimentoAdapter());
    Hive.registerAdapter(TipoPlatoAdapter());
    Hive.registerAdapter(EjercicioAdapter());
    Hive.registerAdapter(SesionEntrenamientoAdapter());
    Hive.registerAdapter(AguaAdapter());
    Hive.registerAdapter(RecetaAdapter());
    Hive.registerAdapter(RecordatorioAdapter());
    Hive.registerAdapter(ComidaPlanificadaAdapter());
    Hive.registerAdapter(ProfileAdapter());
    Hive.registerAdapter(SexoAdapter());
    Hive.registerAdapter(NivelActividadAdapter());
    Hive.registerAdapter(ComidaConsumidaAdapter());
    Hive.registerAdapter(InsigniaAdapter());
    Hive.registerAdapter(RachaAdapter());

    await Hive.openBox<Map>('food');
    await Hive.openBox<Medida>('medidas');
    await Hive.openBox<Ejercicio>('ejercicios');
    await Hive.openBox<SesionEntrenamiento>('sesiones');
    await Hive.openBox<Agua>('agua');
    await Hive.openBox<Receta>('recetas');
    await Hive.openBox<Recordatorio>('recordatorios');
    await Hive.openBox<ComidaPlanificada>('dieta');
    await Hive.openBox<Profile>('profile');
    await Hive.openBox<Insignia>('insignias');
    await Hive.openBox<Racha>('rachas');
    await Hive.openBox<ComidaConsumida>('comidasConsumidasBox');
  } catch (e) {
    debugPrint('Error inicializando Firebase o Hive: $e');
  }

  runApp(const AppState());
}

class AppState extends StatelessWidget {
  const AppState({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => WaterProvider()),
        ChangeNotifierProvider(create: (_) => RecordatorioProvider()),
        ChangeNotifierProvider(create: (_) => MedidaProvider()),
        ChangeNotifierProvider(create: (_) => FoodProvider()),
        ChangeNotifierProvider(create: (_) => EntrenamientoProvider()),
        ChangeNotifierProvider(create: (_) => RecetaProvider()),
        ChangeNotifierProvider(create: (_) => DietaProvider()),
        ChangeNotifierProvider(create: (_) => InsigniaProvider()),
        ChangeNotifierProvider(create: (_) => RachaProvider()),
        
        ChangeNotifierProxyProvider<ProfileProvider, ConsumoProvider>(
          create: (_) => ConsumoProvider(),
          update: (_, profileProvider, consumo) {
            consumo ??= ConsumoProvider();
            consumo.update(profileProvider);
            return consumo;
          },
        ),

        ChangeNotifierProxyProvider<FoodProvider, SyncProvider>(
          create: (_) => SyncProvider(),
          update: (context, foodProvider, sync) {
            sync ??= SyncProvider();
            sync.updateDataProviders(
              profileProvider: context.read<ProfileProvider>(),
              medidaProvider: context.read<MedidaProvider>(),
              foodProvider: foodProvider,
              entrenamientoProvider: context.read<EntrenamientoProvider>(),
              waterProvider: context.read<WaterProvider>(),
              recetaProvider: context.read<RecetaProvider>(),
              recordatorioProvider: context.read<RecordatorioProvider>(),
              dietaProvider: context.read<DietaProvider>(),
            );
            return sync;
          },
        ),
      ],
      child: const MyApp(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Mi Salud Activa',
      themeMode: themeProvider.themeMode,
      theme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(seedColor: themeProvider.seedColor),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeProvider.seedColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', '')],
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          final user = snapshot.data!;
          if (user.providerData.any((info) => info.providerId == 'password') &&
              !user.emailVerified) {
            return const PantallaVerificarEmail();
          }
          // <-- CAMBIO: Usamos el nuevo scaffold principal
          return const MainScaffold(); 
        }

        return const PantallaAuth();
      },
    );
  }
}
