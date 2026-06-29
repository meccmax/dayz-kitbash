<#
  build-templates.ps1 — Kitbash
  Extracts vanilla clothing/gear COLOR textures (*_co.paa) from the game PBOs and
  converts them to PNG paint-over templates under .\templates\<bucket>\, plus a
  templates\index.json the Forge UI reads to offer per-item underlays.

  Run once (re-run after a game update). Usage:
      ./build-templates.ps1
      ./build-templates.ps1 -Size 1024        # smaller files (downscaled)
      ./build-templates.ps1 -DayZPath "E:\SteamLibrary\steamapps\common\DayZ"
      ./build-templates.ps1 -Buckets tops,vests
#>
param(
  [string]$DayZPath = "",
  [string]$ToolsBin = "",
  [int]$Size = 0,                 # 0 = native resolution
  [string[]]$Buckets = @()        # empty = all
)
$ErrorActionPreference = "Stop"
$root    = $PSScriptRoot
$outRoot = Join-Path $root "templates"

# ---- PBO -> bucket map (bucket = how the UI groups templates) ----
$pboMap = [ordered]@{
  "characters_tops"      = "tops"
  "characters_pants"     = "pants"
  "characters_vests"     = "vests"
  "characters_headgear"  = "headgear"
  "characters_masks"     = "masks"
  "characters_gloves"    = "gloves"
  "characters_shoes"     = "shoes"
  "characters_backpacks" = "backpacks"
  "gear_containers"      = "items"
  "gear_camping"         = "items"
}

# ---- locate DayZ ----
function Find-DayZ {
  if ($DayZPath -and (Test-Path $DayZPath)) { return $DayZPath }
  $cands = @(
    "E:\SteamLibrary\steamapps\common\DayZ",
    "D:\SteamLibrary\steamapps\common\DayZ",
    "${env:ProgramFiles(x86)}\Steam\steamapps\common\DayZ"
  )
  # parse libraryfolders.vdf for extra Steam libraries
  $vdf = "${env:ProgramFiles(x86)}\Steam\steamapps\libraryfolders.vdf"
  if (Test-Path $vdf) {
    Select-String -Path $vdf -Pattern '"path"\s+"([^"]+)"' | ForEach-Object {
      $p = $_.Matches[0].Groups[1].Value -replace '\\\\','\'
      $cands += (Join-Path $p "steamapps\common\DayZ")
    }
  }
  foreach ($c in $cands) { if (Test-Path (Join-Path $c "Addons")) { return $c } }
  return $null
}
function Find-ToolsBin {
  if ($ToolsBin -and (Test-Path $ToolsBin)) { return $ToolsBin }
  $cands = @(
    "E:\SteamLibrary\steamapps\common\DayZ Tools\Bin",
    "D:\SteamLibrary\steamapps\common\DayZ Tools\Bin",
    "${env:ProgramFiles(x86)}\Steam\steamapps\common\DayZ Tools\Bin"
  )
  foreach ($c in $cands) { if (Test-Path $c) { return $c } }
  return $null
}

$dayz = Find-DayZ
if (-not $dayz) { throw "DayZ install not found. Pass -DayZPath 'X:\...\common\DayZ'." }
$bin  = Find-ToolsBin
if (-not $bin)  { throw "DayZ Tools Bin not found. Pass -ToolsBin 'X:\...\DayZ Tools\Bin'." }

$addons  = Join-Path $dayz "Addons"
$bankrev = Join-Path $bin  "PboUtils\BankRev.exe"
$img2paa = Join-Path $bin  "ImageToPAA\ImageToPAA.exe"
if (-not (Test-Path $bankrev)) { throw "BankRev.exe not found at $bankrev" }
if (-not (Test-Path $img2paa)) { throw "ImageToPAA.exe not found at $img2paa" }

Write-Host "DayZ : $dayz"  -ForegroundColor DarkGray
Write-Host "Tools: $bin"   -ForegroundColor DarkGray

$tmp = Join-Path $env:TEMP ("forge_tpl_" + [guid]::NewGuid().ToString("N").Substring(0,8))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null

$index = [ordered]@{}
$total = 0

try {
  foreach ($pbo in $pboMap.Keys) {
    $bucket = $pboMap[$pbo]
    if ($Buckets.Count -and ($Buckets -notcontains $bucket)) { continue }
    $pboFile = Join-Path $addons "$pbo.pbo"
    if (-not (Test-Path $pboFile)) { Write-Host "  skip (missing): $pbo.pbo" -ForegroundColor DarkYellow; continue }

    Write-Host "Unpacking $pbo.pbo ..." -ForegroundColor Cyan
    $dest = Join-Path $tmp $pbo
    Push-Location $addons
    & $bankrev -f $dest "$pbo.pbo" | Out-Null
    Pop-Location

    $outBucket = Join-Path $outRoot $bucket
    New-Item -ItemType Directory -Force -Path $outBucket | Out-Null
    if (-not $index.Contains($bucket)) { $index[$bucket] = New-Object System.Collections.ArrayList }

    $cos = Get-ChildItem -Path $dest -Recurse -Filter *_co.paa -ErrorAction SilentlyContinue
    Write-Host "  $($cos.Count) color texture(s)" -ForegroundColor DarkGray
    foreach ($co in $cos) {
      $png = Join-Path $outBucket ([System.IO.Path]::ChangeExtension($co.Name, ".png"))
      $args = @()
      if ($Size -gt 0) { $args += "-size=$Size" }
      $args += @($co.FullName, $png)
      & $img2paa @args | Out-Null
      if (Test-Path $png) {
        [void]$index[$bucket].Add(([System.IO.Path]::GetFileName($png)))
        $total++
      }
    }
  }

  # de-dup + sort each bucket
  $clean = [ordered]@{}
  foreach ($k in $index.Keys) { $clean[$k] = @($index[$k] | Sort-Object -Unique) }
  $clean | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $outRoot "index.json") -Encoding UTF8

  Write-Host ""
  Write-Host "Done. $total template(s) written to $outRoot" -ForegroundColor Green
  Write-Host "Reload the Forge page to use them." -ForegroundColor Green
}
finally {
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
