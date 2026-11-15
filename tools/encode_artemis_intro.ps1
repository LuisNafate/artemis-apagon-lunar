param([string]$Output = 'dist/intro')

$ErrorActionPreference = 'Stop'
$Project = Split-Path -Parent $PSScriptRoot
$Work = (Resolve-Path -LiteralPath $Output).Path
$Frames = Join-Path $Work 'fotogramas'
$Assets = Join-Path $Project 'assets/cinematica'
New-Item -ItemType Directory -Force $Assets | Out-Null
$InputPattern = Join-Path $Frames 'artemis-%04d.png'

for ($Index = 1; $Index -le 480; $Index++) {
    if (-not (Test-Path -LiteralPath (Join-Path $Frames ('artemis-{0:0000}.png' -f $Index)))) {
        throw "No se encuentra el fotograma $Index."
    }
}

function Invoke-Encode {
    param([string[]]$Options)
    & ffmpeg -hide_banner -loglevel error -y @Options
    if ($LASTEXITCODE -ne 0) { throw 'Falló la codificación en FFmpeg.' }
}

$common = @('-framerate', '24', '-start_number', '1', '-i', $InputPattern)
Invoke-Encode ($common + @('-frames:v', '480', '-an', '-c:v', 'libx264', '-preset', 'fast',
    '-crf', '17', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', (Join-Path $Work 'artemis-apertura.mp4')))

# Playing videos in Godot uses the built-in Theora decoder.
$theora = @('-an', '-c:v', 'libtheora', '-q:v', '8', '-pix_fmt', 'yuv420p', '-vf', 'scale=1280:720')
Invoke-Encode ($common + @('-frames:v', '384') + $theora + @((Join-Path $Assets 'artemis-viaje.ogv')))
$loop = @('-framerate', '24', '-start_number', '385', '-i', $InputPattern, '-frames:v', '96')
Invoke-Encode ($loop + $theora + @((Join-Path $Assets 'artemis-luna.ogv')))
Invoke-Encode @('-i', (Join-Path $Frames 'artemis-0385.png'), '-vf', 'scale=1280:720',
    '-frames:v', '1', (Join-Path $Assets 'artemis-luna.png'))
