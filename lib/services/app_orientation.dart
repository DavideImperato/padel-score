import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Home e schermate di gestione in verticale; solo il tabellone in landscape.
class AppOrientation {
  // Flutter imposta gli orientamenti consentiti; sulle scene iPadOS la
  // richiesta UIKit esplicita aiuta l'OS ad applicare la geometria nuova.
  // Su iPadOS con finestra libera, il sistema può comunque rifiutarla.
  static const MethodChannel _iPadGeometry =
      MethodChannel('padel_score_board/ipad_geometry');

  static Future<void> _updateIPadScene(String orientation) async {
    if (!Platform.isIOS) return;
    try {
      await _iPadGeometry.invokeMethod<void>('requestOrientation', orientation);
    } on MissingPluginException {
      // Non impedire l'apertura delle schermate se il bridge non è registrato.
    } on PlatformException {
      // Il sistema mantiene il controllo dell'orientamento delle finestre.
    }
  }

  static Future<void> home() async {
    await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    await _updateIPadScene('portrait');
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  /// Il setup resta verticale, incluso il ritorno dal tabellone.
  static Future<void> setup() => home();

  static Future<void> match() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await _updateIPadScene('landscape');
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
}

/// Notifica la Home quando si torna indietro da una pagina gestita dal Navigator.
final RouteObserver<ModalRoute<dynamic>> homeRouteObserver = RouteObserver<ModalRoute<dynamic>>();
