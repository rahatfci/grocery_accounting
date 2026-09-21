import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/injection.dart';
import 'features/auth/presentation/auth_cubit.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Web defaults the on-disk cache to off, so offline capture needs this set
  // explicitly rather than relying on the mobile default.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  configureDependencies();
  runApp(GroceryAccountingApp(authCubit: getIt<AuthCubit>()));
}
