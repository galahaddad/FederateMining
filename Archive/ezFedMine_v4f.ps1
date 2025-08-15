<# 
  EZ Fed Mine — One‑Click Monero P2Pool Launcher (v4f)
  - DNS self-heal (Admin): sets public DNS (Cloudflare) if DuckDNS resolution fails, then retries
  - Wrapper resilience: pools ordered LAN -> DuckDNS -> WAN; explicit CLI args + config.json
  - Robust XMRig download (Windows x64, excludes ARM64) with retries
  - Console persists; press ESC to exit after errors or miner exit
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
$Wallet       = '48ZRLsh2aiCAzRsCN4pxkAGtPLMUigXJmFaL2vwYKgFnLxCPbeQe2niYTU3DkF4QPAdULbQ8zCTop1MzPB3R81z88WEqjEk'
$DuckDomain   = 'ralphfederated.duckdns.org'
$Port         = 37888
$LanIPv4      = '192.168.4.23'     # Your P2Pool host on LAN
$FallbackIPv4 = '172.92.188.136'   # Last-known WAN IP
$Coin         = 'monero'
$RigId        = $env:COMPUTERNAME

# DNS self-heal options
$DnsFixEnabled = $true
$DnsServers    = @('1.1.1.1','1.0.0.1')  # Cloudflare (you can switch to 8.8.8.8/8.8.4.4)

# Optional pinned XMRig URL (skip API)
$OverrideUrl  = ''  # e.g. 'https://github.com/xmrig/xmrig/releases/download/v6.24.0/xmrig-6.24.0-windows-x64.zip'
# ======================

# Paths (ps2exe-safe)
$ExePath   = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
$BaseDir   = [System.IO.Path]::GetDirectoryName($ExePath)
$XmrigDir  = Join-Path $BaseDir 'xmrig'
$XmrigExe  = Join-Path $XmrigDir 'xmrig.exe'
$CfgPath   = Join-Path $XmrigDir 'config.json'
$ZipPath   = Join-Path $XmrigDir 'xmrig.zip'

$Host.UI.RawUI.WindowTitle = "EZ Fed Mine — P2Pool Mini (Ralph)"

function Test-IsAdmin {
  try {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  } catch { return $false }
}

function Resolve-NameIPv4([string]$name) {
  try {
    # Prefer PowerShell built-in if available
    $r = Resolve-DnsName -Name $name -ErrorAction Stop | Where-Object { $_.Type -eq 'A' }
    if ($r) { return ,($r | Select-Object -ExpandProperty IPAddress) }
  } catch {
    # Fallback to .NET
    try {
      $ips = [System.Net.Dns]::GetHostAddresses($name) | Where-Object { $_.AddressFamily -eq 'InterNetwork' }
      if ($ips) { return ,($ips.IPAddressToString) }
    } catch { }
  }
  return @()
}

