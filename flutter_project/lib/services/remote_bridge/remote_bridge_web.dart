// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js' as js;
import 'remote_bridge.dart';

RemoteBridge createRemoteBridge() => RemoteBridgeWeb();

/// Implementazione Web: Gestisce lo sblocco dell'audio in background (silent audio loop)
/// e la MediaSession API del browser per intercettare gli impulsi dei telecomandi selfie Bluetooth
/// su iOS/Safari e Android/Chrome.
class RemoteBridgeWeb implements RemoteBridge {
  static const String _silentAudioUri =
      'data:audio/wav;base64,UklGRjIAAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YRAAAAAAAAAAAAAAAAAAAAAA';

  html.AudioElement? _silentAudio;
  bool _isAudioUnlocked = false;
  html.EventListener? _customEventListener;
  html.EventListener? _interactionListener;

  void Function(String action)? _signalHandler;

  @override
  void init({required void Function(String action) onSignal}) {
    _signalHandler = onSignal;

    // 1. Registra callback su window.__onPadelRemoteSignal per chiamate JS dirette
    try {
      js.context['__onPadelRemoteSignal'] = js.allowInterop((dynamic action) {
        final actStr = action?.toString() ?? 'click';
        _handleSignal(actStr);
      });
    } catch (_) {}

    // 2. Ascolta l'evento personalizzato 'padel-remote-signal' da JS
    _customEventListener = (html.Event event) {
      if (event is html.CustomEvent) {
        final dynamic detail = event.detail;
        if (detail is Map && detail.containsKey('action')) {
          _handleSignal(detail['action'].toString());
        } else {
          _handleSignal('click');
        }
      } else {
        _handleSignal('click');
      }
    };

    try {
      html.window.addEventListener('padel-remote-signal', _customEventListener!);
    } catch (_) {}

    // 3. Predispone l'elemento audio silenzioso nel DOM
    _ensureSilentAudioElement();

    // 4. Collega listener per il primo tocco/clic dell'utente per sbloccare l'audio
    _interactionListener = (html.Event event) {
      unlockAudio();
    };

    try {
      html.window.addEventListener('click', _interactionListener!, true);
      html.window.addEventListener('touchstart', _interactionListener!, true);
      html.window.addEventListener('pointerdown', _interactionListener!, true);
      html.window.addEventListener('keydown', _interactionListener!, true);
    } catch (_) {}

    // Tenta subito uno sblocco (se il contesto lo consente)
    unlockAudio();
  }

  void _handleSignal(String action) {
    if (_signalHandler != null) {
      _signalHandler!(action);
    }
  }

  void _ensureSilentAudioElement() {
    try {
      var audio = html.document.getElementById('padel-silent-audio') as html.AudioElement?;
      if (audio == null) {
        audio = html.AudioElement()
          ..id = 'padel-silent-audio'
          ..src = _silentAudioUri
          ..loop = true
          ..volume = 0.01;
        audio.setAttribute('playsinline', 'true');
        audio.setAttribute('webkit-playsinline', 'true');
        html.document.body?.append(audio);
      }
      _silentAudio = audio;
    } catch (_) {}
  }

  @override
  void unlockAudio() {
    if (_isAudioUnlocked) return;

    _ensureSilentAudioElement();

    if (_silentAudio != null) {
      try {
        final playPromise = _silentAudio!.play();
        playPromise.then((_) {
          _isAudioUnlocked = true;
          _setupMediaSession();
        }).catchError((_) {
          // In attesa del primo gesto utente esplicito
        });
      } catch (_) {}
    }
  }

  /// Configura la MediaSession API del browser per catturare i comandi multimediali
  /// inviati dai telecomandi selfie Bluetooth (play, pause, nexttrack, previoustrack, stop).
  void _setupMediaSession() {
    try {
      final dynamic navigator = js.context['navigator'];
      if (navigator == null || navigator['mediaSession'] == null) return;

      final dynamic mediaSession = navigator['mediaSession'];

      // Metadati per lock screen e centro notifiche
      try {
        if (js.context['MediaMetadata'] != null) {
          mediaSession['metadata'] = js.JsObject(js.context['MediaMetadata'], [
            js.JsObject.jsify({
              'title': 'Padel ScoreBot',
              'artist': 'Telecomando Bluetooth Attivo',
              'album': 'Segnapunti Padel',
            })
          ]);
        }
      } catch (_) {}

      final actions = [
        'play',
        'pause',
        'nexttrack',
        'previoustrack',
        'stop',
        'seekbackward',
        'seekforward'
      ];

      for (final act in actions) {
        try {
          mediaSession.callMethod('setActionHandler', [
            act,
            js.allowInterop(() {
              _handleSignal(act);
            })
          ]);
        } catch (_) {}
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    if (_customEventListener != null) {
      try {
        html.window.removeEventListener('padel-remote-signal', _customEventListener!);
      } catch (_) {}
      _customEventListener = null;
    }

    if (_interactionListener != null) {
      try {
        html.window.removeEventListener('click', _interactionListener!, true);
        html.window.removeEventListener('touchstart', _interactionListener!, true);
        html.window.removeEventListener('pointerdown', _interactionListener!, true);
        html.window.removeEventListener('keydown', _interactionListener!, true);
      } catch (_) {}
      _interactionListener = null;
    }

    try {
      _silentAudio?.pause();
      _silentAudio?.remove();
    } catch (_) {}
    _silentAudio = null;

    try {
      js.context.deleteProperty('__onPadelRemoteSignal');
    } catch (_) {}

    _signalHandler = null;
  }
}
