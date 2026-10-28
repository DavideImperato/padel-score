import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Home e schermate di gestione in verticale; solo il tabellone in landscape.
class AppOrientation {
  static Future<void> home() async {
    await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  /// Il setup resta verticale, incluso il ritorno dal tabellone.
  static Future<void> setup() => home();

  static Future<void> match() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
}

/// Notifica la Home quando si torna indietro da una pagina gestita dal Navigator.
final RouteObserver<ModalRoute<dynamic>> homeRouteObserver = RouteObserver<ModalRoute<dynamic>>();
