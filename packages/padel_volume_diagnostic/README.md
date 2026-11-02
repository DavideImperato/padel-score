# Debug volume diagnostic (iOS only)

Development-only experiment for Padel Score Board. It attempts to set the iOS
output volume through an MPVolumeView associated with the active UIWindowScene,
then reads AVAudioSession.outputVolume to report whether the request took effect.

It **does not** intercept hardware buttons before iOS, block system volume,
hide the system volume HUD or guarantee that a volume-key press will be delivered.
It must not be shipped in TestFlight/App Store builds. Apple App Review
Guideline 2.5.9 prohibits altering or disabling the normal functions of volume
buttons.

Run from the root project:

```
flutter pub get
flutter test test/padel_volume_diagnostic_test.dart
flutter run --debug -t lib/padel_native_volume_probe.dart
```

Compare the real volume, STREAM event counter and the confirmed status after
pressing `Imposta 50%` and `Imposta 80%` on a physical iPhone. If confirmed is
false, the plugin could not set the actual volume. Do not connect it to the
score engine before that native confirmation succeeds reliably.

The production app and Apple Watch code are untouched by this probe. To revert,
use the supplied Git patch with `git apply -R` after checking with
`git apply -R --check`.
