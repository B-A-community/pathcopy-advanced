# Собирает src\ в build\PathCopyAdvanced-<версия>.rbz — например
# build\PathCopyAdvanced-0.1.0.rbz. Имя архива на идентичность расширения не
# влияет: SketchUp читает pathcopy_advanced.rb из КОРНЯ архива, а версию —
# из src\pathcopy_advanced\constants.rb, откуда её берёт и этот скрипт.
# Запуск:  powershell -ExecutionPolicy Bypass -File tools\build_rbz.ps1

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$src  = Join-Path $root 'src'
$out  = Join-Path $root 'build'

if (-not (Test-Path $src)) { throw "Нет папки с исходниками: $src" }

# 1. Версия берётся из исходника, чтобы имя пакета не разъезжалось с кодом
$constants = Join-Path $src 'pathcopy_advanced\constants.rb'
$match = Select-String -Path $constants -Pattern "VERSION\s*=\s*'([^']+)'" | Select-Object -First 1
if (-not $match) { throw "Не нашёл VERSION в $constants" }
$version = $match.Matches[0].Groups[1].Value

$name = "PathCopyAdvanced-$version.rbz"
$rbz  = Join-Path $out $name
New-Item -ItemType Directory -Force $out | Out-Null
if (Test-Path $rbz) { Remove-Item $rbz -Force }

# 2. Упаковка.
# Записи добавляем поштучно: CreateFromDirectory и Compress-Archive в .NET
# Framework / PS 5.1 пишут пути через обратный слэш, а ZIP требует прямой —
# SketchUp такой архив разложит в один файл "pathcopy_advanced\tool.rb"
# вместо папки.
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::Open($rbz, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    $prefix = (Resolve-Path $src).Path.TrimEnd('\') + '\'
    Get-ChildItem $src -Recurse -File | Sort-Object FullName | ForEach-Object {
        $entryName = $_.FullName.Substring($prefix.Length).Replace('\', '/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $archive, $_.FullName, $entryName, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
} finally {
    $archive.Dispose()
}

Write-Host "Собрано: $rbz"
$check = [System.IO.Compression.ZipFile]::OpenRead($rbz)
$check.Entries | ForEach-Object { Write-Host ("  {0,-45} {1,7} б" -f $_.FullName, $_.Length) }
$check.Dispose()
