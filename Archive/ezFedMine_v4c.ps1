<# 
  EZ Fed Mine — One‑Click Monero P2Pool Launcher (v4c)
  - Forces config.json to contain Ralph's pool as FIRST entry (removes donate pool)
  - Also launches XMRig with explicit -o/-u flags (belt-and-suspenders)
  - Robust GitHub asset discovery (prefers windows-x64, excludes arm64) + retries
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
$OverrideUrl = ''  # e.g. 'https://github.com/xmrig/xmrig/releases/download/v6.24.0/xmrig-6.24.0-windows-x64.zip'
# ======================

# Paths (ps2exe-safe)
$ExePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
$BaseDir = [System.IO.Path]::GetDirectoryName($ExePath)
$XmrigDir = Join-Path $BaseDir 'xmrig'
$XmrigExe = Join-Path $XmrigDir 'xmrig.exe'
$CfgPath  = Join-Path $XmrigDir 'config.json'
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

  $assets = $release.assets
  $names = $assets | ForEach-Object { $_.name }
  Log ("Found assets: " + ($names -join ', ')) 'INFO'

  # Filter to Windows x64, explicitly exclude arm64
  $win64 = $assets | Where-Object { $_.name -match 'windows' -and $_.name -match 'x64' -and $_.name -notmatch 'arm64' -and $_.name -match '\.zip$' }

  $asset = $win64 | Where-Object { $_.name -match 'windows-x64\.zip$' } | Select-Object -First 1
  if (-not $asset) { $asset = $win64 | Where-Object { $_.name -match 'windows-gcc-x64\.zip$' } | Select-Object -First 1 }
  if (-not $asset) { $asset = $win64 | Select-Object -First 1 }

  if (-not $asset) { throw "Could not find a Windows x64 asset in latest release (non-ARM)." }

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
    $url = 'https://github.com/xmrig/xmrig/releases/latest/download/xmrig-windows-x64.zip'
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
    throw "xmrig.exe not found after extraction (AV may have quarantined it)."
  }
  Log "XMRig is ready." 'OK'
}

function Force-Config {
  Log "Ensuring config.json has Ralph's pool as the first entry..."
  $obj = $null
  if (Test-Path $CfgPath) {
    try { $obj = Get-Content $CfgPath -Raw | ConvertFrom-Json } catch { $obj = $null }
  }
  if (-not $obj) { $obj = @{} }

  # Ensure pools array and remove donate pool entries
  if (-not $obj.pools) { $obj.pools = @() }
  $obj.pools = @($obj.pools | Where-Object { $_.url -notmatch 'donate\.v2\.xmrig\.com' })

  # Create our entry
  $mine = [ordered]@{
    "url"       = $Pool
    "user"      = $Wallet
    "coin"      = $Coin
    "rig-id"    = $RigId
    "keepalive" = $true
    "tls"       = $false
  }

  # Prepend our pool (and also remove any existing same-url entry to avoid duplicates)
  $obj.pools = @($mine) + @($obj.pools | Where-Object { $_.url -ne $Pool })

  # Other top-level settings
  $obj.autosave = $true
  $obj."donate-level" = 1
  $obj.cpu = @{
    "enabled"    = $true
    "huge-pages" = $true
    "hw-aes"     = $null
    "priority"   = $null
  }

  ($obj | ConvertTo-Json -Depth 6) | Out-File -FilePath $CfgPath -Encoding ascii -Force
  Log "config.json updated (pool = $Pool)" 'OK'
}

# ---- MAIN ----
try {
  Log "Starting EZ Fed Mine (v4c)"
  Log "Base  : $BaseDir"
  Log "Pool  : $Pool"
  Log "Wallet: $($Wallet.Substring(0,8))... (hidden)"

  Ensure-Xmrig
  Force-Config

  Log "Launching XMRig (same console). To stop mining, press Ctrl+C." 'INFO'
  Set-Location $XmrigDir
  try {
    # CLI flags override any lingering config ambiguity
    & $XmrigExe -o $Pool -u $Wallet --coin $Coin --rig-id $RigId --keepalive --config=config.json
  } catch {
    Log "Launch failed. If the message mentions 'contains a virus or potentially unwanted software', Windows Defender quarantined xmrig.exe." 'ERROR'
    Log "Fix: Windows Security → Virus & threat protection → Protection history → find 'xmrig.exe' → Actions → Allow on device. Then add an exclusion for: $XmrigDir" 'WARN'
    Log 'Or run (as Administrator): Add-MpPreference -ExclusionPath "'"$XmrigDir"'"' 'WARN'
    throw
  }

  Log "XMRig exited with code $LASTEXITCODE" ('WARN')
  Wait-ForEsc "Press ESC to close this window."
}
catch {
  Log $_.Exception.Message 'ERROR'
  Wait-ForEsc "An error occurred. Press ESC to close this window."
}
