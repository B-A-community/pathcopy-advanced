# Regenerates the PNG icons from the same geometry the SVGs use.
# SketchUp takes SVG on Windows for crisp HiDPI toolbars; the PNGs are the
# fallback for macOS and for SketchUp 2015 and older.

Add-Type -AssemblyName System.Drawing

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$out  = Join-Path (Split-Path -Parent $here) "src\pathcopy_advanced\icons"
if (-not (Test-Path $out)) { New-Item -ItemType Directory -Path $out | Out-Null }

# Control points of the path glyph, in a 24x24 design grid.
$P0 = @(2.0, 18.0); $C1 = @(9.0, 19.0); $C2 = @(13.0, 6.0); $P3 = @(22.0, 7.0)

function Get-BezierPoint([double]$t) {
    $u = 1.0 - $t
    $a = $u * $u * $u
    $b = 3.0 * $u * $u * $t
    $c = 3.0 * $u * $t * $t
    $d = $t * $t * $t
    @(
        (($a * $P0[0]) + ($b * $C1[0]) + ($c * $C2[0]) + ($d * $P3[0])),
        (($a * $P0[1]) + ($b * $C1[1]) + ($c * $C2[1]) + ($d * $P3[1]))
    )
}

function New-Icon([int]$size, [string]$file, [double]$boxSize, [double]$stroke) {
    $scale = $size / 24.0
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)

    $pathPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 74, 74, 74), [single]($stroke * $scale))
    $pathPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pathPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawBezier($pathPen, `
        [single]($P0[0] * $scale), [single]($P0[1] * $scale), `
        [single]($C1[0] * $scale), [single]($C1[1] * $scale), `
        [single]($C2[0] * $scale), [single]($C2[1] * $scale), `
        [single]($P3[0] * $scale), [single]($P3[1] * $scale))

    $fill = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 46, 125, 209))
    $edge = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 27, 79, 134), [single](1.0 * $scale))

    foreach ($t in @(0.0, 0.3333, 0.6667, 1.0)) {
        $p = Get-BezierPoint $t
        $x = ($p[0] - $boxSize / 2.0) * $scale
        $y = ($p[1] - $boxSize / 2.0) * $scale
        $w = $boxSize * $scale
        $g.FillRectangle($fill, [single]$x, [single]$y, [single]$w, [single]$w)
        $g.DrawRectangle($edge, [single]$x, [single]$y, [single]$w, [single]$w)
    }

    $g.Dispose()
    $target = Join-Path $out $file
    $bmp.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output "wrote $target"
}

function New-Cursor([string]$file) {
    $size = 32
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)

    # Standard arrow, hotspot at (4,4) to match Icons.cursor.
    $arrow = @(
        (New-Object System.Drawing.PointF(4, 3)),
        (New-Object System.Drawing.PointF(4, 18)),
        (New-Object System.Drawing.PointF(8, 14)),
        (New-Object System.Drawing.PointF(11, 21)),
        (New-Object System.Drawing.PointF(14, 19)),
        (New-Object System.Drawing.PointF(11, 13)),
        (New-Object System.Drawing.PointF(16, 13))
    )
    $g.FillPolygon((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)), $arrow)
    $g.DrawPolygon((New-Object System.Drawing.Pen([System.Drawing.Color]::Black, 1.4)), $arrow)

    # Miniature path glyph in the lower right.
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 74, 74, 74), 1.6)
    $g.DrawBezier($pen, 16, 29, 20, 30, 22, 22, 30, 22)
    $fill = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 46, 125, 209))
    foreach ($p in @(@(16, 29), @(23, 25), @(30, 22))) {
        $g.FillRectangle($fill, [single]($p[0] - 2), [single]($p[1] - 2), 4, 4)
    }

    $g.Dispose()
    $target = Join-Path $out $file
    $bmp.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output "wrote $target"
}

New-Icon -size 24 -file "pca_large.png" -boxSize 5.0 -stroke 1.6
New-Icon -size 16 -file "pca_small.png" -boxSize 5.5 -stroke 2.0
New-Cursor -file "pca_cursor.png"
