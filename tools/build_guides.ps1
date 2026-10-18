# Печатает инструкции docs\guide-rus.html и docs\guide-eng.html в PDF
# docs\pathcopy-advanced-<версия>-guide-rus.pdf / -eng.pdf — headless Chrome или
# Edge, как у инструкций area counter и RALNCS. Версия берётся из
# src\pathcopy_advanced\constants.rb.
# Запуск:  powershell -ExecutionPolicy Bypass -File tools\build_guides.ps1
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$docs = Join-Path $root 'docs'
$match = Select-String -Path (Join-Path $root 'src\pathcopy_advanced\constants.rb') -Pattern "VERSION\s*=\s*'([^']+)'" | Select-Object -First 1
if (-not $match) { throw 'Не нашёл VERSION в src\pathcopy_advanced\constants.rb' }
$version = $match.Matches[0].Groups[1].Value

$browser = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $browser) { throw 'Нужен Chrome или Edge для печати PDF' }

# Отдельный профиль: печать не задевает открытый браузер пользователя
$pdfProfile = Join-Path $env:TEMP 'pathcopy_advanced_pdf_profile'

foreach ($lang in @('rus', 'eng')) {
    $html = Join-Path $docs "guide-$lang.html"
    $pdf  = Join-Path $docs ('pathcopy-advanced-{0}-guide-{1}.pdf' -f $version, $lang)
    Remove-Item $pdf -ErrorAction SilentlyContinue
    $url = 'file:///' + $html.Replace('\', '/').Replace(' ', '%20')
    # Start-Process склеивает аргументы через пробел — пути с пробелами берём в кавычки
    $argList = @('--headless=new', '--disable-gpu', "`"--user-data-dir=$pdfProfile`"", '--no-pdf-header-footer',
                 "`"--print-to-pdf=$pdf`"", "`"$url`"")
    Start-Process -FilePath $browser -ArgumentList $argList -Wait -WindowStyle Hidden
    if (-not (Test-Path $pdf)) { throw "PDF не появился: $pdf" }
    Write-Host ("Готово: {0} ({1} б)" -f $pdf, (Get-Item $pdf).Length)
}
