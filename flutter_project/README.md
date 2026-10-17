# Padel ScoreBot (Flutter)

Applicazione mobile di tabellone segnapunti per PADEL in modalità orizzontale (Landscape), concepita per funzionare 100% OFFLINE, senza costi di abbonamento o API esterne, con sintesi vocale TTS in italiano (stile arbitro professionista), gestione rotazione 4 giocatori e controllo hardware via telecomandi Bluetooth (tasti volume).

## Struttura del Progetto
- `pubspec.yaml`: dipendenze (`flutter_tts`, `provider`, `shared_preferences`, `wakelock_plus`)
- `lib/models/padel_match_state.dart`: Modello immutabile del match con `servingRotationIndex` e storico Undo
- `lib/services/tts_service.dart`: Motore vocale offline configurato a `0.48` speechRate con tono da arbitro
- `lib/services/bluetooth_key_service.dart`: Intercettatore eventi tastiera/telecomando (Volume Up 1x/2x, Volume Down Undo)
- `lib/providers/padel_score_provider.dart`: State machine Padel con rotazione ufficiale a 4 giocatori, Punto d'Oro, Tie-break a 7 punti
- `lib/screens/match_setup_screen.dart`: **Schermata Iniziale di Setup Match** (nomi squadre, 4 giocatori, selettore 1° servizio con anteprima rotazione, regole)
- `lib/screens/landscape_scoreboard_screen.dart`: UI Landscape a 2 colonne, indicatore visivo *"IN BATTUTA: [NOME GIOCATORE]"*, font 160sp, timer cambio campo 90s FIP
- `lib/main.dart`: Configurazione orientamento forzato orizzontale, WakelockPlus e avvio da `MatchSetupScreen`
- `android/app/src/main/AndroidManifest.xml`: Blocco orientamento orizzontale e permessi
- `ios/Runner/Info.plist`: Blocco orientamento orizzontale e background audio

## Rotazione Ufficiale a 4 Giocatori
All'inizio del match si seleziona quale dei 4 giocatori serve per primo:
* **Turno 1:** Giocatore 1 (Squadra 1)
* **Turno 2:** Giocatore 3 (Squadra 2)
* **Turno 3:** Giocatore 2 (Squadra 1)
* **Turno 4:** Giocatore 4 (Squadra 2)
*(e poi ciclicamente ad ogni cambio game).*

## Mappatura Telecomando Bluetooth
- **1 Click su Volume Up**: +1 Punto Squadra 1
- **2 Click veloci su Volume Up (< 400ms)**: +1 Punto Squadra 2
- **Click su Volume Down**: Undo (Annulla ultimo punto)

## Esecuzione
```bash
flutter pub get
flutter run
```
