# Padel Score Board — Fase 4B: Watch tabellone in tempo reale

Base richiesta: Fase 4A già applicata sul repository e target `PadelScoreWatch Watch App` creato in Xcode.

## Cosa fa
- Il punteggio rimane governato ESCLUSIVAMENTE dal provider Flutter dell'iPhone.
- Il Watch mostra 4 pagine scorrendo orizzontalmente: Punteggio, Dettagli, Comandi, Connessione.
- I punti assegnati da iPhone/telecomando e Undo aggiornano l'orologio (WatchConnectivity).
- Lo stato più recente usa `updateApplicationContext`; con Watch raggiungibile usa anche `sendMessage` immediato.
- Il Watch può richiedere lo stato corrente con `get_match_state` o **RISINCRONIZZA**.
- I comandi sportivi del Watch sono DISABILITATI durante la 4B. Saranno attivi nella Fase 4C, con ACK e protezione dai duplicati.

## File
- `ios/Runner/AppDelegate.swift`: bridge nativo iPhone con nuova API `publishMatch`.
- `lib/services/watch_match_sync.dart` e copia `flutter_project`: conversione del punteggio in un payload ridotto e canale Flutter.
- `lib/providers/padel_score_provider.dart` e copia `flutter_project`: invio su modifiche del match e ogni 15 s di cronometro.
- `watchos/PadelScoreWatch/WatchConnectionModel.swift`: ricezione messaggi, applicationContext e snapshot su richiesta.
- `watchos/PadelScoreWatch/WatchConnectionView.swift`: quattro schermate Watch.
- `test/watch_match_sync_test.dart` e copia `flutter_project`: suite Dart.

## Procedura Xcode
1. **Non ricreare il target Watch.** Conferma che i tre Swift esistenti puntino a `watchos/PadelScoreWatch` (File Inspector → Full Path).
2. Conserva i cambiamenti locali `ios/Runner.xcodeproj/project.pbxproj` effettuati in Xcode, inclusa la posizione di **Embed Watch Content** prima di **Thin Binary**.
3. Da cartella principale: `flutter test test/watch_match_sync_test.dart`, `flutter test`, `flutter analyze`.
4. Seconda copia: `cd flutter_project && flutter test && flutter analyze && cd ..`.
5. `cd ios && pod install && cd ..` solo se CocoaPods segnala disallineamento. Apri `ios/Runner.xcworkspace`.
6. Compila lo schema Runner sul simulatore iPhone abbinato, poi lo schema Watch. Avvia entrambi.
7. Esegui una partita di prova su iPhone; verifica che punti, game, set, battitore e Undo appaiano sul Watch.
8. Chiudi e riapri la Watch App: deve recuperare l'ultimo stato con applicationContext/get_match_state.

## Limitazioni
- La visualizzazione in tempo reale richiede un iPhone raggiungibile con l'app attiva; i trasferimenti in background possono essere ritardati dal sistema.
- Nessun comando di gioco viene inviato dal Watch in questa fase; non dichiarare completa la Fase 4C.
- Il cronometro Watch è una fotografia aggiornata circa ogni 15 s; l'iPhone resta la fonte ufficiale.
- Su Android e web l'API Flutter è ignorata in sicurezza.
