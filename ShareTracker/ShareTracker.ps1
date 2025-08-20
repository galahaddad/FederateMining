# ShareTracker.ps1 - Hashpower and Share Tracking System for EZ Fed Mine
# This script tracks mining contributions from each miner for reward distribution

<#
.SYNOPSIS
    Tracks mining shares and hashpower contributions for reward distribution
.DESCRIPTION
    Monitors XMRig logs and pool data to track each miner's contribution.
    Stores data in CSV files for later reward calculation and distribution.
.PARAMETER RigId
    The unique identifier for this mining rig
.PARAMETER LogPath
    Path to XMRig log file to monitor
.PARAMETER DatabasePath
    Path to store tracking database files
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$RigId = $env:COMPUTERNAME,
    
    [Parameter(Mandatory=$false)]
    [string]$LogPath = ".\xmrig\xmrig.log",
    
    [Parameter(Mandatory=$false)]
    [string]$DatabasePath = ".\ShareTracker\Database"
)

$ErrorActionPreference = 'Stop'

# Ensure database directory exists
if (-not (Test-Path $DatabasePath)) {
    New-Item -ItemType Directory -Path $DatabasePath -Force | Out-Null
    Write-Host "Created database directory: $DatabasePath" -ForegroundColor Green
}

# Database files
$SharesFile = Join-Path $DatabasePath "shares.csv"
$HashrateFile = Join-Path $DatabasePath "hashrate.csv"
$SessionFile = Join-Path $DatabasePath "sessions.csv"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "INFO" { "Cyan" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Initialize-Database {
    # Initialize shares CSV if it doesn't exist
    if (-not (Test-Path $SharesFile)) {
        $sharesHeader = "Timestamp,RigId,ShareType,Difficulty,Hash,Nonce"
        $sharesHeader | Out-File -FilePath $SharesFile -Encoding UTF8
        Write-Log "Initialized shares database: $SharesFile"
    }
    
    # Initialize hashrate CSV if it doesn't exist
    if (-not (Test-Path $HashrateFile)) {
        $hashrateHeader = "Timestamp,RigId,Hashrate10s,Hashrate60s,Hashrate15m,Threads"
        $hashrateHeader | Out-File -FilePath $HashrateFile -Encoding UTF8
        Write-Log "Initialized hashrate database: $HashrateFile"
    }
    
    # Initialize sessions CSV if it doesn't exist
    if (-not (Test-Path $SessionFile)) {
        $sessionHeader = "Timestamp,RigId,Event,SessionId,Pool,Wallet"
        $sessionHeader | Out-File -FilePath $SessionFile -Encoding UTF8
        Write-Log "Initialized session database: $SessionFile"
    }
}

function Record-Share {
    param(
        [string]$ShareType,
        [string]$Difficulty,
        [string]$Hash,
        [string]$Nonce
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $record = "$timestamp,$RigId,$ShareType,$Difficulty,$Hash,$Nonce"
    $record | Add-Content -Path $SharesFile -Encoding UTF8
    Write-Log "Recorded $ShareType share: diff=$Difficulty" "INFO"
}

function Record-Hashrate {
    param(
        [double]$Hashrate10s,
        [double]$Hashrate60s,
        [double]$Hashrate15m,
        [int]$Threads
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $record = "$timestamp,$RigId,$Hashrate10s,$Hashrate60s,$Hashrate15m,$Threads"
    $record | Add-Content -Path $HashrateFile -Encoding UTF8
    Write-Log "Recorded hashrate: 10s=$($Hashrate10s)H/s, 60s=$($Hashrate60s)H/s, 15m=$($Hashrate15m)H/s"
}

function Record-Session {
    param(
        [string]$Event,
        [string]$SessionId = "",
        [string]$Pool = "",
        [string]$Wallet = ""
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $record = "$timestamp,$RigId,$Event,$SessionId,$Pool,$Wallet"
    $record | Add-Content -Path $SessionFile -Encoding UTF8
    Write-Log "Recorded session event: $Event"
}

function Parse-XmrigLog {
    param([string]$LogFile)
    
    if (-not (Test-Path $LogFile)) {
        Write-Log "Log file not found: $LogFile" "WARN"
        return
    }
    
    Write-Log "Monitoring XMRig log: $LogFile"
    
    # Read existing log content to avoid re-processing
    $lastPosition = 0
    if (Test-Path "$DatabasePath\lastposition.txt") {
        $lastPosition = [int](Get-Content "$DatabasePath\lastposition.txt")
    }
    
    # Monitor log file for new entries
    while ($true) {
        if (Test-Path $LogFile) {
            $currentSize = (Get-Item $LogFile).Length
            
            if ($currentSize -gt $lastPosition) {
                $newContent = Get-Content $LogFile -Encoding UTF8 | Select-Object -Skip $([math]::Max(0, $lastPosition / 100))
                
                foreach ($line in $newContent) {
                    # Parse accepted shares
                    if ($line -match 'accepted \((\d+)/(\d+)\) diff (\d+)') {
                        $accepted = $matches[1]
                        $total = $matches[2]
                        $difficulty = $matches[3]
                        Record-Share -ShareType "accepted" -Difficulty $difficulty -Hash "" -Nonce ""
                    }
                    
                    # Parse rejected shares
                    if ($line -match 'rejected \((\d+)/(\d+)\) diff (\d+)') {
                        $rejected = $matches[1]
                        $total = $matches[2]
                        $difficulty = $matches[3]
                        Record-Share -ShareType "rejected" -Difficulty $difficulty -Hash "" -Nonce ""
                    }
                    
                    # Parse hashrate information
                    if ($line -match '10s/60s/15m ([\d.]+) ([\d.]+) ([\d.]+) H/s max ([\d.]+) H/s') {
                        $hashrate10s = [double]$matches[1]
                        $hashrate60s = [double]$matches[2]
                        $hashrate15m = [double]$matches[3]
                        $maxHashrate = [double]$matches[4]
                        Record-Hashrate -Hashrate10s $hashrate10s -Hashrate60s $hashrate60s -Hashrate15m $hashrate15m -Threads 0
                    }
                    
                    # Parse session start
                    if ($line -match 'use pool (.+)') {
                        $pool = $matches[1]
                        Record-Session -Event "pool_connect" -Pool $pool
                    }
                    
                    # Parse mining start
                    if ($line -match 'READY threads (\d+)') {
                        $threads = [int]$matches[1]
                        Record-Session -Event "mining_start" -SessionId (Get-Date -Format "yyyyMMddHHmmss")
                    }
                }
                
                $lastPosition = $currentSize
                $lastPosition | Out-File -FilePath "$DatabasePath\lastposition.txt" -Encoding UTF8
            }
        }
        
        Start-Sleep -Seconds 5
    }
}

function Get-MinerStats {
    param(
        [datetime]$StartDate = (Get-Date).AddHours(-24),
        [datetime]$EndDate = (Get-Date)
    )
    
    if (-not (Test-Path $SharesFile) -or -not (Test-Path $HashrateFile)) {
        Write-Log "Database files not found. No stats available." "WARN"
        return
    }
    
    # Calculate stats for the specified time period
    $shares = Import-Csv $SharesFile | Where-Object { 
        $timestamp = [datetime]$_.Timestamp
        $timestamp -ge $StartDate -and $timestamp -le $EndDate -and $_.RigId -eq $RigId
    }
    
    $hashrates = Import-Csv $HashrateFile | Where-Object { 
        $timestamp = [datetime]$_.Timestamp
        $timestamp -ge $StartDate -and $timestamp -le $EndDate -and $_.RigId -eq $RigId
    }
    
    $acceptedShares = ($shares | Where-Object { $_.ShareType -eq "accepted" }).Count
    $rejectedShares = ($shares | Where-Object { $_.ShareType -eq "rejected" }).Count
    $totalShares = $acceptedShares + $rejectedShares
    
    $avgHashrate = if ($hashrates.Count -gt 0) {
        ($hashrates | Measure-Object -Property Hashrate60s -Average).Average
    } else { 0 }
    
    $stats = [PSCustomObject]@{
        RigId = $RigId
        Period = "$StartDate to $EndDate"
        AcceptedShares = $acceptedShares
        RejectedShares = $rejectedShares
        TotalShares = $totalShares
        ShareEfficiency = if ($totalShares -gt 0) { [math]::Round(($acceptedShares / $totalShares) * 100, 2) } else { 0 }
        AverageHashrate = [math]::Round($avgHashrate, 2)
        ContributionScore = $acceptedShares * $avgHashrate
    }
    
    return $stats
}

# Main execution
try {
    Write-Log "Starting ShareTracker for RigId: $RigId" "INFO"
    Write-Log "Database Path: $DatabasePath"
    Write-Log "Log Path: $LogPath"
    
    Initialize-Database
    
    # Record session start
    Record-Session -Event "tracker_start"
    
    if ($args.Count -gt 0 -and $args[0] -eq "-stats") {
        # Show stats only
        $stats = Get-MinerStats
        Write-Host "`nMining Statistics for $($stats.RigId):" -ForegroundColor Cyan
        Write-Host "Period: $($stats.Period)" -ForegroundColor White
        Write-Host "Accepted Shares: $($stats.AcceptedShares)" -ForegroundColor Green
        Write-Host "Rejected Shares: $($stats.RejectedShares)" -ForegroundColor Red
        Write-Host "Share Efficiency: $($stats.ShareEfficiency)%" -ForegroundColor Yellow
        Write-Host "Average Hashrate: $($stats.AverageHashrate) H/s" -ForegroundColor Cyan
        Write-Host "Contribution Score: $($stats.ContributionScore)" -ForegroundColor Magenta
    } else {
        # Start monitoring
        Parse-XmrigLog -LogFile $LogPath
    }
    
} catch {
    Write-Log "Error: $($_.Exception.Message)" "ERROR"
    exit 1
} finally {
    # Record session end
    Record-Session -Event "tracker_stop"
}