function Ensure-DnsHealthy {
  $ips = Resolve-NameIPv4 $DuckDomain
  if ($ips -and $ips.Count -gt 0) {
    Log "DNS OK: $DuckDomain -> $($ips -join ', ')" 'OK'
    return $true
  }

  Log "DNS lookup failed for $DuckDomain" 'WARN'

  if (-not $DnsFixEnabled) { return $false }

  $isAdmin = Test-IsAdmin
  if (-not $isAdmin) {
    Log "Cannot auto-fix DNS without Administrator rights." 'WARN'
    Log "To fix manually (PowerShell as Admin):" 'INFO'
    Log "  Get-NetAdapter | ? Status -eq Up | ft Name, InterfaceIndex, Status" 'INFO'
    Log "  Set-DnsClientServerAddress -InterfaceIndex <N> -ServerAddresses $($DnsServers -join ',')" 'INFO'
    Log "  ipconfig /flushdns" 'INFO'
    return $false
  }

  try {
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
    if (-not $adapters) {
      Log "No active network adapters found for DNS change." 'WARN'
      return $false
    }

    foreach ($a in $adapters) {
      Log "Setting DNS on adapter '$($a.Name)' (Index $($a.InterfaceIndex)) to: $($DnsServers -join ', ')" 'INFO'
      Set-DnsClientServerAddress -InterfaceIndex $a.InterfaceIndex -ServerAddresses $DnsServers -ErrorAction Stop
    }
    Log "Flushing DNS cache..." 'INFO'
    ipconfig /flushdns | Out-Null
  } catch {
    Log "DNS change failed: $($_.Exception.Message)" 'ERROR'
    return $false
  }

  # Retry resolution
  $retry = Resolve-NameIPv4 $DuckDomain
  if ($retry -and $retry.Count -gt 0) {
    Log "DNS fixed: $DuckDomain -> $($retry -join ', ')" 'OK'
    return $true
  } else {
    Log "DNS still failing after change." 'WARN'
    return $false
  }
}

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

  try { $url = Get-XmrigAssetUrl } catch {
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

function Build-PoolList {
  $lan    = "$LanIPv4:$Port"
  $duck   = "$DuckDomain:$Port"
  $wan    = "$FallbackIPv4:$Port"
  $list   = @()

  # Prefer LAN if reachable (hairpin-proof)
  try {
    $ok = Test-NetConnection -ComputerName $LanIPv4 -Port $Port -InformationLevel Quiet
    if ($ok) { $list += $lan; Log "LAN reachable: $lan" 'OK' }
    else { Log "LAN not reachable: $lan" 'WARN' }
  } catch { Log "LAN test error: $($_.Exception.Message)" 'WARN' }

  # Add DuckDNS if it resolves
  $ips = Resolve-NameIPv4 $DuckDomain
  if ($ips -and $ips.Count -gt 0) {
    $list += $duck
    Log "DNS OK: $DuckDomain -> $($ips -join ', ')" 'OK'
  } else {
    Log "DNS returned no IPv4 for $DuckDomain" 'WARN'
  }

  # Always include WAN fallback last
  $list += $wan

  # Deduplicate while preserving order
  $seen = @{}
  $ordered = @()
  foreach ($p in $list) {
    if (-not $seen.ContainsKey($p)) {
      $seen[$p] = $true
      $ordered += $p
    }
  }
  return ,$ordered
}

function Force-Config {
  $pools = Build-PoolList
  Log "Ensuring config.json pools = $($pools -join ', ')"

  $obj = $null
  if (Test-Path $CfgPath) {
    try { $obj = Get-Content $CfgPath -Raw | ConvertFrom-Json } catch { $obj = $null }
  }
  if (-not $obj) { $obj = @{} }

  if (-not $obj.pools) { $obj.pools = @() }
  # remove donate pool entries
  $obj.pools = @($obj.pools | Where-Object { $_.url -notmatch 'donate\.v2\.xmrig\.com' })

  # Build entries
  $entries = @()
  foreach ($p in $pools) {
    $entries += [ordered]@{
      "url"       = $p
      "user"      = $Wallet
      "coin"      = $Coin
      "rig-id"    = $RigId
      "keepalive" = $true
      "tls"       = $false
    }
  }
  $obj.pools = $entries

  $obj.autosave = $true
  $obj."donate-level" = 1
  $obj.cpu = @{
    "enabled"    = $true
    "huge-pages" = $true
    "hw-aes"     = $null
    "priority"   = $null
  }

  ($obj | ConvertTo-Json -Depth 6) | Out-File -FilePath $CfgPath -Encoding ascii -Force
  Log "config.json updated with pools: $(($obj.pools | ForEach-Object {$_.url}) -join ', ')" 'OK'
}

# ---- MAIN ----
try {
  Log "Starting EZ Fed Mine (v4f)"
  Log "Base  : $BaseDir"
  Log "Pool  : $DuckDomain:$Port (LAN/DNS/WAN fallbacks)"
  Log "Wallet: $($Wallet.Substring(0,8))... (hidden)"

  # DNS self-heal
  $dnsOk = Ensure-DnsHealthy
  if (-not $dnsOk) {
    Log "Proceeding with fallback pool list; DNS may still be flaky." 'WARN'
  }

  Ensure-Xmrig
  Force-Config

  $pools = (Get-Content $CfgPath -Raw | ConvertFrom-Json).pools | ForEach-Object { $_.url }
  $primary = $pools[0]

  Log "Launching XMRig (same console). To stop mining, press Ctrl+C." 'INFO'
  Set-Location $XmrigDir
  try {
    & $XmrigExe -o $primary -u $Wallet --coin $Coin --rig-id $RigId --keepalive --config=config.json
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
