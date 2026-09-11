# Ice Breath

Wim-Hof-Atem-App als reine Web-App, die per [apk-builder](../apk-builder)
zu einer Android-APK wird. Laeuft komplett offline, ohne Abhaengigkeiten,
alles in einer Datei. Bewusst nur die Wim-Hof-Methode (WHM) - keine
Multi-Modality-Breathing-App wie Othership/Breathwrk, das waere ein
eigenes Projekt.

## Bauen

```powershell
cd "D:\claude code projects\ice-breath"
.\build.ps1 -Release
```

Baut *nicht* direkt mit `apk-builder`s eigenen Skripten, sondern ueber den
eigenen `build.ps1`-Wrapper, der nach dem Erzeugen des Projekts zwei Dinge
nachpatcht, die apk-builder selbst nicht kann:

- **Portrait-Lock** (`android:screenOrientation="portrait"` im Manifest) -
  eine Atem-Session soll bei Drehung nicht neu aufgebaut werden.
- **Bildschirm bleibt waehrend der Session wach**
  (`FLAG_KEEP_SCREEN_ON` in `MainActivity.onCreate`) - braucht anders als
  `WAKE_LOCK` keine Manifest-Permission. Zusaetzlich fragt die Web-App
  selbst per `navigator.wakeLock` einen Screen-Wake-Lock an (Backup, falls
  der native Flag aus irgendeinem Grund nicht greift).

`-VersionCode` bei jeder Auslieferung hochzaehlen, sonst sind zwei
APK-Versionen fuer Android nicht unterscheidbar:

```powershell
.\build.ps1 -VersionName "1.1" -VersionCode 2 -Release -Install
```

Das Icon liegt bewusst **neben** `web\`, nicht darin - sonst wanderte es
zusaetzlich als Web-Asset in die APK.

## Ablauf einer Session

Eine Runde: `Bereit (3s)` → `Power-Atmung` (konfigurierbare Anzahl
Atemzuege, Tempo einstellbar; ab der Haelfte der Atemzuege optional per
Tap vorzeitig in den Atem-Halt wechseln) → `Atem anhalten` (offenes
Stoppuhr, endet per Tap irgendwo auf dem Bildschirm) → `Erholungsatem
halten` (Countdown, Standard 15s) → kurzer `Ausatmen`-Uebergang (~2.5s,
nur zwischen Runden) → naechste Runde oder Zusammenfassung.

Der Pacer-Kreis wechselt beim Einatmen/Ausatmen die Farbe (Cyan ↔ Gruen)
als zusaetzliches visuelles Signal zum Wachsen/Schrumpfen.

Ein Abbrechen mitten in der Session (Button oder Android-Zurueck) fragt
per Bestaetigungsdialog nach und verwirft die Session komplett - sie wird
**nicht** gespeichert. Das ist absichtlich so, weil die Streak-Logik genau
darauf aufbaut: nur eine bis zum Ende durchgehaltene Session zaehlt.

## Datenmodell (localStorage)

Alle Keys namespaced + versioniert, damit ein spaeteres Schema-Update ohne
stille Migration auskommt:

- `wimhof.settings.v1` - Atemzuege/Runde, Rundenzahl, Ein-/Ausatemtempo,
  Erholungsatem-Dauer, Ton/Vibration/Theme-Toggles.
- `wimhof.sessions.v1` - Array abgeschlossener Sessions:
  ```js
  {
    id, startedAt, endedAt,
    config: { breathsPerRound, roundCount, inhaleMs, exhaleMs, recoveryHoldSec },
    rounds: [ { retentionMs, recoveryHoldMs, breathsCompleted }, ... ],
    medianRetentionMs, longestRetentionMs, totalDurationMs   // bei Save vorberechnet
  }
  ```
  Die Leaderboard-Funktionen berechnen bei Bedarf defensiv aus `rounds`
  neu, falls die vorberechneten Felder mal fehlen sollten - kein separater
  Stats-Cache, das Datenvolumen ist trivial klein.
- `wimhof.badgesSeen.v1` - IDs bereits gezeigter Achievement-Badges.
- `wimhof.coldBest.v1` - persoenliche Bestzeit im Kaelte-Timer.
- `wimhof.onboardingAccepted.v1` - Gate fuer die Sicherheitshinweise beim
  ersten Start.

## Leaderboards & Streak

Drei Kategorien, alle rein lokal/persoenlich (kein Netzwerk, keine
Mitspieler):

1. **Median-Breath-Hold** - Median der Retention-Zeiten einer Session;
   Top-5 all-time und bester Monat (`bestMedianByMonth()`).
2. **Laengste Session** - zwei getrennte Ranglisten: Gesamtdauer
   (`totalDurationMs`, Start bis Ende der Session) und laengster
   Einzel-Hold (`longestRetentionMs`, ueber alle Sessions).
3. **Daily-Streak** - "completed" heisst: die Session hat `finishSession()`
   erreicht, alle Runden durchlaufen. Zugeordnet wird der lokale
   Kalendertag von `endedAt`; mehrere Sessions am selben Tag zaehlen als
   ein Tag (Dedupe ueber `dayKey`). `currentStreak()` bewertet "ist der
   Streak heute noch am Leben" (bricht, sobald ein ganzer Kalendertag
   ohne Session vergangen ist); `longestStreak()` ist der unveraenderliche
   historische Bestwert. Beide DST-sicher ueber Tages-Arithmetik, nicht
   ueber rohe Millisekunden-Differenzen.

## Ton & Vibration

Wie bei Hopper werden alle Sound-Cues zur Laufzeit mit der Web Audio API
synthetisiert - keine Audiodateien im Repo/in der APK. Vibration nutzt
`navigator.vibrate()` mit kurzen Mustern fuer Ein-/Ausatmen, laengeren
Pulsen fuer Halt-Beginn/-Ende und Rundenwechsel.

## Achievements

Kleine, aus dem Verlauf abgeleitete Meilensteine (erste Session, 10
Sessions, 7-/30-Tage-Streak, Haelte ueber 2/3 Minuten) - kein eigener
State ausser einer Liste bereits gezeigter Badge-IDs, um Doppel-Toasts zu
vermeiden.

## Sicherheit

Beim ersten Start ein Pflicht-Screen mit den wichtigsten
Kontraindikationen (nie im/am Wasser, nie beim Autofahren, Vorerkrankungen
vorher abklaeren, bei Schwindel abbrechen) - jederzeit auch unter
Einstellungen → "Sicherheitshinweise anzeigen" wieder aufrufbar.
