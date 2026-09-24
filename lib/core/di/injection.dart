import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:injectable/injectable.dart';

import 'injection.config.dart';

final getIt = GetIt.instance;

@InjectableInit()
void configureDependencies() => getIt.init();

@module
abstract class FirebaseModule {
  @lazySingleton
  FirebaseAuth get firebaseAuth => FirebaseAuth.instance;

  @lazySingleton
  FirebaseFirestore get firestore => FirebaseFirestore.instance;
}

@module
abstract class ReceiptsModule {
  @lazySingleton
  ImagePicker get imagePicker => ImagePicker();

  /// Receipt photos go to Supabase Storage over its REST API.
  @lazySingleton
  http.Client get httpClient => http.Client();
}

@module
abstract class NotificationsModule {
  @lazySingleton
  FlutterLocalNotificationsPlugin get notifications =>
      FlutterLocalNotificationsPlugin();
}
