# Padel Score Board — Fase 4A: iPhone ↔ Apple Watch

## Ambito e limiti

Questa fase crea il ponte **WatchConnectivity + Flutter** e un test di comunicazione **Ping/Pong**. Non assegna punti dall'orologio: i comandi sportivi, Undo e la sincronizzazione dello stato della partita arriveranno nelle fasi 4B–4D. La parte React/Google AI Studio non è coinvolta.

Il progetto esportato conserva **un solo progetto Xcode iOS reale**, `ios/Runner.xcodeproj`. La cartella `flutter_project/ios/` contiene solo un plist: i file Swift per iPhone e Watch vanno configurati nel progetto `ios/` principale, non nella copia Flutter.

## 1. Applica patch e verifica Flutter

```bash
cd ~/Lavoro/PadelScore/padel-score

git apply --check ~/Downloads/Padel_Score_Board_Fase_4A.patch
git apply ~/Downloads/Padel_Score_Board_Fase_4A.patch

flutter test test/watch_link_test.dart
flutter test
flutter analyze
cd flutter_project
flutter test test/watch_link_test.dart
flutter test
flutter analyze
cd ..
git diff --check
```

Non eseguire `git add .`: nel repository ci sono file `ios/Flutter/ephemeral`, `.dart_tool` e altri file generati da escludere.

## 2. Crea il target Watch in Xcode (OBBLIGATORIO)

1. Sul Mac, usa Xcode con SDK watchOS installato. Apri `ios/Runner.xcworkspace` (oppure `ios/Runner.xcodeproj` se il workspace non è configurato).
2. Seleziona il progetto **Runner** nella barra laterale, premi `+` per aggiungere un target (o **File > New > Target**).
3. Scegli **watchOS > App**. Nome suggerito: **PadelScoreWatch**. Modalità: **Watch App for Existing iOS App**. App iOS associata: **Runner**. Non creare un nuovo progetto iOS indipendente.
4. Consenti a Xcode di creare target, build phases, scheme, Info.plist, icone e identificatori di bundle. Se Xcode chiede di attivare lo schema watchOS, accetta.
5. Nel target watchOS elimina **solo i file Swift di esempio generati da Xcode** che definiscono un `@main` e una `ContentView` (se presenti). Non eliminare il target o le impostazioni generate.
6. In Xcode scegli **File > Add Files to "Runner"** e seleziona **i tre file** da `watchos/PadelScoreWatch/`:
   - `PadelScoreWatchApp.swift`
   - `WatchConnectionModel.swift`
   - `WatchConnectionView.swift`
   Assicurati che **Target Membership** sia soltanto il target watchOS `PadelScoreWatch` e che siano inclusi in **Build Phases > Compile Sources** del target Watch. Non aggiungerli a Runner iOS.
7. Nel target Runner iOS verifica che il file `ios/Runner/AppDelegate.swift` aggiornato sia nel target **Runner**; non aggiungerlo al target Watch.
8. In **Signing & Capabilities**, verifica che Runner e Watch abbiano lo stesso Team di firma, bundle identifier Watch coerente con quello dell'app iPhone e app associata corretta. Lascia che Xcode generi gli ID di prodotto/watch; non copiare Info.plist a mano.
9. Salva il progetto. **Conserva nel commit anche `ios/Runner.xcodeproj/project.pbxproj` e gli eventuali file del target/asset creati da Xcode**: altrimenti su un altro Mac il Watch target mancherà. Evita invece qualsiasi file `ephemeral`.

Indicazioni Apple: https://developer.apple.com/documentation/watchos-apps/setting-up-a-watchos-project

## 3. Prova reale o nel simulatore

1. In Xcode seleziona una coppia iPhone + Apple Watch disponibile nei dispositivi/simulatori associati, installa ed esegui Runner iOS e la Watch App. Per i test reali usa iPhone e Apple Watch abbinati, con Bluetooth/Wi-Fi funzionanti.
2. Apri l'app su entrambi i dispositivi **in primo piano**. Il canale live `sendMessage` richiede `isReachable == true`; in background può essere false anche se il Watch è correttamente associato.
3. Nell'iPhone, apri il **setup** e trova la card **Apple Watch — Collegamento**. Deve mostrare «Apple Watch raggiungibile». Premi **Prova Ping/Pong**: attendi un risultato in millisecondi.
4. Sul Watch premi **PROVA PING**: deve apparire «Pong: ... ms». La card iPhone potrà mostrare anche la data dell'ultimo ping ricevuto.
5. Ripeti dopo aver chiuso e riaperto la Watch App. La connessione deve tornare quando entrambe le app sono nuovamente attive.
6. Se la card mostra «Installa l'app su Apple Watch» controlla prima l'installazione e il bundle, non cambiare il codice del motore di punteggio.

Queste prove non possono essere eseguite nell'anteprima web di Google AI Studio. Devi utilizzare l'app iPhone compilata da Flutter/Xcode e un simulatore abbinato o un Watch fisico.

## 4. Protocollo 4A e decisioni di sicurezza

- Canali Flutter: `padel_score_board/watch_link` e `padel_score_board/watch_link_events`.
- Metodi Flutter: `getStatus`, `activate`, `ping`.
- Messaggi WatchConnectivity: `{"type":"ping", "requestId":"<UUID>"}` e risposta `{"type":"pong", "requestId":"<UUID>"}`.
- Il `requestId` viene verificato sul dispositivo mittente per confermare che la risposta corrisponda alla richiesta.
- Nessun punto, Undo o risultato viene trasmesso nella Fase 4A.
- Per i **futuri comandi 4C**, l'iPhone sarà l'unica fonte autorevole del punteggio. A ogni comando Watch verrà assegnato un ID univoco per deduplicazione; l'iPhone invierà snapshot/versione confermati ai dispositivi. Mai mettere in coda incrementi di punti offline da riapplicare silenziosamente.
- `updateApplicationContext` servirà alla replica dello **stato più recente** quando il Watch non è raggiungibile live. Non sostituisce la consegna istantanea in background.

## 5. Test e commit dopo Xcode

```bash
flutter test && flutter analyze
cd flutter_project && flutter test && flutter analyze && cd ..
git diff --check
git status --short
```

Prima del commit confronta `git diff --stat` e `git status --short`, includendo **solo** codice Fase 4A, i file del target Watch generati da Xcode e le configurazioni Xcode necessarie. Non applicare `git add .`.
