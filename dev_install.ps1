# Копирует плагин в папку Plugins SketchUp 2024 для разработки.
# После копирования перезапустите SketchUp (или в Ruby-консоли: load 'pathcopy_advanced.rb').
$ErrorActionPreference = "Stop"

$plugins = Join-Path $env:APPDATA "SketchUp\SketchUp 2024\SketchUp\Plugins"
if (-not (Test-Path $plugins)) {
  Write-Error "Не найдена папка плагинов SketchUp 2024: $plugins"
}

Copy-Item (Join-Path $PSScriptRoot "src\pathcopy_advanced.rb") $plugins -Force
Copy-Item (Join-Path $PSScriptRoot "src\pathcopy_advanced") $plugins -Recurse -Force
Write-Host "Установлено в $plugins"
