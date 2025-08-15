<# 
  EZ Fed Mine — One‑Click Monero P2Pool Launcher (v4a)
  - Fix: PowerShell hashtable syntax (use semicolons, not commas)
  - Robust GitHub asset discovery + retries
  - Console persists; ESC to close after errors or after miner exits
#>

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Log([string]$msg, [string]$lvl='INFO') {
  $prefix = "[{0}] " -f $lvl.ToUpper()
  switch ($lvl.ToUpper()) {
    'OK'    { $c='Green' }
    'WARN'  { $c='Yellow' }
    'ERROR' { $c='Red' }
    default { $c='Cyan' }
  }
  try { Write-Host ($prefix + $msg) -ForegroundColor $c } catch { Write-Host ($prefix + $msg) }
}

function Wait-ForEsc([string]$message = "Press ESC to exit...") {
  Write-Host ""
  Write-Host $message -ForegroundColor DarkGray
  while ($true) {
    try {
      if ([Console]::KeyAvailable) {
        $k = [Console]::ReadKey($true)
        if ($k.Key -eq 'Escape') { break }
      }
      Start-Sleep -Milliseconds 120
    } catch { Start-Sleep -Seconds 1 }
  }
}

# ====== SETTINGS ======
$Wallet = '48ZRLsh2aiCAzRsCN4pxkAGtPLMUigXJmFaL2vwYKgFnLxCPbeQe2niYTU3DkF4QPAdULbQ8zCTop1MzPB3R81z88WEqjEk'
$Pool   = 'ralphfederated.duckdns.org:37888'
$Coin   = 'monero'
$RigId  = $env:COMPUTERNAME
# Optional manual override if GitHub API is blocked:
$OverrideUrl = ''  # e.g. 'https://github.com/xmrig/xmrig/releases/download/v6.22.0/xmrig-6.22.0-msvc-win64.zip'
# ======================

# Paths (ps2exe-safe)
$ExePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
$BaseDir = [System.IO.Path]::GetDirectoryName($ExePath)
$XmrigDir = Join-Path $BaseDir 'xmrig'
$XmrigExe = Join-Path $XmrigDir 'xmrig.exe'
$ZipPath  = Join-Path $XmrigDir 'xmrig.zip'

$Host.UI.RawUI.WindowTitle = "EZ Fed Mine — P2Pool Mini (Ralph)"

function Get-XmrigAssetUrl {
  if ($OverrideUrl -and $OverrideUrl.Trim().Length -gt 0) {
    Log "Using manual override URL." 'WARN'
    return $OverrideUrl
  }

  $apiUrl = 'https://api.github.com/repos/xmrig/xmrig/releases/latest'
  Log "Querying $apiUrl"
  $headers = @{ 'User-Agent' = 'PowerShell' }
  $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 30

  if (-not $release -or -not $release.assets) {
    throw "GitHub API returned no assets."
  }

  # Prefer MSVC win64, fall back to any win64, then any windows zip
  $assets = $release.assets
  $names = $assets | ForEach-Object { $_.name }
  Log ("Found assets: " + ($names -join ', ')) 'INFO'

  $candidates =
    ($assets | Where-Object { $_.name -match 'msvc.*win64\.zip$' }) +
    ($assets | Where-Object { $_.name -match 'msvc-win64\.zip$' }) +
    ($assets | Where-Object { $_.name -match 'win64\.zip$' }) +
    ($assets | Where-Object { $_.name -match 'windows.*zip$' })

  $asset = $candidates | Select-Object -First 1
  if (-not $asset) {
    throw "Could not find a Windows 64-bit asset in latest release."
  }

  Log "Selected asset: $($asset.name)" 'OK'
  return $asset.browser_download_url
}

function Download-WithRetry([string]$url, [string]$outFile, [int]$retries = 3) {
  for ($i=1; $i -le $retries; $i++) {
    try {
      Log "Downloading (attempt $i/$retries): $url"
      Invoke-WebRequest -Uri $url -OutFile $outFile -UseBasicParsing -TimeoutSec 600
      if (Test-Path $outFile) {
        Log "Download complete: $outFile" 'OK'
        return
      }
      throw "File not found after download."
    } catch {
      Log "Download failed: $($_.Exception.Message)" 'WARN'
      if ($i -eq $retries) { throw }
      Start-Sleep -Seconds ([int][Math]::Min(10, 2 * $i))
    }
  }
}

function Ensure-Xmrig {
  if (Test-Path $XmrigExe) { Log "XMRig found at $XmrigExe" 'OK'; return }

  Log "XMRig not found. Creating $XmrigDir and downloading latest build..."
  New-Item -ItemType Directory -Force -Path $XmrigDir | Out-Null

  try {
    $url = Get-XmrigAssetUrl
  } catch {
    Log "Failed to get asset from API: $($_.Exception.Message)" 'WARN'
    # Last-resort pinned pattern: attempt to follow "latest/download" without fixed version
    $url = 'https://github.com/xmrig/xmrig/releases/latest/download/xmrig-msvc-win64.zip'
    Log "Falling back to generic latest/download URL (may fail if asset name differs): $url" 'WARN'
  }

  Download-WithRetry -url $url -outFile $ZipPath

  Log "Extracting..."
  Expand-Archive -Path $ZipPath -DestinationPath $XmrigDir -Force
  Remove-Item $ZipPath -Force
  Log "Extraction complete" 'OK'

  # Move files up if archive created a versioned subfolder
  $sub = Get-ChildItem $XmrigDir -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'xmrig.exe') } | Select-Object -First 1
  if ($sub) {
    Get-ChildItem $sub.FullName -Force | ForEach-Object {
      Move-Item $_.FullName -Destination $XmrigDir -Force
    }
    Remove-Item $sub.FullName -Recurse -Force
  }

  if (-not (Test-Path $XmrigExe)) {
    throw "xmrig.exe not found after extraction."
  }
  Log "XMRig is ready." 'OK'
}

function Write-Config {
  $cfgPath = Join-Path $XmrigDir 'config.json'
  if (Test-Path $cfgPath) {
    Log "config.json already exists; leaving it as-is." 'OK'
    return
  }
  Log "Writing config.json for P2Pool mini..."
  $cfg = @{
    "autosave"      = $true;
    "cpu"           = @{ "enabled" = $true; "huge-pages" = $true; "hw-aes" = $null; "priority" = $null };
    "donate-level"  = 1;
    "pools"         = @(@{
        "url"      = $Pool;
        "user"     = $Wallet;
        "coin"     = $Coin;
        "rig-id"   = $RigId;
        "keepalive"= $true;
        "tls"      = $false
    })
  } | ConvertTo-Json -Depth 6

  $cfg | Out-File -FilePath $cfgPath -Encoding ascii -Force
  Log "config.json written." 'OK'
}

# ---- MAIN ----
try {
  Log "Starting EZ Fed Mine (v4a)"
  Log "Base  : $BaseDir"
  Log "Pool  : $Pool"
  Log "Wallet: $($Wallet.Substring(0,8))... (hidden)"

  Ensure-Xmrig
  Write-Config

  Log "Launching XMRig (same console). To stop mining, press Ctrl+C." 'INFO'
  Set-Location $XmrigDir
  & $XmrigExe --config=config.json

  Log "XMRig exited with code $LASTEXITCODE" ('WARN')
  Wait-ForEsc "Press ESC to close this window."
}
catch {
  Log $_.Exception.Message 'ERROR'
  Wait-ForEsc "An error occurred. Press ESC to close this window."
}
