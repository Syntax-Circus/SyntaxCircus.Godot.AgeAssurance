#Requires -Version 7.0
<#
.SYNOPSIS
Builds and tests the native Android bridge and Godot addon, then writes a local versioned ZIP and manifest.
.DESCRIPTION
Like SyntaxCircus.Godot.GamesServices, this never creates a tag or uploads a release.
The GitHub release workflow publishes these tested outputs. iOS sources are delivered for consumer-side Mac builds.
#>
[CmdletBinding()]
param(
    [string]$Version,
    [string]$GodotPath = $env:GODOT_PATH,
    [string]$JavaHome = $env:JAVA_HOME,
    [string]$AndroidHome = $(if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { $env:ANDROID_SDK_ROOT }),
    [string]$PythonPath = 'python',
    [string]$GradlePath,
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'dist'),
    [switch]$SkipTests,
    [switch]$DryRun
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $Version) {
    $cfg = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'addons/syntaxcircus_age_assurance/plugin.cfg') -Raw
    if ($cfg -notmatch '(?m)^version="([^"\r\n]+)"') { throw 'plugin.cfg has no version' }
    $Version = $Matches[1]
}
if ($Version -notmatch '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$') { throw 'Version must be X.Y.Z without a v prefix' }
if (-not $JavaHome -or -not $AndroidHome) { throw 'Set JAVA_HOME (JDK17) and ANDROID_HOME (SDK36), or pass their parameters' }
if (-not $SkipTests -and -not $GodotPath) { throw 'Set GODOT_PATH or pass -GodotPath' }
$env:JAVA_HOME = $JavaHome
$env:ANDROID_HOME = $AndroidHome
if (-not $GradlePath) { $GradlePath = Join-Path $PSScriptRoot $(if ($IsWindows) { 'android/gradlew.bat' } else { 'android/gradlew' }) }
if (-not $SkipTests) {
    & $PythonPath (Join-Path $PSScriptRoot 'tests/test_release.py')
    if ($LASTEXITCODE) { throw 'Release packaging tests failed' }
}
$tasks = @(':plugin:assembleDebug', ':plugin:assembleRelease')
if (-not $SkipTests) { $tasks = @(':plugin:testDebugUnitTest') + $tasks }
& $GradlePath --no-daemon -p (Join-Path $PSScriptRoot 'android') @tasks
if ($LASTEXITCODE) { throw 'Native Android build/tests failed' }
if (-not $SkipTests) {
    foreach ($name in 'test_age_assurance','test_native_adapter') {
        & $GodotPath --headless --path $PSScriptRoot --script "res://tests/$name.gd"
        if ($LASTEXITCODE) { throw "Godot test $name failed" }
    }
}
$arguments = @((Join-Path $PSScriptRoot 'scripts/release.py'), '--version', $Version, '--output', $OutputDirectory)
if (Test-Path -LiteralPath (Join-Path $PSScriptRoot '.git')) {
    $commit = & git -C $PSScriptRoot rev-parse HEAD
    if ($LASTEXITCODE) { throw 'Cannot determine source commit; commit source before packaging' }
    $arguments += @('--source-commit', $commit.Trim())
}
& $PythonPath @arguments
if ($LASTEXITCODE) { throw 'Release packaging failed' }
if ($DryRun) { Write-Host 'Dry run: built and tested locally; no tag, push or GitHub release created.' }
