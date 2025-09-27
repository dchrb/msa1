import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:msa/models/models.dart';
// Import all data providers
import 'package:msa/providers/providers.dart';

class SyncProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  bool _isBackingUp = false;
  bool _isRestoring = false;
  DateTime? _lastSyncTime;

  // References to all data providers
  ProfileProvider? _profileProvider;
  MedidaProvider? _medidaProvider;
  FoodProvider? _foodProvider;
  EntrenamientoProvider? _entrenamientoProvider;
  WaterProvider? _waterProvider;
  RecetaProvider? _recetaProvider;
  RecordatorioProvider? _recordatorioProvider;
  DietaProvider? _dietaProvider;

  SyncProvider() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  User? get user => _user;
  bool get isBackingUp => _isBackingUp;
  bool get isRestoring => _isRestoring;
  bool get isSyncing => _isBackingUp || _isRestoring;
  DateTime? get lastSyncTime => _lastSyncTime;

  void updateDataProviders({
    required ProfileProvider profileProvider,
    required MedidaProvider medidaProvider,
    required FoodProvider foodProvider,
    required EntrenamientoProvider entrenamientoProvider,
    required WaterProvider waterProvider,
    required RecetaProvider recetaProvider,
    required RecordatorioProvider recordatorioProvider,
    required DietaProvider dietaProvider,
  }) {
    _profileProvider = profileProvider;
    _medidaProvider = medidaProvider;
    _foodProvider = foodProvider;
    _entrenamientoProvider = entrenamientoProvider;
    _waterProvider = waterProvider;
    _recetaProvider = recetaProvider;
    _recordatorioProvider = recordatorioProvider;
    _dietaProvider = dietaProvider;
  }

  Future<void> _onAuthStateChanged(User? newUser) async {
    final wasAnonymous = _user?.isAnonymous ?? false;
    _user = newUser;

    if (wasAnonymous && newUser != null && !newUser.isAnonymous) {
      debugPrint("Cuenta de invitado vinculada. Realizando primer respaldo automático...");
      await syncAllData();
    } else if (newUser == null) {
      await _clearAllLocalData();
      debugPrint("Usuario deslogueado. Datos locales borrados.");
    } else if (newUser.metadata.creationTime != null &&
        newUser.metadata.lastSignInTime != null &&
        newUser.metadata.creationTime!.millisecondsSinceEpoch ==
            newUser.metadata.lastSignInTime!.millisecondsSinceEpoch) {
      debugPrint("Primer login o restauración necesaria.");
      await restoreAllData();
    }

    notifyListeners();
  }

  Future<bool> syncAllData() async {
    if (_user == null || isSyncing) return false;

    _isBackingUp = true;
    notifyListeners();

    try {
      final userId = _user!.uid;
      final batch = _firestore.batch();

      _addCollectionToBatch(batch, 'users/$userId/medidas', _medidaProvider?.registros);
      _addCollectionToBatch(batch, 'users/$userId/platos', _foodProvider?.allPlatos);
      _addCollectionToBatch(batch, 'users/$userId/alimentos', _foodProvider?.alimentosManuales);
      _addCollectionToBatch(batch, 'users/$userId/ejercicios', _entrenamientoProvider?.ejercicios);
      _addCollectionToBatch(batch, 'users/$userId/sesiones', _entrenamientoProvider?.sesiones);
      _addCollectionToBatch(batch, 'users/$userId/agua', _waterProvider?.registros);
      _addCollectionToBatch(batch, 'users/$userId/recordatorios', _recordatorioProvider?.recordatorios);
      _addCollectionToBatch(batch, 'users/$userId/recetas', _recetaProvider?.recetas);
      if (_dietaProvider?.menuSemanal != null) {
        _addCollectionToBatch(batch, 'users/$userId/dieta', _dietaProvider!.menuSemanal.values.expand((x) => x).toList());
      }

      if (_profileProvider?.profile != null) {
        final profileDoc = _firestore.collection('users').doc(userId).collection('configuracion').doc('perfil');
        batch.set(profileDoc, _profileProvider!.profile!.toJson());
      }
      if (_waterProvider != null) {
        final waterGoalDoc = _firestore.collection('users').doc(userId).collection('configuracion').doc('metaAgua');
        batch.set(waterGoalDoc, {'metaDiaria': _waterProvider!.metaDiaria});
      }

      await batch.commit();
      _lastSyncTime = DateTime.now();
      debugPrint("Respaldo completado con éxito.");
      return true;
    } catch (e) {
      debugPrint("Error durante el respaldo: $e");
      return false;
    } finally {
      _isBackingUp = false;
      notifyListeners();
    }
  }

  Future<bool> restoreAllData() async {
    if (_user == null || isSyncing) return false;

    _isRestoring = true;
    notifyListeners();

    try {
      final userId = _user!.uid;

      await _clearAllLocalData();

      final profileSnap = await _firestore.collection('users').doc(userId).collection('configuracion').doc('perfil').get();
      if (profileSnap.exists && _profileProvider != null) {
        _profileProvider!.loadProfileFromMap(profileSnap.data()!);
      }
      final waterGoalSnap = await _firestore.collection('users').doc(userId).collection('configuracion').doc('metaAgua').get();
      if (waterGoalSnap.exists && _waterProvider != null) {
        final meta = waterGoalSnap.data()?['metaDiaria'] as double?;
        if (meta != null) {
          _waterProvider!.setMeta(meta);
        }
      }

      final platos = await _restoreCollection<Plato>('users/$userId/platos', Plato.fromJson);
      final alimentos = await _restoreCollection<Alimento>('users/$userId/alimentos', Alimento.fromJson);
      await _foodProvider?.replaceAllData(platos, alimentos);

      await _medidaProvider?.replaceAll(await _restoreCollection<Medida>('users/$userId/medidas', Medida.fromJson));
      await _entrenamientoProvider?.replaceAllEjercicios(await _restoreCollection<Ejercicio>('users/$userId/ejercicios', Ejercicio.fromJson));
      await _entrenamientoProvider?.replaceAllSesiones(await _restoreCollection<SesionEntrenamiento>('users/$userId/sesiones', SesionEntrenamiento.fromJson));
      await _waterProvider?.replaceAllAgua(await _restoreCollection<Agua>('users/$userId/agua', Agua.fromJson));
      await _recordatorioProvider?.replaceAllRecordatorios(await _restoreCollection<Recordatorio>('users/$userId/recordatorios', Recordatorio.fromJson));
      await _recetaProvider?.replaceAll(await _restoreCollection<Receta>('users/$userId/recetas', Receta.fromJson));
      await _dietaProvider?.replaceAllComidas(await _restoreCollection<ComidaPlanificada>('users/$userId/dieta', ComidaPlanificada.fromJson));

      _lastSyncTime = DateTime.now();
      debugPrint("Restauración completada con éxito.");
      return true;
    } catch (e) {
      debugPrint("Error durante la restauración: $e");
      return false;
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  void _addCollectionToBatch<T>(WriteBatch batch, String collectionPath, List<T>? items) {
    if (items == null) return;
    for (final item in items) {
      final id = (item as dynamic).id;
      final data = (item as dynamic).toJson();
      final docRef = _firestore.collection(collectionPath).doc(id);
      batch.set(docRef, data);
    }
  }

  Future<List<T>> _restoreCollection<T>(String collectionPath, T Function(Map<String, dynamic> json) fromJson) async {
    try {
      final snapshot = await _firestore.collection(collectionPath).get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.map((doc) => fromJson(doc.data())).toList();
      }
    } catch (e) {
      debugPrint('Could not restore collection $collectionPath: $e');
    }
    return [];
  }

  Future<void> _clearAllLocalData() async {
    debugPrint('Limpiando todos los datos locales.');
    await _medidaProvider?.replaceAll([]);
    await _foodProvider?.replaceAllData([], []);
    await _entrenamientoProvider?.replaceAllEjercicios([]);
    await _entrenamientoProvider?.replaceAllSesiones([]);
    await _waterProvider?.replaceAllAgua([]);
    await _recetaProvider?.replaceAll([]);
    await _recordatorioProvider?.replaceAllRecordatorios([]);
    await _dietaProvider?.replaceAllComidas([]);
    _profileProvider?.clearProfile();
    _waterProvider?.setMeta(2500.0);
    notifyListeners();
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null; // El usuario canceló el flujo
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint('Error al iniciar sesión con Google: $e');
      return null;
    }
  }

  Future<UserCredential?> signInAnonymously() async {
    try {
      return await _auth.signInAnonymously();
    } catch (e) {
      debugPrint('Error al iniciar sesión como invitado: $e');
      return null;
    }
  }

  Future<bool> linkWithGoogle() async {
    // Implementa la lógica si la necesitas
    return false;
  }

  Future<bool> linkWithEmail(String email, String password) async {
    // Implementa la lógica si la necesitas
    return false;
  }

  Future<bool> linkAccountWithCredential(AuthCredential credential) async {
    // Implementa la lógica si la necesitas
    return false;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<String?> sendPasswordResetEmail(String email) async {
    // Implementa la lógica si la necesitas
    return null;
  }

  Future<void> syncDocumentToFirestore(String collection, String docId, Map<String, dynamic> data) async {
    if (_user == null) return;
    try {
      await _firestore.collection('users').doc(_user!.uid).collection(collection).doc(docId).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error al subir documento a Firestore: $e');
    }
  }

  Future<void> deleteDocumentFromFirestore(String collection, String docId) async {
    if (_user == null) return;
    try {
      await _firestore.collection('users').doc(_user!.uid).collection(collection).doc(docId).delete();
    } catch (e) {
      debugPrint('Error al eliminar documento de Firestore: $e');
    }
  }
}