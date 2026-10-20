# Harness check: validates the invariants of this repo layout. It does NOT run the project
# tests; that is the project check in AGENTS.md. Needs only PowerShell 5.1.
# Keep scripts/check.sh in sync with this file.
#
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check.ps1
# Output: one [PASS] / [FAIL] / [SKIP] line per check. A SKIP is not a pass: the check did
# not run, and the reason is printed. Exit code 1 if any check FAILs, otherwise 0.
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $Root

$script:Pass = 0
$script:Fail = 0
$script:Skip = 0
function Pass($m) { $script:Pass++; Write-Output "[PASS] $m" }
function Fail($m) { $script:Fail++; Write-Output "[FAIL] $m" }
function Skip($m) { $script:Skip++; Write-Output "[SKIP] $m" }

# 1. No unresolved placeholders in the files people read first.
if (Test-Path 'modules') {
  Skip 'placeholders: template not initialized (modules/ exists)'
} else {
  $bad = $false
  foreach ($f in 'AGENTS.md', 'README.md', 'CLAUDE.md') {
    if (-not (Test-Path $f)) { continue }
    $found = [regex]::Matches((Get-Content -Raw -Encoding UTF8 $f), '\{\{[A-Z_]+\}\}') |
      ForEach-Object { $_.Value } | Sort-Object -Unique
    if ($found) {
      $bad = $true
      Fail ("placeholders: unresolved in ${f}: " + ($found -join ' ') + ' ')
    }
  }
  if (-not $bad) { Pass 'placeholders: none unresolved' }
}

# 2. Every path in the first column of the repository map (AGENTS.md section 3) exists.
if (-not (Test-Path 'AGENTS.md')) {
  Fail 'repo map: AGENTS.md not found'
} else {
  $paths = @()
  $insec = $false
  foreach ($line in (Get-Content -Encoding UTF8 'AGENTS.md')) {
    if ($line -match '^## ') { $insec = ($line -match '^## 3\. Repository map') }
    if ($insec -and $line -match '^\| `([^`]*)`') { $paths += $Matches[1] }
  }
  if ($paths.Count -eq 0) {
    Skip "repo map: no table found under '## 3. Repository map' in AGENTS.md"
  } else {
    $missing = $false
    foreach ($p in $paths) {
      if (-not (Test-Path $p)) { $missing = $true; Fail "repo map: $p does not exist" }
    }
    if (-not $missing) { Pass "repo map: all $($paths.Count) paths exist" }
  }
}

# 3. Every non-stub schema has a valid and an invalid example next to it.
#    This checks that the examples exist, not that they validate (that needs a validator).
$schemas = @()
if (Test-Path 'schemas') { $schemas = @(Get-ChildItem 'schemas' -Filter '*.schema.json' | Sort-Object Name) }
if ($schemas.Count -gt 0) {
  $miss = $false
  $n = 0
  foreach ($s in $schemas) {
    $name = $s.Name -replace '\.schema\.json$', ''
    if ((Get-Content -Raw -Encoding UTF8 $s.FullName) -cmatch 'TODO') { Skip "schema ${name}: stub (contains TODO)"; continue }
    $n++
    foreach ($k in 'valid', 'invalid') {
      if (-not (Test-Path "schemas/examples/$name.$k.json")) {
        $miss = $true
        Fail "schema ${name}: missing schemas/examples/$name.$k.json"
      }
    }
  }
  if (-not $miss) { Pass "schema examples: $n non-stub schemas have valid and invalid examples" }
} else {
  Skip 'schema examples: no schemas/ directory'
}

Write-Output "Summary: $($script:Pass) pass, $($script:Fail) fail, $($script:Skip) skip"
if ($script:Fail -gt 0) { exit 1 } else { exit 0 }
