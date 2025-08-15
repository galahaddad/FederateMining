<# 
  EZ Fed Mine — One‑Click Monero P2Pool Launcher (v3)
  - Fix: robust path detection for ps2exe (no $MyInvocation/PSScriptRoot dependency)
  - First run downloads latest XMRig (msvc-win64), writes config.json, starts miner
  - Console stays open; exit only on ESC after error or after miner exits
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
    } catch {
      Start-Sleep -Seconds 1
    }
  }
}

try {
  # ====== SETTINGS ======
  $Wallet = '48ZRLsh2aiCAzRsCN4pxkAGtPLMUigXJmFaL2vwYKgFnLxCPbeQe2niYTU3DkF4QPAdULbQ8zCTop1MzPB3R81z88WEqjEk'
  $Pool   = 'ralphfederated.duckdns.org:37888'
  $Coin   = 'monero'
  $RigId  = $env:COMPUTERNAME
  # ======================

  # Robust base directory (works in ps2exe)
  $ExePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
  $BaseDir = [System.IO.Path]::GetDirectoryName($ExePath)
  $XmrigDir = Join-Path $BaseDir 'xmrig'
  $XmrigExe = Join-Path $XmrigDir 'xmrig.exe'
  $ZipPath  = Join-Path $XmrigDir 'xmrig.zip'

  $Host.UI.RawUI.WindowTitle = "EZ Fed Mine — P2Pool Mini (Ralph)"
  Log "Starting EZ Fed Mine (v3)"
  Log "Base  : $BaseDir"
  Log "Pool  : $Pool"
  Log "Wallet: $($Wallet.Substring(0,8))... (hidden)"

  function Ensure-Xmrig {
    if (Test-Path $XmrigExe) { Log "XMRig found at $XmrigExe" 'OK'; return }

    Log "XMRig not found. Creating $XmrigDir and downloading latest build..."
    New-Item -ItemType Directory -Force -Path $XmrigDir | Out-Null

    # Query GitHub latest release JSON
    $apiUrl = 'https://api.github.com/repos/xmrig/xmrig/releases/latest'
    Log "Querying $apiUrl"
    $headers = @{ 'User-Agent' = 'PowerShell' }
    $asset = $null
    try {
      $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 30
      $asset   = $release.assets | Where-Object { $_.name -match 'msvc-win64\.zip$' } | Select-Object -First 1
    } catch {
      Log "GitHub API call failed: $($_.Exception.Message)" 'WARN'
    }
    if (-not $asset) {
      Log "Falling back to pinned URL." 'WARN'
      $asset = [pscustomobject]@{
        browser_download_url = 'https://github.com/xmrig/xmrig/releases/latest/download/xmrig-6.21.3-msvc-win64.zip'
        name = 'xmrig-msvc-win64.zip'
      }
    }

    Log "Downloading $($asset.name)..."
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $ZipPath -UseBasicParsing -TimeoutSec 600
    if (-not (Test-Path $ZipPath)) {
      Log "Download failed; archive not found at $ZipPath" 'ERROR'
      throw "XMRig download failed."
    }
    Log "Download complete" 'OK'

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

  # Do setup + launch
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
