# Padel Score Board — applicazione nativa Flutter

Padel Score Board è un progetto **offline-first** dedicato al segnapunti padel, allo storico, alle statistiche punto per punto e ai tornei. La vecchia versione React/Vite e il target Flutter Web sono stati rimossi nella Fase 6D: **il progetto principale non ha più una versione browser**.

## Piattaforme e stato

| Dispositivo | Stato del progetto |
| --- | --- |
| iPhone | App Flutter con tabellone, gestione partite e tornei; da ricompilare e testare dopo ogni aggiornamento |
| iPad | App iOS Flutter, con layout e rotazioni da verificare su simulatore e dispositivo reale |
| Smartphone Android | Codice Flutter condiviso; build Android nativa **ancora da verificare/completare** |
| Tablet Android | Stesso codice Flutter; da verificare layout, orientamento e build |
| Apple Watch | Companion SwiftUI/watchOS e comunicazione WatchConnectivity con l'iPhone |
| Smartwatch Android / Wear OS | **Non ancora implementato**. Richiede un companion Wear OS e sincronizzazione con Android; è la prossima fase dedicata |

> La rimozione del web **non aggiunge** automaticamente il supporto Wear OS o le configurazioni Android eventualmente mancanti.

## Codice e directory da conservare

- `lib/`, `test/`, `assets/`: applicazione Flutter primaria, motore punteggio e test.
- `ios/`: progetto Runner e target **PadelScoreWatch Watch App**, con le relative configurazioni Xcode.
- `android/`: configurazione Android esistente. Verificare la presenza dei file Gradle prima di una build Android.
- `watchos/PadelScoreWatch/`: sorgenti Watch conservati, anche se alcune copie Swift vengono compilate dal target sotto `ios/`.
- `flutter_project/`: seconda copia storica dei sorgenti Flutter e dei test. Non è stata eliminata né consolidata automaticamente, per evitare di rompere configurazioni e procedure di lavoro esistenti.
- `test/fixtures/scoring_parity_cases.json`: casi di regressione congelati; continuano a verificare il motore Flutter **senza Node/React**.

Non eliminare a mano i file Swift di Watch, i target Xcode né le dipendenze Flutter iOS durante la pulizia.

## Comandi Flutter (Mac)

Dalla root del repository:

```bash
flutter pub get
flutter test
flutter analyze
open ios/Runner.xcworkspace
```

In Xcode compilare prima **Runner** per iPhone e poi **PadelScoreWatch Watch App** per Watch, senza `Clean Build Folder` fra le due build se compare il noto problema di dipendenze Flutter del target Watch.

Se i file di compilazione Android (ad esempio Gradle wrapper e `settings.gradle`) mancano, **non** assumere che Android sia già pubblicabile: la configurazione del progetto va completata e verificata in una fase separata, preservando il codice e il manifesto esistenti.

### Seconda copia Flutter (test)

```bash
cd flutter_project
flutter pub get
flutter test
flutter analyze
```

## Backup e rimozione del web

Prima di applicare la patch 6D, creare un backup dei file web ancora presenti e un branch di archivio del commit corrente. La patch elimina soltanto React/Vite/Node e il target Flutter Web; non elimina dati utente, schermate native, risorse padel o Apple Watch.

Nota: `git branch` punta all'ultimo **commit**; se le fasi recenti sono ancora modifiche locali, salvarne anche una copia nell'archivio `.tar.gz` suggerito dalla guida 6D.
