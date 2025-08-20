# RewardDashboard.ps1 - Monitoring Dashboard for Reward Sharing System

<#
.SYNOPSIS
    Provides a monitoring dashboard for the mining reward sharing system
.DESCRIPTION
    Displays real-time statistics, mining contributions, and reward distributions.
    Provides web-based dashboard and console reporting capabilities.
.PARAMETER DatabasePath
    Path to the ShareTracker database files
.PARAMETER Port
    Port for web dashboard (if enabled)
.PARAMETER WebMode
    Enable web-based dashboard
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$DatabasePath = ".\ShareTracker\Database",
    
    [Parameter(Mandatory=$false)]
    [int]$Port = 8080,
    
    [Parameter(Mandatory=$false)]
    [switch]$WebMode = $false
)

$ErrorActionPreference = 'Stop'

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

function Get-DatabaseStats {
    $sharesFile = Join-Path $DatabasePath "shares.csv"
    $hashrateFile = Join-Path $DatabasePath "hashrate.csv"
    $sessionFile = Join-Path $DatabasePath "sessions.csv"
    $distributionFile = Join-Path $DatabasePath "reward-distributions.csv"
    
    $stats = @{
        DatabaseExists = (Test-Path $DatabasePath)
        SharesRecords = 0
        HashrateRecords = 0
        SessionRecords = 0
        DistributionRecords = 0
        ActiveMiners = 0
        LastUpdateTime = "Never"
    }
    
    if (Test-Path $sharesFile) {
        $shares = Import-Csv $sharesFile
        $stats.SharesRecords = $shares.Count
        $stats.ActiveMiners = ($shares | Select-Object -ExpandProperty RigId -Unique).Count
        
        if ($shares.Count -gt 0) {
            $stats.LastUpdateTime = ($shares | Sort-Object Timestamp -Descending)[0].Timestamp
        }
    }
    
    if (Test-Path $hashrateFile) {
        $hashrates = Import-Csv $hashrateFile
        $stats.HashrateRecords = $hashrates.Count
    }
    
    if (Test-Path $sessionFile) {
        $sessions = Import-Csv $sessionFile
        $stats.SessionRecords = $sessions.Count
    }
    
    if (Test-Path $distributionFile) {
        $distributions = Import-Csv $distributionFile
        $stats.DistributionRecords = $distributions.Count
    }
    
    return $stats
}

function Get-MiningOverview {
    param([int]$Hours = 24)
    
    $sharesFile = Join-Path $DatabasePath "shares.csv"
    $hashrateFile = Join-Path $DatabasePath "hashrate.csv"
    
    if (-not (Test-Path $sharesFile) -or -not (Test-Path $hashrateFile)) {
        return @()
    }
    
    $cutoffTime = (Get-Date).AddHours(-$Hours)
    
    $recentShares = Import-Csv $sharesFile | Where-Object { 
        [datetime]$_.Timestamp -ge $cutoffTime 
    }
    
    $recentHashrates = Import-Csv $hashrateFile | Where-Object { 
        [datetime]$_.Timestamp -ge $cutoffTime 
    }
    
    $rigIds = ($recentShares | Select-Object -ExpandProperty RigId -Unique) + 
              ($recentHashrates | Select-Object -ExpandProperty RigId -Unique) | 
              Select-Object -Unique
    
    $overview = @()
    
    foreach ($rigId in $rigIds) {
        $rigShares = $recentShares | Where-Object { $_.RigId -eq $rigId }
        $rigHashrates = $recentHashrates | Where-Object { $_.RigId -eq $rigId }
        
        $acceptedShares = ($rigShares | Where-Object { $_.ShareType -eq "accepted" }).Count
        $rejectedShares = ($rigShares | Where-Object { $_.ShareType -eq "rejected" }).Count
        
        $currentHashrate = if ($rigHashrates.Count -gt 0) {
            ($rigHashrates | Sort-Object Timestamp -Descending)[0].Hashrate60s
        } else { 0 }
        
        $avgHashrate = if ($rigHashrates.Count -gt 0) {
            ($rigHashrates | Measure-Object -Property Hashrate60s -Average).Average
        } else { 0 }
        
        $lastSeen = if ($rigShares.Count -gt 0) {
            ($rigShares | Sort-Object Timestamp -Descending)[0].Timestamp
        } elseif ($rigHashrates.Count -gt 0) {
            ($rigHashrates | Sort-Object Timestamp -Descending)[0].Timestamp
        } else {
            "Unknown"
        }
        
        $overview += [PSCustomObject]@{
            RigId = $rigId
            AcceptedShares = $acceptedShares
            RejectedShares = $rejectedShares
            CurrentHashrate = [math]::Round($currentHashrate, 2)
            AverageHashrate = [math]::Round($avgHashrate, 2)
            LastSeen = $lastSeen
            Status = if ([datetime]$lastSeen -gt (Get-Date).AddMinutes(-10)) { "Online" } else { "Offline" }
        }
    }
    
    return $overview
}

