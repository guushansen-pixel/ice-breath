<#
.SYNOPSIS
    Baut Ice Breath ueber apk-builder und patcht danach drei Dinge nach, die
    apk-builder selbst nicht unterstuetzt: Portrait-Lock, Keep-Screen-On und
    einen eigenen Predictive-Back-Handler fuer die Zurueck-Wischgeste.
.DESCRIPTION
    apps\IceBreath unter apk-builder wird bei jedem Lauf per -Force komplett
    neu aus dem WebView-Template erzeugt (siehe apk-builder\CLAUDE.md) - die
    Patches unten muessen deshalb bei jedem Build erneut angewendet werden.
    Sie sind mit throw-Guards abgesichert: aendert sich das Template von
    apk-builder, bricht der Build laut ab statt still eine unfertige APK zu
    bauen.
.EXAMPLE
    .\build.ps1 -Release -Install
#>
[CmdletBinding()]
param(
    [string]$VersionName = '1.0',
    [int]$VersionCode = 1,
    [switch]$Release,
    [switch]$Install
)

$ErrorActionPreference = 'Stop'

# javac lehnt eine UTF-8-BOM als "Unzulaessiges Zeichen U+FEFF" ab, und
# Set-Content -Encoding utf8 schreibt in PowerShell 5.1 immer eine BOM -
# deshalb wie new-app.ps1 selbst ueber .NET BOM-frei schreiben.
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
function Write-TextNoBom {
    param([string]$Path, [string]$Content)
    [System.IO.File]::WriteAllText($Path, $Content, $Utf8NoBom)
}

$ApkBuilder = "D:\claude code projects\apk-builder"
$PackageId  = "com.daniel.icebreath"
$AppName    = "IceBreath"
$appDir     = Join-Path $ApkBuilder "apps\$AppName"

& "$ApkBuilder\new-app.ps1" -Name $AppName -PackageId $PackageId `
    -WebRoot "D:\claude code projects\ice-breath\web" `
    -Icon "D:\claude code projects\ice-breath\icon.xml" `
    -IconBackground "#12495C" `
    -VersionName $VersionName -VersionCode $VersionCode -Force

# --- AndroidManifest.xml: Portrait-Lock + Predictive Back -----------------
$manifestPath = Join-Path $appDir 'app\src\main\AndroidManifest.xml'
$manifest = Get-Content $manifestPath -Raw

# Patch 1: Portrait-Lock - eine Atem-Session soll das Layout nicht per
# Rotation neu aufbauen.
$launchModeNeedle = 'android:launchMode="singleTop">'
if ($manifest -notmatch [regex]::Escape($launchModeNeedle)) {
    throw "Manifest-Patchziel (launchMode) nicht gefunden - hat sich das apk-builder-Template geaendert?"
}
$manifest = $manifest -replace [regex]::Escape($launchModeNeedle), ('android:launchMode="singleTop"' + "`n            android:screenOrientation=`"portrait`">")

# Patch 2: Predictive Back explizit aktivieren - ab targetSdk 33 ist das
# Verhalten zwar schon Standard, aber nur mit diesem Attribut registriert
# Android unseren OnBackInvokedCallback (siehe MainActivity.java-Patch
# unten) zuverlaessig, statt sich auf einen impliziten Kompatibilitaets-
# Fallback zu verlassen.
$themeNeedle = 'android:theme="@style/AppTheme">'
if ($manifest -notmatch [regex]::Escape($themeNeedle)) {
    throw "Manifest-Patchziel (theme) nicht gefunden - hat sich das apk-builder-Template geaendert?"
}
$manifest = $manifest -replace [regex]::Escape($themeNeedle), ('android:theme="@style/AppTheme"' + "`n        android:enableOnBackInvokedCallback=`"true`">")

Write-TextNoBom -Path $manifestPath -Content $manifest

# --- MainActivity.java: Keep-Screen-On + Predictive Back ------------------
$javaDir = Join-Path $appDir ("app\src\main\java\" + $PackageId.Replace('.', '\'))
$mainActivityPath = Join-Path $javaDir 'MainActivity.java'
$java = Get-Content $mainActivityPath -Raw

$importNeedle = 'import android.view.KeyEvent;'
if ($java -notmatch [regex]::Escape($importNeedle)) {
    throw "MainActivity.java Import-Patchziel nicht gefunden - hat sich das apk-builder-Template geaendert?"
}
$java = $java -replace [regex]::Escape($importNeedle), ($importNeedle + "`nimport android.view.WindowManager;`nimport android.window.OnBackInvokedDispatcher;")

# Patch 3: Bildschirm waehrend Session wach halten. FLAG_KEEP_SCREEN_ON
# braucht keine Manifest-Permission (anders als WAKE_LOCK+PowerManager) -
# siehe Plan/README fuer die Begruendung.
$ccNeedle = 'setContentView(webView);'
if ($java -notmatch [regex]::Escape($ccNeedle)) {
    throw "MainActivity.java onCreate-Patchziel nicht gefunden - hat sich das apk-builder-Template geaendert?"
}
$java = $java -replace [regex]::Escape($ccNeedle), ($ccNeedle + "`n`n        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);")

# Patch 4: Zurueck-Wischgeste (Predictive Back). Bei targetSdk 33+ faengt
# onKeyDown/KEYCODE_BACK (unten im Template bereits vorhanden) die Geste des
# modernen Gesture-Nav-Zurueckwischens nicht mehr zuverlaessig ab - ohne
# eigenen OnBackInvokedCallback schliesst die Geste sonst direkt die App,
# statt (wie ein Tastendruck) im WebView zurueckzugehen und damit unseren
# Abbrechen-Dialog waehrend einer aktiven Session auszuloesen.
$keepScreenOnNeedle = 'getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);'
if ($java -notmatch [regex]::Escape($keepScreenOnNeedle)) {
    throw "MainActivity.java Predictive-Back-Patchziel nicht gefunden - Keep-Screen-On-Patch hat nicht wie erwartet gegriffen?"
}
$predictiveBackSnippet = $keepScreenOnNeedle + "`n`n        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {`n            getOnBackInvokedDispatcher().registerOnBackInvokedCallback(`n                    OnBackInvokedDispatcher.PRIORITY_DEFAULT,`n                    () -> {`n                        if (webView.canGoBack()) {`n                            webView.goBack();`n                        } else {`n                            finish();`n                        }`n                    });`n        }"
$java = $java -replace [regex]::Escape($keepScreenOnNeedle), $predictiveBackSnippet

Write-TextNoBom -Path $mainActivityPath -Content $java

Write-Host "  [ok] Patches angewendet (Portrait-Lock, Keep-Screen-On, Predictive Back)" -ForegroundColor Green

if ($Release -and $Install) {
    & "$ApkBuilder\build-apk.ps1" -App $AppName -Release -Install
} elseif ($Release) {
    & "$ApkBuilder\build-apk.ps1" -App $AppName -Release
} elseif ($Install) {
    & "$ApkBuilder\build-apk.ps1" -App $AppName -Install
} else {
    & "$ApkBuilder\build-apk.ps1" -App $AppName
}
