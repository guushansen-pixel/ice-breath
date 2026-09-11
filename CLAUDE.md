# Ice Breath

Offline Android-App fuer die Wim-Hof-Atemmethode, reine Web-App in einer
Datei, die per [apk-builder](../apk-builder) zur APK wird. Details zu
Datenmodell, Leaderboards/Streak-Logik, Timer-Engine stehen in
[README.md](README.md) - dort nachlesen statt hier duplizieren.

## Build & Test

Kein Bundler, kein Build-Step fuer die Web-App selbst - `web/index.html`
ist direkt per `file://` im Browser lauffaehig und dort auch primaer zu
testen (Session-Ablauf, Settings, Verlauf/Bestenliste, Persistenz nach
Reload). `?fast=1` an die URL anhaengen, um alle Zeit-Konstanten durch 10
zu teilen und schnell durchzuklicken.

APK bauen - **nicht** direkt `apk-builder\new-app.ps1`/`build-apk.ps1`
aufrufen, sondern immer ueber den eigenen Wrapper, der Portrait-Lock und
Keep-Screen-On nachpatcht (apk-builder unterstuetzt beides nicht nativ,
und `apps\IceBreath` wird bei jedem `-Force`-Lauf komplett neu generiert):

```powershell
cd "D:\claude code projects\ice-breath"
.\build.ps1                              # Debug-APK
.\build.ps1 -Release                     # signierte Release-APK
.\build.ps1 -Release -Install            # + adb install auf verbundenes Geraet
.\build.ps1 -VersionName "1.1" -VersionCode 2 -Release   # bei jedem Release hochzaehlen
```

Was sich nur auf dem echten Geraet (Pixel 11 Pro) verifizieren laesst,
nicht im Desktop-Browser: Vibrationsgefuehl, ob der Bildschirm waehrend
einer echten Session wach bleibt, WebView-Force-Dark-Verhalten, Portrait-
Lock, Android-Back waehrend einer aktiven Session (muss den Abbrechen-
Dialog oeffnen statt die App zu schliessen).

## Konventionen

- Alles in `web/index.html` (HTML+CSS+JS inline), kein Framework, keine
  externen Abhaengigkeiten - muss offline funktionieren.
- `icon.xml` liegt bewusst **neben** `web/`, nicht darin.
- localStorage-Keys sind versioniert und namespaced (`wimhof.settings.v1`,
  `wimhof.sessions.v1`, ...) - bei einer Schemaaenderung neue
  Versionsnummer statt stillschweigender Migration.
- Nur `finishSession()` schreibt einen Session-Record nach `sessions` -
  `cancelSession()` nie. Das ist absichtlich so, weil die Streak-Logik
  genau darauf aufbaut (siehe README).
- Harter Anspruch: kein Netzwerkzugriff, keine Geraetedaten ausser dem, was
  die App selbst braucht (Vibration). `new-app.ps1` wird ohne `-Online`
  aufgerufen; einzige Permission im Manifest ist VIBRATE.

## Aktueller Stand

Erste Version fertig: WHM-Session (konfigurierbare Atemzuege/Runden/Tempo/
Erholungsatem-Dauer), Leaderboards (Median-Hold pro Session + pro Monat,
laengste Session, laengster Einzel-Hold, Daily-Streak), Achievement-Badges,
Kaelte-Timer, Sicherheitshinweise. Im Browser durchgetestet; APK-Build und
Geraetetest auf dem Pixel 11 Pro stehen noch aus.