function Get-RewardSummary {
    $distributionFile = Join-Path $DatabasePath "reward-distributions.csv"
    
    if (-not (Test-Path $distributionFile)) {
        return @{
            TotalDistributions = 0
            TotalAmount = 0
            PendingCount = 0
            PendingAmount = 0
            SentCount = 0
            SentAmount = 0
        }
    }
    
    $distributions = Import-Csv $distributionFile
    
    $pending = $distributions | Where-Object { $_.Status -eq "Pending" }
    $sent = $distributions | Where-Object { $_.Status -eq "Sent" }
    
    return @{
        TotalDistributions = $distributions.Count
        TotalAmount = [math]::Round(($distributions | Measure-Object -Property RewardAmount -Sum).Sum, 6)
        PendingCount = $pending.Count
        PendingAmount = [math]::Round(($pending | Measure-Object -Property RewardAmount -Sum).Sum, 6)
        SentCount = $sent.Count
        SentAmount = [math]::Round(($sent | Measure-Object -Property RewardAmount -Sum).Sum, 6)
    }
}

function Show-ConsoleDashboard {
    while ($true) {
        Clear-Host
        
        Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║              EZ Fed Mine - Reward Sharing Dashboard           ║" -ForegroundColor Cyan
        Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
        
        # Database stats
        $dbStats = Get-DatabaseStats
        Write-Host "📊 Database Status:" -ForegroundColor Yellow
        Write-Host "   Database Path: $DatabasePath" -ForegroundColor White
        Write-Host "   Database Exists: $($dbStats.DatabaseExists)" -ForegroundColor White
        Write-Host "   Share Records: $($dbStats.SharesRecords)" -ForegroundColor White
        Write-Host "   Hashrate Records: $($dbStats.HashrateRecords)" -ForegroundColor White
        Write-Host "   Active Miners: $($dbStats.ActiveMiners)" -ForegroundColor White
        Write-Host "   Last Update: $($dbStats.LastUpdateTime)" -ForegroundColor White
        Write-Host ""
        
        # Mining overview (last 24 hours)
        $overview = Get-MiningOverview -Hours 24
        Write-Host "⛏️  Mining Overview (Last 24 Hours):" -ForegroundColor Yellow
        
        if ($overview.Count -eq 0) {
            Write-Host "   No mining data available" -ForegroundColor Gray
        } else {
            Write-Host "   " + "RigId".PadRight(15) + "Status".PadRight(10) + "Shares".PadRight(12) + "Hashrate".PadRight(15) + "Last Seen" -ForegroundColor Gray
            Write-Host "   " + ("-" * 65) -ForegroundColor Gray
            
            foreach ($miner in $overview | Sort-Object AcceptedShares -Descending) {
                $statusColor = if ($miner.Status -eq "Online") { "Green" } else { "Red" }
                $shareText = "$($miner.AcceptedShares)/$($miner.RejectedShares)"
                $hashrateText = "$($miner.CurrentHashrate) H/s"
                
                Write-Host "   " -NoNewline
                Write-Host $miner.RigId.PadRight(15) -NoNewline -ForegroundColor White
                Write-Host $miner.Status.PadRight(10) -NoNewline -ForegroundColor $statusColor
                Write-Host $shareText.PadRight(12) -NoNewline -ForegroundColor White
                Write-Host $hashrateText.PadRight(15) -NoNewline -ForegroundColor Cyan
                Write-Host $miner.LastSeen -ForegroundColor Gray
            }
        }
        Write-Host ""
        
        # Reward summary
        $rewardSummary = Get-RewardSummary
        Write-Host "💰 Reward Summary:" -ForegroundColor Yellow
        Write-Host "   Total Distributions: $($rewardSummary.TotalDistributions)" -ForegroundColor White
        Write-Host "   Total Amount: $($rewardSummary.TotalAmount) XMR" -ForegroundColor White
        Write-Host "   Pending: $($rewardSummary.PendingCount) distributions ($($rewardSummary.PendingAmount) XMR)" -ForegroundColor Yellow
        Write-Host "   Sent: $($rewardSummary.SentCount) distributions ($($rewardSummary.SentAmount) XMR)" -ForegroundColor Green
        Write-Host ""
        
        # Real-time stats
        $totalHashrate = ($overview | Measure-Object -Property CurrentHashrate -Sum).Sum
        $totalShares = ($overview | Measure-Object -Property AcceptedShares -Sum).Sum
        
        Write-Host "📈 Current Network Stats:" -ForegroundColor Yellow
        Write-Host "   Total Network Hashrate: $([math]::Round($totalHashrate, 2)) H/s" -ForegroundColor Cyan
        Write-Host "   Total Accepted Shares (24h): $totalShares" -ForegroundColor Green
        Write-Host "   Online Miners: $(($overview | Where-Object { $_.Status -eq 'Online' }).Count)" -ForegroundColor Green
        Write-Host ""
        
        Write-Host "🕒 Last Updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
        Write-Host "Press Ctrl+C to exit | Refreshing in 30 seconds..." -ForegroundColor Gray
        
        Start-Sleep -Seconds 30
    }
}

