# CBATH build + deploy script (P1-001).
# Generates a unique build id, stamps it into the assembly, builds, deploys to the game,
# and verifies that deployed bytes identical to the built bytes.
# Usage: pwsh -File build-deploy.ps1 [-GameDir <path>]

param(
    [string]$GameDir = 'E:\SteamLibrary\steamapps\common\Mount & Blade II Bannerlord'
)

$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleId = 'CombatBrainAutonomousTestHarness'
$deployRoot = Join-Path $GameDir "Modules\$moduleId"
$deployBin = Join-Path $deployRoot 'bin\Win64_Shipping_Client'
$outDll = Join-Path $here 'bin\Debug\CombatBrainAutonomousTestHarness.dll'
$stampFile = Join-Path $here 'BuildIdentity.g.cs'

function Get-FileSha256([string]$path) {
    if (-not (Test-Path $path)) { return '<missing>' }
    (Get-FileHash -Path $path -Algorithm SHA256).Hash.ToLowerInvariant()
}

# 1. unique build id
$rnd = -join ((0..7) | ForEach-Object { '{0:x1}' -f (Get-Random -Minimum 0 -Maximum 16) })
$buildId = 'b{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), $rnd
$buildTs = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

Write-Host "=== CBATH build/deploy ==="
Write-Host "build_id     = $buildId"
Write-Host "build_ts     = $buildTs"
Write-Host "game_dir     = $GameDir"

# 2. stamp
$stamp = @"
namespace CombatBrainAutonomousTestHarness
{
    internal static class BuildIdentity
    {
        internal const string ModuleId = "$moduleId";
        internal const string BuildId = "$buildId";
        internal const string BuildTimestamp = "$buildTs";
        internal const string AssemblyVersion = "1.0.0.0";
    }
}
"@
[System.IO.File]::WriteAllText($stampFile, $stamp, (New-Object System.Text.UTF8Encoding $false))
Write-Host "stamp written: $stampFile"

# 3. ensure no game process holds the DLL.
# A just-killed game can linger in the process table with HasExited=true; it no longer
# holds the file, so ignore those.
$procs = Get-Process -Name 'Bannerlord','Bannerlord.Native' -ErrorAction SilentlyContinue |
         Where-Object { -not $_.HasExited }
if ($procs) {
    Write-Host "ERROR: game processes running, refusing to deploy:" -ForegroundColor Red
    $procs | ForEach-Object { Write-Host ("  pid={0} name={1}" -f $_.Id, $_.ProcessName) }
    exit 2
}

# 3b. Bannerlord shows a blocking Safe Mode dialog when safely_exited=0 (i.e. after a
# non-graceful exit). Always reset it to 1 before launching so mods load.
$engineConfig = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Mount and Blade II Bannerlord\Configs\engine_config.txt'
if (Test-Path $engineConfig) {
    $lines = Get-Content $engineConfig
    $lines = $lines | ForEach-Object { if ($_ -match '^safely_exited') { 'safely_exited = 1' } else { $_ } }
    [System.IO.File]::WriteAllLines($engineConfig, $lines)
    Write-Host "safely_exited reset to 1 in: $engineConfig"
} else {
    Write-Host "WARNING: engine_config.txt not found, skipping safely_exited reset"
}

# 4. build. MSBuild's incremental check keys off file timestamps, and the stamped source
# can change faster than that, so wipe the output dir to force a real recompile.
Set-Location $here
foreach ($d in @(Join-Path $here 'bin'), (Join-Path $here 'obj')) {
    if (Test-Path $d) { Remove-Item $d -Recurse -Force }
}
dotnet build (Join-Path $here 'CombatBrainAutonomousTestHarness.csproj') -c Debug --nologo -v:m
if ($LASTEXITCODE -ne 0) {
    Write-Host "BUILD FAILED exit=$LASTEXITCODE" -ForegroundColor Red
    exit 3
}

if (-not (Test-Path $outDll)) {
    Write-Host "BUILD OUTPUT MISSING: $outDll" -ForegroundColor Red
    exit 4
}

# 5. verify the stamp really landed in the compiled DLL (guard against stale output).
# Metadata strings are UTF-16 and may start at an odd byte offset, so search both
# alignments instead of decoding once.
$dllBytes = [System.IO.File]::ReadAllBytes($outDll)
$pat = [System.Text.Encoding]::Unicode.GetBytes($buildId)
$stampFound = $false
for ($i = 0; $i -lt ($dllBytes.Length - $pat.Length); $i++) {
    $ok = $true
    for ($j = 0; $j -lt $pat.Length; $j++) {
        if ($dllBytes[$i + $j] -ne $pat[$j]) { $ok = $false; break }
    }
    if ($ok) { $stampFound = $true; break }
}
if (-not $stampFound) {
    Write-Host "STAMP NOT FOUND IN DLL: expected $buildId" -ForegroundColor Red
    exit 5
}
Write-Host "stamp verified inside compiled DLL"

# 6. deploy
New-Item -ItemType Directory -Force -Path $deployBin | Out-Null
Copy-Item $outDll (Join-Path $deployBin 'CombatBrainAutonomousTestHarness.dll') -Force

# Lib.GAB and Gabp.Runtime are not shipped by the game. Newtonsoft.Json is, so skip it
# to avoid clashing with the version already loaded by Bannerlord.
foreach ($dep in @('Lib.GAB.dll', 'Gabp.Runtime.dll')) {
    $srcDep = Join-Path (Split-Path $outDll -Parent) $dep
    if (Test-Path $srcDep) { Copy-Item $srcDep (Join-Path $deployBin $dep) -Force }
    else { Write-Host "WARNING: dependency $dep not found in build output" -ForegroundColor Yellow }
}

# SubModule.xml
$subModuleXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<Module xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:noNamespaceSchemaLocation="https://raw.githubusercontent.com/BUTR/Bannerlord.XmlSchemas/master/SubModule.xsd">
  <Id value="$moduleId" />
  <Name value="CombatBrain Autonomous Test Harness" />
  <Version value="v1.0.0" />
  <DefaultModule value="false" />
  <ModuleCategory value="Singleplayer" />
  <ModuleType value="Community" />
  <Url value="" />
  <DependedModules>
    <DependedModule Id="Native" />
  </DependedModules>
  <SubModules>
    <SubModule>
      <Name value="$moduleId" />
      <DLLName value="CombatBrainAutonomousTestHarness.dll" />
      <SubModuleClassType value="CombatBrainAutonomousTestHarness.ProbeSubModule" />
      <Tags />
    </SubModule>
  </SubModules>
</Module>
"@
[System.IO.File]::WriteAllText((Join-Path $deployRoot 'SubModule.xml'), $subModuleXml, (New-Object System.Text.UTF8Encoding $false))

# 7. cross-check hashes
$srcHash = Get-FileSha256 $outDll
$dstHash = Get-FileSha256 (Join-Path $deployBin 'CombatBrainAutonomousTestHarness.dll')

Write-Host ""
Write-Host "=== RESULT ==="
Write-Host "build_id          = $buildId"
Write-Host "source_dll        = $outDll"
Write-Host "source_sha256     = $srcHash"
Write-Host "deployed_dll      = $(Join-Path $deployBin 'CombatBrainAutonomousTestHarness.dll')"
Write-Host "deployed_sha256   = $dstHash"

if ($srcHash -ne $dstHash) {
    Write-Host "HASH MISMATCH - ABORT" -ForegroundColor Red
    exit 6
}

Write-Host "DEPLOY OK" -ForegroundColor Green
exit 0
