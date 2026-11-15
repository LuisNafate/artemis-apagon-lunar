param([string]$Godot)

$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot

if (-not $Godot) {
    $command = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { $Godot = $command.Source }
}
if (-not $Godot) {
    $packageRoot = Join-Path $env:LOCALAPPDATA 'Microsoft/WinGet/Packages'
    $match = Get-ChildItem $packageRoot -Recurse -Filter '*godot*console.exe' -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($match) { $Godot = $match.FullName }
}
if (-not $Godot) { throw 'Indica la ruta al ejecutable de Godot 4 con -Godot.' }

$python = Get-Command python3, python -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $python) { throw 'Instala Python 3 y gdtoolkit para validar los scripts.' }
$log = [IO.Path]::GetTempFileName()

function Invoke-GodotCheck {
    param([string]$Name, [string[]]$GodotArguments)
    Write-Host "--- $Name"
    [IO.File]::WriteAllText($log, '')
    & $Godot --headless --path $project --log-file $log @GodotArguments | Out-Null
    $engineStatus = $LASTEXITCODE
    $logContents = Get-Content -Raw -LiteralPath $log
    if ($engineStatus -ne 0 -or $logContents -match '(?im)^\s*(SCRIPT ERROR|ERROR|WARNING|Parse Error):') {
        throw "$Name falló (salida $engineStatus).`n$logContents"
    }
    if ($Name -like 'Regresión*' -and $logContents -notmatch '(?m)^(ARTEMIS|OUTPOST|FIELD|CREST|LUNAR|OPEN) SUITE: \d+ cases, \d+ assertions, 0 failed') {
        throw 'La suite se cerró antes de completar los casos.'
    }
    $logContents -split '\r?\n' | Where-Object { $_ -match '^Godot Engine|^(ARTEMIS|OUTPOST|FIELD|CREST|LUNAR|OPEN) SUITE' }
}

Push-Location $project
try {
    & $python.Source -m gdtoolkit.formatter --check src tests outpost field crest lunar
    if ($LASTEXITCODE -ne 0) { throw 'Falló gdformat.' }
    & $python.Source -m gdtoolkit.linter src tests outpost field crest lunar
    if ($LASTEXITCODE -ne 0) { throw 'Falló gdlint.' }
    Invoke-GodotCheck -Name 'Importación en editor' -GodotArguments @('--editor', '--import')
    Invoke-GodotCheck -Name 'Arranque principal' -GodotArguments @('--quit-after', '12')
    Invoke-GodotCheck -Name 'Regresión' -GodotArguments @('--quit-after', '300', 'res://tests/mission_suite.tscn')
    Invoke-GodotCheck -Name 'Regresión del puesto lunar' -GodotArguments @('--quit-after', '300', 'res://tests/outpost_suite.tscn')
    Invoke-GodotCheck -Name 'Regresión 3D' -GodotArguments @('--disable-render-loop', '--fixed-fps', '60', '--quit-after', '8000', 'res://tests/field_suite.tscn')
    Invoke-GodotCheck -Name 'Regresión Estación Cresta' -GodotArguments @('--fixed-fps', '60', '--quit-after', '25000', 'res://tests/crest_suite.tscn')
    Invoke-GodotCheck -Name 'Regresión campaña lunar' -GodotArguments @('--fixed-fps', '60', '--quit-after', '2400', 'res://tests/lunar_suite.tscn')
    Invoke-GodotCheck -Name 'Regresión mundo abierto' -GodotArguments @('--fixed-fps', '60', '--quit-after', '6000', 'res://tests/open_world_suite.tscn')
} finally {
    Pop-Location
    Remove-Item -LiteralPath $log -ErrorAction SilentlyContinue
}
