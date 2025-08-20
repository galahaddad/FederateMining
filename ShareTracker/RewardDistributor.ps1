# RewardDistributor.ps1 - Block Reward Distribution System for EZ Fed Mine
# This script calculates and distributes Monero rewards based on hashpower contributions

<#
.SYNOPSIS
    Calculates and distributes mining rewards based on proportional hashpower contributions
.DESCRIPTION
    Reads mining contribution data from ShareTracker and distributes rewards proportionally.
    Handles Monero wallet operations for sending rewards to contributors.
.PARAMETER DatabasePath
    Path to the ShareTracker database files
.PARAMETER WalletPath
    Path to the Monero wallet CLI
.PARAMETER ConfigPath
    Path to configuration file with reward distribution settings
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$DatabasePath = ".\ShareTracker\Database",
    
    [Parameter(Mandatory=$false)]
    [string]$WalletPath = ".\monero\monero-wallet-cli.exe",
    
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = ".\ShareTracker\reward-config.json"
)

$ErrorActionPreference = 'Stop'

# Default configuration
$DefaultConfig = @{
    # Ralph's wallet settings
    MainWallet = @{
        Address = "48ZRLsh2aiCAzRsCN4pxkAGtPLMUigXJmFaL2vwYKgFnLxCPbeQe2niYTU3DkF4QPAdULbQ8zCTop1MzPB3R81z88WEqjEk"
        Password = ""  # Set this manually in config file
        FileName = "ralph_wallet"
    }
    
    # Distribution settings
    Distribution = @{
        OwnerSharePercent = 10      # Ralph keeps 10% as operator fee
        MinimumPayout = 0.001       # Minimum XMR amount to payout
        DistributionPeriodHours = 24 # How often to calculate distributions
        RequiredConfirmations = 10   # Blocks to wait before distributing
    }
    
    # Hashpower calculation settings
    Calculation = @{
        WeightShareCount = 0.6      # 60% weight for share count
        WeightHashrate = 0.4        # 40% weight for average hashrate
        MinimumSessionHours = 1     # Minimum mining time to qualify for rewards
    }
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "INFO" { "Cyan" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Initialize-Config {
    if (-not (Test-Path $ConfigPath)) {
        $DefaultConfig | ConvertTo-Json -Depth 3 | Out-File -FilePath $ConfigPath -Encoding UTF8
        Write-Log "Created default configuration file: $ConfigPath" "SUCCESS"
        Write-Log "Please edit the configuration file to set your wallet password and preferences" "WARN"
        return $DefaultConfig
    } else {
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        Write-Log "Loaded configuration from: $ConfigPath"
        return $config
    }
}

function Get-AllMinerStats {
    param(
        [datetime]$StartDate,
        [datetime]$EndDate
    )
    
    $sharesFile = Join-Path $DatabasePath "shares.csv"
    $hashrateFile = Join-Path $DatabasePath "hashrate.csv"
    $sessionFile = Join-Path $DatabasePath "sessions.csv"
    
    if (-not (Test-Path $sharesFile) -or -not (Test-Path $hashrateFile)) {
        Write-Log "Database files not found. Cannot calculate stats." "ERROR"
        return @()
    }
    
    # Load all data
    $allShares = Import-Csv $sharesFile | Where-Object { 
        $timestamp = [datetime]$_.Timestamp
        $timestamp -ge $StartDate -and $timestamp -le $EndDate
    }
    
    $allHashrates = Import-Csv $hashrateFile | Where-Object { 
        $timestamp = [datetime]$_.Timestamp
        $timestamp -ge $StartDate -and $timestamp -le $EndDate
    }
    
    $allSessions = Import-Csv $sessionFile | Where-Object { 
        $timestamp = [datetime]$_.Timestamp
        $timestamp -ge $StartDate -and $timestamp -le $EndDate
    }
    
    # Group by RigId and calculate stats
    $rigIds = ($allShares | Select-Object -ExpandProperty RigId -Unique) + 
              ($allHashrates | Select-Object -ExpandProperty RigId -Unique) | 
              Select-Object -Unique
    
    $minerStats = @()
    
    foreach ($rigId in $rigIds) {
        $rigShares = $allShares | Where-Object { $_.RigId -eq $rigId }
        $rigHashrates = $allHashrates | Where-Object { $_.RigId -eq $rigId }
        $rigSessions = $allSessions | Where-Object { $_.RigId -eq $rigId }
        
        $acceptedShares = ($rigShares | Where-Object { $_.ShareType -eq "accepted" }).Count
        $rejectedShares = ($rigShares | Where-Object { $_.ShareType -eq "rejected" }).Count
        $totalShares = $acceptedShares + $rejectedShares
        
        $avgHashrate = if ($rigHashrates.Count -gt 0) {
            ($rigHashrates | Measure-Object -Property Hashrate60s -Average).Average
        } else { 0 }
        
        # Calculate mining session duration
        $sessionDuration = 0
        $startSessions = $rigSessions | Where-Object { $_.Event -eq "mining_start" }
        $stopSessions = $rigSessions | Where-Object { $_.Event -eq "tracker_stop" }
        
        if ($startSessions.Count -gt 0) {
            $firstSession = ($startSessions | Sort-Object Timestamp)[0]
            $lastSession = if ($stopSessions.Count -gt 0) {
                ($stopSessions | Sort-Object Timestamp)[-1]
            } else {
                [PSCustomObject]@{ Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss") }
            }
            
            $sessionDuration = ([datetime]$lastSession.Timestamp - [datetime]$firstSession.Timestamp).TotalHours
        }
        
        $stats = [PSCustomObject]@{
            RigId = $rigId
            AcceptedShares = $acceptedShares
            RejectedShares = $rejectedShares
            TotalShares = $totalShares
            ShareEfficiency = if ($totalShares -gt 0) { [math]::Round(($acceptedShares / $totalShares) * 100, 2) } else { 0 }
            AverageHashrate = [math]::Round($avgHashrate, 2)
            SessionDurationHours = [math]::Round($sessionDuration, 2)
            ContributionScore = 0  # Will be calculated later
        }
        
        $minerStats += $stats
    }
    
    return $minerStats
}

function Calculate-ContributionScores {
    param(
        [array]$MinerStats,
        [object]$Config
    )
    
    # Filter miners that meet minimum session requirements
    $qualifiedMiners = $MinerStats | Where-Object { 
        $_.SessionDurationHours -ge $Config.Calculation.MinimumSessionHours 
    }
    
    if ($qualifiedMiners.Count -eq 0) {
        Write-Log "No qualified miners found for this period" "WARN"
        return @()
    }
    
    # Calculate totals for normalization
    $totalShares = ($qualifiedMiners | Measure-Object -Property AcceptedShares -Sum).Sum
    $totalHashrate = ($qualifiedMiners | Measure-Object -Property AverageHashrate -Sum).Sum
    
    Write-Log "Total qualified shares: $totalShares, Total hashrate: $totalHashrate H/s"
    
    # Calculate contribution scores
    foreach ($miner in $qualifiedMiners) {
        $shareRatio = if ($totalShares -gt 0) { $miner.AcceptedShares / $totalShares } else { 0 }
        $hashrateRatio = if ($totalHashrate -gt 0) { $miner.AverageHashrate / $totalHashrate } else { 0 }
        
        $contributionScore = ($shareRatio * $Config.Calculation.WeightShareCount) + 
                           ($hashrateRatio * $Config.Calculation.WeightHashrate)
        
        $miner.ContributionScore = [math]::Round($contributionScore, 6)
        
        Write-Log "Miner $($miner.RigId): Shares=$($miner.AcceptedShares), Hashrate=$($miner.AverageHashrate), Score=$($miner.ContributionScore)"
    }
    
    return $qualifiedMiners
}

function Get-WalletBalance {
    param([object]$Config)
    
    # This would integrate with Monero wallet CLI or RPC
    # For now, return a placeholder
    Write-Log "Checking wallet balance..." "INFO"
    
    # Placeholder - in real implementation, this would call monero-wallet-cli
    # or use the wallet RPC to get the actual balance
    return 1.5  # Placeholder balance in XMR
}

function Calculate-RewardDistribution {
    param(
        [array]$QualifiedMiners,
        [double]$AvailableBalance,
        [object]$Config
    )
    
    # Reserve owner's share
    $ownerShare = $AvailableBalance * ($Config.Distribution.OwnerSharePercent / 100)
    $distributionPool = $AvailableBalance - $ownerShare
    
    Write-Log "Available balance: $AvailableBalance XMR"
    Write-Log "Owner share (${$($Config.Distribution.OwnerSharePercent)}%): $ownerShare XMR"
    Write-Log "Distribution pool: $distributionPool XMR"
    
    $rewards = @()
    
    foreach ($miner in $QualifiedMiners) {
        $rewardAmount = $distributionPool * $miner.ContributionScore
        
        if ($rewardAmount -ge $Config.Distribution.MinimumPayout) {
            $reward = [PSCustomObject]@{
                RigId = $miner.RigId
                ContributionScore = $miner.ContributionScore
                RewardAmount = [math]::Round($rewardAmount, 6)
                WalletAddress = ""  # To be set from miner registration
                Status = "Pending"
            }
            $rewards += $reward
        } else {
            Write-Log "Miner $($miner.RigId) reward $rewardAmount XMR below minimum payout threshold" "WARN"
        }
    }
    
    return $rewards
}

function Save-RewardDistribution {
    param(
        [array]$Rewards,
        [datetime]$PeriodStart,
        [datetime]$PeriodEnd
    )
    
    $distributionFile = Join-Path $DatabasePath "reward-distributions.csv"
    
    # Initialize distribution file if it doesn't exist
    if (-not (Test-Path $distributionFile)) {
        $header = "Timestamp,PeriodStart,PeriodEnd,RigId,ContributionScore,RewardAmount,WalletAddress,Status,TransactionId"
        $header | Out-File -FilePath $distributionFile -Encoding UTF8
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    foreach ($reward in $Rewards) {
        $record = "$timestamp,$PeriodStart,$PeriodEnd,$($reward.RigId),$($reward.ContributionScore),$($reward.RewardAmount),$($reward.WalletAddress),$($reward.Status),"
        $record | Add-Content -Path $distributionFile -Encoding UTF8
    }
    
    Write-Log "Saved $($Rewards.Count) reward distributions to database" "SUCCESS"
}

function Show-RewardSummary {
    param(
        [array]$MinerStats,
        [array]$QualifiedMiners,
        [array]$Rewards,
        [datetime]$PeriodStart,
        [datetime]$PeriodEnd
    )
    
    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host "REWARD DISTRIBUTION SUMMARY" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Cyan
    Write-Host "Period: $PeriodStart to $PeriodEnd" -ForegroundColor White
    Write-Host "Total Miners: $($MinerStats.Count)" -ForegroundColor White
    Write-Host "Qualified Miners: $($QualifiedMiners.Count)" -ForegroundColor Green
    Write-Host "Rewards to Distribute: $($Rewards.Count)" -ForegroundColor Green
    
    Write-Host "`nMiner Statistics:" -ForegroundColor Yellow
    Write-Host $("RigId".PadRight(15) + "Shares".PadRight(10) + "Hashrate".PadRight(12) + "Hours".PadRight(8) + "Score".PadRight(10) + "Reward") -ForegroundColor Gray
    Write-Host $("-" * 70) -ForegroundColor Gray
    
    foreach ($miner in $QualifiedMiners) {
        $reward = $Rewards | Where-Object { $_.RigId -eq $miner.RigId }
        $rewardStr = if ($reward) { "$($reward.RewardAmount) XMR" } else { "Below min" }
        
        Write-Host $(
            $miner.RigId.PadRight(15) +
            $miner.AcceptedShares.ToString().PadRight(10) +
            "$($miner.AverageHashrate) H/s".PadRight(12) +
            $miner.SessionDurationHours.ToString().PadRight(8) +
            $miner.ContributionScore.ToString().PadRight(10) +
            $rewardStr
        ) -ForegroundColor White
    }
    
    $totalRewards = ($Rewards | Measure-Object -Property RewardAmount -Sum).Sum
    Write-Host "`nTotal Rewards: $totalRewards XMR" -ForegroundColor Green
    Write-Host "="*60 -ForegroundColor Cyan
}

# Main execution
try {
    Write-Log "Starting Reward Distribution System" "INFO"
    
    # Initialize configuration
    $config = Initialize-Config
    
    # Set calculation period (last 24 hours by default)
    $endDate = Get-Date
    $startDate = $endDate.AddHours(-$config.Distribution.DistributionPeriodHours)
    
    Write-Log "Calculating rewards for period: $startDate to $endDate"
    
    # Get mining statistics for all miners
    $minerStats = Get-AllMinerStats -StartDate $startDate -EndDate $endDate
    
    if ($minerStats.Count -eq 0) {
        Write-Log "No mining data found for the specified period" "WARN"
        exit 0
    }
    
    # Calculate contribution scores
    $qualifiedMiners = Calculate-ContributionScores -MinerStats $minerStats -Config $config
    
    if ($qualifiedMiners.Count -eq 0) {
        Write-Log "No qualified miners for reward distribution" "WARN"
        exit 0
    }
    
    # Get available wallet balance
    $availableBalance = Get-WalletBalance -Config $config
    
    # Calculate reward distribution
    $rewards = Calculate-RewardDistribution -QualifiedMiners $qualifiedMiners -AvailableBalance $availableBalance -Config $config
    
    # Save distribution record
    if ($rewards.Count -gt 0) {
        Save-RewardDistribution -Rewards $rewards -PeriodStart $startDate -PeriodEnd $endDate
    }
    
    # Show summary
    Show-RewardSummary -MinerStats $minerStats -QualifiedMiners $qualifiedMiners -Rewards $rewards -PeriodStart $startDate -PeriodEnd $endDate
    
    Write-Log "Reward calculation completed successfully" "SUCCESS"
    
} catch {
    Write-Log "Error: $($_.Exception.Message)" "ERROR"
    exit 1
}