function Generate-HTMLDashboard {
    $overview = Get-MiningOverview -Hours 24
    $dbStats = Get-DatabaseStats
    $rewardSummary = Get-RewardSummary
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>EZ Fed Mine - Reward Sharing Dashboard</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 0; padding: 20px; background: #1a1a1a; color: #ffffff; }
        .header { text-align: center; margin-bottom: 30px; padding: 20px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 10px; }
        .container { max-width: 1200px; margin: 0 auto; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .card { background: #2d2d2d; padding: 20px; border-radius: 10px; border: 1px solid #444; }
        .card h3 { margin-top: 0; color: #4CAF50; }
        .stat { display: flex; justify-content: space-between; margin: 10px 0; }
        .stat-value { font-weight: bold; color: #00bcd4; }
        .table { width: 100%; border-collapse: collapse; margin-top: 15px; }
        .table th, .table td { padding: 12px; text-align: left; border-bottom: 1px solid #444; }
        .table th { background: #444; color: #4CAF50; }
        .status-online { color: #4CAF50; }
        .status-offline { color: #f44336; }
        .refresh-note { text-align: center; margin-top: 20px; color: #888; }
    </style>
    <script>
        setTimeout(function() { location.reload(); }, 30000);
    </script>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>⛏️ EZ Fed Mine - Reward Sharing Dashboard</h1>
            <p>Monitoring mining contributions and reward distributions</p>
        </div>
        
        <div class="grid">
            <div class="card">
                <h3>📊 Database Status</h3>
                <div class="stat"><span>Active Miners:</span><span class="stat-value">$($dbStats.ActiveMiners)</span></div>
                <div class="stat"><span>Share Records:</span><span class="stat-value">$($dbStats.SharesRecords)</span></div>
                <div class="stat"><span>Hashrate Records:</span><span class="stat-value">$($dbStats.HashrateRecords)</span></div>
                <div class="stat"><span>Last Update:</span><span class="stat-value">$($dbStats.LastUpdateTime)</span></div>
            </div>
            
            <div class="card">
                <h3>💰 Reward Summary</h3>
                <div class="stat"><span>Total Distributions:</span><span class="stat-value">$($rewardSummary.TotalDistributions)</span></div>
                <div class="stat"><span>Total Amount:</span><span class="stat-value">$($rewardSummary.TotalAmount) XMR</span></div>
                <div class="stat"><span>Pending:</span><span class="stat-value">$($rewardSummary.PendingCount) ($($rewardSummary.PendingAmount) XMR)</span></div>
                <div class="stat"><span>Sent:</span><span class="stat-value">$($rewardSummary.SentCount) ($($rewardSummary.SentAmount) XMR)</span></div>
            </div>
            
            <div class="card">
                <h3>📈 Network Stats (24h)</h3>
                <div class="stat"><span>Online Miners:</span><span class="stat-value">$(($overview | Where-Object { $_.Status -eq 'Online' }).Count)</span></div>
                <div class="stat"><span>Total Hashrate:</span><span class="stat-value">$([math]::Round(($overview | Measure-Object -Property CurrentHashrate -Sum).Sum, 2)) H/s</span></div>
                <div class="stat"><span>Total Shares:</span><span class="stat-value">$(($overview | Measure-Object -Property AcceptedShares -Sum).Sum)</span></div>
            </div>
        </div>
        
        <div class="card">
            <h3>⛏️ Mining Overview (Last 24 Hours)</h3>
"@

    if ($overview.Count -eq 0) {
        $html += "<p>No mining data available</p>"
    } else {
        $html += @"
            <table class="table">
                <thead>
                    <tr>
                        <th>Rig ID</th>
                        <th>Status</th>
                        <th>Accepted Shares</th>
                        <th>Rejected Shares</th>
                        <th>Current Hashrate</th>
                        <th>Average Hashrate</th>
                        <th>Last Seen</th>
                    </tr>
                </thead>
                <tbody>
"@
        
        foreach ($miner in $overview | Sort-Object AcceptedShares -Descending) {
            $statusClass = if ($miner.Status -eq "Online") { "status-online" } else { "status-offline" }
            
            $html += @"
                    <tr>
                        <td>$($miner.RigId)</td>
                        <td class="$statusClass">$($miner.Status)</td>
                        <td>$($miner.AcceptedShares)</td>
                        <td>$($miner.RejectedShares)</td>
                        <td>$($miner.CurrentHashrate) H/s</td>
                        <td>$($miner.AverageHashrate) H/s</td>
                        <td>$($miner.LastSeen)</td>
                    </tr>
"@
        }
        
        $html += @"
                </tbody>
            </table>
"@
    }
    
    $html += @"
        </div>
        
        <div class="refresh-note">
            📄 Last Updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Auto-refresh in 30 seconds
        </div>
    </div>
</body>
</html>
"@
    
    return $html
}

function Start-WebDashboard {
    param([int]$Port)
    
    Write-Log "Starting web dashboard on port $Port" "INFO"
    Write-Log "Access the dashboard at: http://localhost:$Port" "SUCCESS"
    
    # Simple HTTP server implementation
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://localhost:$Port/")
    
    try {
        $listener.Start()
        Write-Log "Web dashboard started successfully" "SUCCESS"
        
        while ($listener.IsListening) {
            $context = $listener.GetContext()
            $response = $context.Response
            
            try {
                $html = Generate-HTMLDashboard
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
                
                $response.ContentType = "text/html; charset=utf-8"
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
                $response.OutputStream.Close()
                
                Write-Log "Served dashboard to $($context.Request.RemoteEndPoint)" "INFO"
            } catch {
                Write-Log "Error serving request: $($_.Exception.Message)" "ERROR"
                $response.StatusCode = 500
                $response.OutputStream.Close()
            }
        }
    } catch {
        Write-Log "Error starting web server: $($_.Exception.Message)" "ERROR"
    } finally {
        if ($listener.IsListening) {
            $listener.Stop()
        }
    }
}

# Main execution
try {
    Write-Log "Starting Reward Sharing Dashboard" "INFO"
    Write-Log "Database Path: $DatabasePath"
    
    if (-not (Test-Path $DatabasePath)) {
        Write-Log "Database directory not found: $DatabasePath" "WARN"
        Write-Log "Run ShareTracker.ps1 first to initialize the database" "INFO"
    }
    
    if ($WebMode) {
        Start-WebDashboard -Port $Port
    } else {
        Show-ConsoleDashboard
    }
    
} catch {
    Write-Log "Error: $($_.Exception.Message)" "ERROR"
    exit 1
}