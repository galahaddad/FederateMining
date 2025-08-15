<# 
  Monero P2Pool One-Click Launcher for Ralph
  - First run: downloads latest XMRig for Windows (msvc-win64), extracts, writes config, launches
  - Next runs: skips setup and launches immediately
  - Node: ralphfederated.duckdns.org:37888
  - Wallet: 48ZRLsh2aiCAzRsCN4pxkAGtPLMUigXJmFaL2vwYKgFnLxCPbeQe2niYTU3DkF4QPAdULbQ8zCTop1MzPB3R81z88WEqjEk
#>

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ------- SETTINGS -------
$Wallet = '48ZRLsh2aiCAzRsCN4pxkAGtPLMUigXJmFaL2vwYKgFnLxCPbeQe2niYTU3DkF4QPAdULbQ8zCTop1MzPB3R81z88WEqjEk'
$Pool   = 'ralphfederated.duckdns.org:37888'
$Coin   = 'monero'
$RigId  = $env:COMPUTERNAME
# ------------------------

$BaseDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$XmrigDir = Join-Path $BaseDir 'xmrig'
$XmrigExe = Join-Path $XmrigDir 'xmrig.exe'
$ZipPath  = Join-Path $XmrigDir 'xmrig.zip'

function Log([string]$msg, [string]$lvl='INFO') {
  $prefix = "[{0}] " -f $lvl.ToUpper()
  switch ($lvl.ToUpper()) {
    'OK'    { $c='Green' }
    'WARN'  { $c='Yellow' }
    'ERROR' { $c='Red' }
    default { $c='Cyan' }
  }
  Write-Host ($prefix + $msg) -ForegroundColor $c
}

function Ensure-Xmrig {
  if (Test-Path $XmrigExe) { Log "XMRig found at $XmrigExe" 'OK'; return }

  Log "XMRig not found. Creating $XmrigDir and downloading latest build..."
  New-Item -ItemType Directory -Force -Path $XmrigDir | Out-Null

  # Get latest release asset via GitHub API
  $apiUrl = 'https://api.github.com/repos/xmrig/xmrig/releases/latest'
  Log "Querying $apiUrl"
  $headers = @{ 'User-Agent' = 'PowerShell' }
  $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 30
  $asset   = $release.assets | Where-Object { $_.name -match 'msvc-win64\.zip$' } | Select-Object -First 1

  if (-not $asset) {
    Log "Could not locate msvc-win64 asset in latest release. Falling back to a pinned URL." 'WARN'
    # Fallback (update if ever broken):
    $asset = [pscustomobject]@{
      browser_download_url = 'https://github.com/xmrig/xmrig/releases/latest/download/xmrig-6.21.3-msvc-win64.zip'
      name = 'xmrig-msvc-win64.zip'
    }
  }

  Log "Downloading $($asset.name)..."
  Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $ZipPath -UseBasicParsing -TimeoutSec 600
  Log "Download complete: $ZipPath" 'OK'

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
    Log "xmrig.exe still not found after extraction." 'ERROR'
    throw "Setup failed."
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
    "autosave"      = $true
    "cpu"           = @{ "enabled" = $true; "huge-pages" = $true; "hw-aes" = $null; "priority" = $null }
    "donate-level"  = 1
    "pools"         = @(@{
        "url"      = $Pool
        "user"     = $Wallet
        "coin"     = $Coin
        "rig-id"   = $RigId
        "keepalive"= $true
        "tls"      = $false
    })
  } | ConvertTo-Json -Depth 6

  $cfg | Out-File -FilePath $cfgPath -Encoding ascii -Force
  Log "config.json written." 'OK'
}

try {
  Log "Starting Ralph's one-click P2Pool miner"
  Log "Wallet: $($Wallet.Substring(0,8))... (hidden)"
  Log "Pool  : $Pool"

  Ensure-Xmrig
  Write-Config

  Log "Launching XMRig..." 'INFO'
  Set-Location $XmrigDir
  # Run in the same console so users see XMRig output
  & $XmrigExe --config=config.json
}
catch {
  Log $_.Exception.Message 'ERROR'
  Read-Host "Press ENTER to exit"
  exit 1
}
