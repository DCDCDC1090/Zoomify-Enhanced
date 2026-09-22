<#
  bump-version.ps1 - works out this fork's next version and writes it into gradle.properties.

  Version format:  <upstream version>-<generation>.<revision>       e.g. 3.5.2-2.0

    upstream version changed since your last build -> generation + 1, revision back to 0
    upstream version unchanged                     -> revision + 1

  The upstream version is read from your 'main' branch, which mirrors isXander's main,
  so the generation number can't drift out of step with his releases.

  Run it from the repo root, on your custom branch, after syncing main:
      git fetch upstream; git checkout main; git merge --ff-only upstream/main; git checkout custom/26.3
      .\bump-version.ps1            # writes the new version
      .\bump-version.ps1 -WhatIf    # just shows what it would be

  Works in both forks: Controlify uses mod.version, Zoomify uses modVersion.
#>
param(
    [string]$UpstreamBranch = "main",
    [switch]$WhatIf
)
$ErrorActionPreference = "Stop"

if (-not (Test-Path "gradle.properties")) { throw "Run this from the root of the repo (no gradle.properties here)." }

$lines = Get-Content "gradle.properties"
$key = if ($lines -match '^mod\.version=') { 'mod.version' }
       elseif ($lines -match '^modVersion=') { 'modVersion' }
       else { throw "Couldn't find a version property in gradle.properties." }
$pattern = "^$([regex]::Escape($key))="

$current = ($lines | Where-Object { $_ -match $pattern }) -replace $pattern, ""

$upstreamProps = git show "${UpstreamBranch}:gradle.properties"
if ($LASTEXITCODE) { throw "Couldn't read gradle.properties from '$UpstreamBranch'. Is that branch up to date with upstream?" }
$upstream = ($upstreamProps | Where-Object { $_ -match $pattern }) -replace $pattern, ""

if ($current -match '^(?<up>[0-9][0-9.]*)-(?<gen>\d+)\.(?<rev>\d+)$') {
    $currentUpstream = $Matches.up
    $gen = [int]$Matches.gen
    $rev = [int]$Matches.rev
} else {
    Write-Host "'$current' isn't in <upstream>-<gen>.<rev> form, starting a new sequence." -ForegroundColor Yellow
    $currentUpstream = $null; $gen = 0; $rev = 0
}

if ($currentUpstream -ne $upstream) {
    $gen++; $rev = 0
    $why = "upstream moved from '$currentUpstream' to '$upstream'"
} else {
    $rev++
    $why = "upstream unchanged at '$upstream'"
}
$new = "$upstream-$gen.$rev"

Write-Host ""
Write-Host "  upstream ($UpstreamBranch) : $upstream"
Write-Host "  current                    : $current"
Write-Host "  next                       : $new   ($why)" -ForegroundColor Cyan
Write-Host ""

if ($WhatIf) { Write-Host "-WhatIf given, nothing written."; return }

($lines | ForEach-Object { if ($_ -match $pattern) { "$key=$new" } else { $_ } }) | Set-Content "gradle.properties"
Write-Host "Wrote $key=$new" -ForegroundColor Green
Write-Host "Next: build, test, then commit gradle.properties with your change." -ForegroundColor Green
