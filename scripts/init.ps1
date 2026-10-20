# Applies a profile and optional modules to this template, then fills in placeholders.
# Behavior is specified in modules/README.md. Keep scripts/init.sh in sync with this file.
#
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\init.ps1
#          -Name NAME [-Profile lite|full] [-Modules a,b]
#          [-InstallCmd CMD] [-RunCmd CMD] [-CheckCmd CMD] [-DryRun] [-Keep]
#   -DryRun  print what would change, touch nothing
#   -Keep    do not delete modules/, the init scripts and TEMPLATE.md afterwards
param(
  [string]$Name = '',
  [string]$Profile = 'lite',
  [string[]]$Modules = @(),
  [string]$InstallCmd = '',
  [string]$RunCmd = '',
  [string]$CheckCmd = '',
  [switch]$DryRun,
  [switch]$Keep
)
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Mods = Join-Path $Root 'modules'
$Utf8 = New-Object System.Text.UTF8Encoding($false)

function Fail($msg) { Write-Error "init: $msg"; exit 1 }
function ReadText($p) { [System.IO.File]::ReadAllText($p, $Utf8) }
function WriteText($p, $t) { [System.IO.File]::WriteAllText($p, $t, $Utf8) }
function RelPath($p) { $p.Substring($Root.Length + 1).Replace('\', '/') }

if (-not $Name) { Fail '-Name is required' }
if (-not (Test-Path $Mods)) { Fail 'modules/ not found: this repo is already initialized' }

$profiles = ReadText (Join-Path $Mods 'profiles.json') | ConvertFrom-Json
if ($profiles.PSObject.Properties.Name -notcontains $Profile) { Fail "unknown profile: $Profile" }

$resolved = New-Object System.Collections.ArrayList
$visiting = New-Object System.Collections.ArrayList
function Add-Module($m) {
  $meta = Join-Path $Mods "$m/module.json"
  if (-not (Test-Path $meta)) { Fail "unknown module: $m" }
  if ($resolved -contains $m) { return }
  if ($visiting -contains $m) { Fail "dependency cycle at module: $m" }
  [void]$visiting.Add($m)
  foreach ($dep in @((ReadText $meta | ConvertFrom-Json).requires)) {
    if ($dep) { Add-Module $dep }
  }
  [void]$resolved.Add($m)
}

$wanted = @($profiles.$Profile) + @($Modules | ForEach-Object { $_ -split ',' })
foreach ($m in $wanted) { if ($m) { Add-Module $m } }

Write-Output "Project: $Name"
Write-Output "Profile: $Profile"
if ($resolved.Count -gt 0) { Write-Output ("Modules: " + ($resolved -join ' ')) } else { Write-Output 'Modules: (none)' }
if ($DryRun) { Write-Output '(dry run: nothing is changed)' }

foreach ($m in $resolved) {
  $src = Join-Path $Mods "$m/files"
  if (-not (Test-Path $src)) { continue }
  Write-Output "[$m]"
  $srcFull = (Resolve-Path $src).Path
  $files = Get-ChildItem -Path $srcFull -Recurse -File -Force |
    ForEach-Object { $_.FullName.Substring($srcFull.Length + 1).Replace('\', '/') } | Sort-Object
  foreach ($f in $files) {
    $dest = Join-Path $Root $f
    if (Test-Path $dest) {
      Write-Output "  skip (exists): $f"
    } else {
      Write-Output "  add: $f"
      if (-not $DryRun) {
        New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
        Copy-Item -Path (Join-Path $srcFull $f) -Destination $dest
      }
    }
  }
}

# Insert module snippets at the markers in AGENTS.md and remove the markers.
$agents = Join-Path $Root 'AGENTS.md'
if ((-not $DryRun) -and (Test-Path $agents)) {
  $map = ''
  $rules = ''
  foreach ($m in $resolved) {
    foreach ($kind in 'map', 'rules') {
      $p = Join-Path $Mods "$m/AGENTS.$kind.md"
      if ((Test-Path $p) -and ((Get-Item $p).Length -gt 0)) {
        $t = ReadText $p
        if (-not $t.EndsWith("`n")) { $t += "`n" }
        if ($kind -eq 'map') { $map += $t } else { $rules += $t }
      }
    }
  }
  $text = ReadText $agents
  $text = [regex]::Replace($text, '(?m)^<!-- modules:map -->\r?\n', { param($x) $map })
  $text = [regex]::Replace($text, '(?m)^<!-- modules:rules -->\r?\n', { param($x) $rules })
  WriteText $agents $text
}

# Strip the template-only blocks from README.md and AGENTS.md.
foreach ($doc in @('README.md', 'AGENTS.md')) {
  $path = Join-Path $Root $doc
  if ((-not $DryRun) -and (Test-Path $path)) {
    $t = ReadText $path
    $t = [regex]::Replace($t, '(?s)<!-- template:start -->.*?<!-- template:end -->\r?\n', '')
    WriteText $path $t
  }
}

# Fill in placeholders. Unset commands keep their placeholder and are reported below.
function Get-ProjectFiles {
  Get-ChildItem -Path $Root -Recurse -File -Force | Where-Object {
    $rel = RelPath $_.FullName
    -not ($rel -like '.git/*' -or $rel -like 'modules/*' -or $rel -like 'scripts/*')
  }
}
function Replace-Placeholder($key, $value) {
  if (-not $value) { return }
  $token = '{{' + $key + '}}'
  foreach ($f in Get-ProjectFiles) {
    $t = ReadText $f.FullName
    if ($t.Contains($token)) {
      Write-Output "  fill ${token}: $(RelPath $f.FullName)"
      if (-not $DryRun) { WriteText $f.FullName ($t.Replace($token, $value)) }
    }
  }
}
Write-Output '[placeholders]'
Replace-Placeholder 'PROJECT_NAME' $Name
Replace-Placeholder 'INSTALL_CMD' $InstallCmd
Replace-Placeholder 'RUN_CMD' $RunCmd
Replace-Placeholder 'CHECK_CMD' $CheckCmd

if ((-not $DryRun) -and (-not $Keep)) {
  Remove-Item -Recurse -Force $Mods
  Remove-Item -Force (Join-Path $Root 'scripts/init.sh'), (Join-Path $Root 'scripts/init.ps1'), (Join-Path $Root 'TEMPLATE.md') -ErrorAction SilentlyContinue
  Write-Output 'Removed modules/, scripts/init.* and TEMPLATE.md'
}

if (-not $DryRun) {
  $left = Get-ProjectFiles | ForEach-Object {
    [regex]::Matches((ReadText $_.FullName), '\{\{[A-Z_]+\}\}') | ForEach-Object { $_.Value }
  } | Sort-Object -Unique
  if ($left) { Write-Output ("Still to fill in by hand: " + ($left -join ' ') + ' ') }
}
Write-Output 'Done.'
