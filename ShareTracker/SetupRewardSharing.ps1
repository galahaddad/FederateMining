# SetupRewardSharing.ps1 - Setup script for the reward sharing system

<#
.SYNOPSIS
    Sets up the reward sharing system for EZ Fed Mine
.DESCRIPTION
    Configures the tracking and distribution system for mining rewards.
    Creates necessary files, databases, and configuration.
.PARAMETER InstallPath
    Path where the reward sharing system will be installed
.PARAMETER AutoStart
    Automatically start tracking after setup
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$InstallPath = ".\ShareTracker",
    
    [Parameter(Mandatory=$false)]
    [switch]$AutoStart = $false
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

function Test-Prerequisites {
    Write-Log "Checking prerequisites..." "INFO"
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Log "PowerShell 5.0 or higher required. Current version: $($PSVersionTable.PSVersion)" "ERROR"
        return $false
    }
    
    # Check if running as Administrator (recommended)
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if (-not $isAdmin) {
        Write-Log "Not running as Administrator. Some features may be limited." "WARN"
    }
    
    Write-Log "Prerequisites check completed" "SUCCESS"
    return $true
}

function Create-DirectoryStructure {
    Write-Log "Creating directory structure..." "INFO"
    
    $directories = @(
        $InstallPath,
        (Join-Path $InstallPath "Database"),
        (Join-Path $InstallPath "Logs"),
        (Join-Path $InstallPath "Config"),
        (Join-Path $InstallPath "Scripts")
    )
    
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Log "Created directory: $dir" "SUCCESS"
        } else {
            Write-Log "Directory already exists: $dir" "INFO"
        }
    }
}

function Create-ConfigurationFiles {
    Write-Log "Creating configuration files..." "INFO"
    
    # Main configuration file
    $configPath = Join-Path $InstallPath "Config\reward-config.json"
    
    $defaultConfig = @{
        # Ralph's wallet settings (to be configured manually)
        MainWallet = @{
            Address = "48ZRLsh2aiCAzRsCN4pxkAGtPLMUigXJmFaL2vwYKgFnLxCPbeQe2niYTU3DkF4QPAdULbQ8zCTop1MzPB3R81z88WEqjEk"
            Password = ""  # MUST be set manually for security
            FileName = "ralph_wallet"
            RpcPort = 18082
        }
        
        # Distribution settings
        Distribution = @{
            OwnerSharePercent = 10      # Ralph keeps 10% as operator fee
            MinimumPayout = 0.001       # Minimum XMR amount to payout (0.001 XMR)
            DistributionPeriodHours = 24 # Calculate distributions every 24 hours
            RequiredConfirmations = 10   # Wait for 10 confirmations before distributing
            AutoDistribute = $false      # Manual approval required by default
        }
        
        # Hashpower calculation settings
        Calculation = @{
            WeightShareCount = 0.6      # 60% weight for share count
            WeightHashrate = 0.4        # 40% weight for average hashrate
            MinimumSessionHours = 2     # Minimum 2 hours mining to qualify for rewards
            DifficultyWeight = $true    # Consider share difficulty in calculations
        }
        
        # Tracking settings
        Tracking = @{
            LogRotationDays = 30        # Keep logs for 30 days
            DatabaseBackupDays = 90     # Keep database backups for 90 days
            UpdateIntervalSeconds = 60  # Update stats every 60 seconds
        }
        
        # Dashboard settings
        Dashboard = @{
            WebPort = 8080
            RefreshIntervalSeconds = 30
            EnableWeb = $false          # Web dashboard disabled by default
        }
    }
    
    if (-not (Test-Path $configPath)) {
        $defaultConfig | ConvertTo-Json -Depth 4 | Out-File -FilePath $configPath -Encoding UTF8
        Write-Log "Created configuration file: $configPath" "SUCCESS"
    } else {
        Write-Log "Configuration file already exists: $configPath" "INFO"
    }
    
    # Miner wallet registration template
    $walletRegPath = Join-Path $InstallPath "Database\miner-wallets.csv"
    if (-not (Test-Path $walletRegPath)) {
        $walletHeader = "RigId,WalletAddress,RegistrationDate,Status,Notes"
        $walletHeader | Out-File -FilePath $walletRegPath -Encoding UTF8
        
        # Add example entry
        $exampleEntry = "EXAMPLE-PC,4EXAMPLE123...,$(Get-Date -Format 'yyyy-MM-dd'),Active,Example miner registration"
        $exampleEntry | Add-Content -Path $walletRegPath -Encoding UTF8
        
        Write-Log "Created miner wallet registration file: $walletRegPath" "SUCCESS"
    }
    
    # Tracking schedule template
    $schedulePath = Join-Path $InstallPath "Config\tracking-schedule.json"
    $scheduleConfig = @{
        ShareTracking = @{
            Enabled = $true
            LogFile = ".\xmrig\xmrig.log"
            UpdateInterval = 5  # seconds
        }
        RewardCalculation = @{
            Enabled = $true
            Schedule = "Daily"  # Daily, Weekly, Manual
            Time = "02:00"      # 2 AM daily
        }
        Dashboard = @{
            AutoStart = $false
            ConsoleMode = $true
        }
    }
    
    if (-not (Test-Path $schedulePath)) {
        $scheduleConfig | ConvertTo-Json -Depth 3 | Out-File -FilePath $schedulePath -Encoding UTF8
        Write-Log "Created tracking schedule file: $schedulePath" "SUCCESS"
    }
}

function Create-LauncherScripts {
    Write-Log "Creating launcher scripts..." "INFO"
    
    # Start tracking script
    $startTrackingPath = Join-Path $InstallPath "Scripts\start-tracking.ps1"
    $startTrackingScript = @"
# Start Mining Share Tracking
param([string]`$RigId = `$env:COMPUTERNAME)

Write-Host "Starting share tracking for rig: `$RigId" -ForegroundColor Green

`$scriptPath = Split-Path `$MyInvocation.MyCommand.Path
`$parentPath = Split-Path `$scriptPath
`$trackerScript = Join-Path `$parentPath "ShareTracker.ps1"

if (Test-Path `$trackerScript) {
    & `$trackerScript -RigId `$RigId -DatabasePath "`$parentPath\Database"
} else {
    Write-Error "ShareTracker.ps1 not found at: `$trackerScript"
}
"@
    
    $startTrackingScript | Out-File -FilePath $startTrackingPath -Encoding UTF8
    Write-Log "Created start tracking script: $startTrackingPath" "SUCCESS"
    
    # Calculate rewards script
    $calculateRewardsPath = Join-Path $InstallPath "Scripts\calculate-rewards.ps1"
    $calculateRewardsScript = @"
# Calculate and Display Reward Distribution
Write-Host "Calculating reward distribution..." -ForegroundColor Green

`$scriptPath = Split-Path `$MyInvocation.MyCommand.Path
`$parentPath = Split-Path `$scriptPath
`$distributorScript = Join-Path `$parentPath "RewardDistributor.ps1"

if (Test-Path `$distributorScript) {
    & `$distributorScript -DatabasePath "`$parentPath\Database" -ConfigPath "`$parentPath\Config\reward-config.json"
} else {
    Write-Error "RewardDistributor.ps1 not found at: `$distributorScript"
}
"@
    
    $calculateRewardsScript | Out-File -FilePath $calculateRewardsPath -Encoding UTF8
    Write-Log "Created calculate rewards script: $calculateRewardsPath" "SUCCESS"
    
    # Dashboard script
    $dashboardPath = Join-Path $InstallPath "Scripts\show-dashboard.ps1"
    $dashboardScript = @"
# Show Mining Dashboard
param([switch]`$Web = `$false, [int]`$Port = 8080)

`$scriptPath = Split-Path `$MyInvocation.MyCommand.Path
`$parentPath = Split-Path `$scriptPath
`$dashboardScript = Join-Path `$parentPath "RewardDashboard.ps1"

if (Test-Path `$dashboardScript) {
    if (`$Web) {
        Write-Host "Starting web dashboard on port `$Port..." -ForegroundColor Green
        & `$dashboardScript -DatabasePath "`$parentPath\Database" -WebMode -Port `$Port
    } else {
        Write-Host "Starting console dashboard..." -ForegroundColor Green
        & `$dashboardScript -DatabasePath "`$parentPath\Database"
    }
} else {
    Write-Error "RewardDashboard.ps1 not found at: `$dashboardScript"
}
"@
    
    $dashboardScript | Out-File -FilePath $dashboardPath -Encoding UTF8
    Write-Log "Created dashboard script: $dashboardPath" "SUCCESS"
}

function Create-ReadmeFile {
    Write-Log "Creating documentation..." "INFO"
    
    $readmePath = Join-Path $InstallPath "README-RewardSharing.md"
    $readmeContent = @"
# EZ Fed Mine - Reward Sharing System

This system tracks mining contributions and enables fair distribution of block rewards based on hashpower contributions.

## Components

### 1. ShareTracker.ps1
Monitors XMRig logs and tracks:
- Accepted/rejected shares per miner
- Hashrate contributions over time
- Mining session durations
- Pool connections and status

### 2. RewardDistributor.ps1
Calculates reward distributions based on:
- Proportional share contributions (60% weight)
- Average hashrate contributions (40% weight)
- Minimum session requirements
- Configurable operator fee

### 3. MoneroRewardSender.ps1
Handles actual Monero transactions:
- Integrates with Monero wallet CLI/RPC
- Sends payments to registered miners
- Tracks transaction status and confirmations

### 4. RewardDashboard.ps1
Provides monitoring and reporting:
- Real-time mining statistics
- Contribution summaries
- Reward distribution history
- Web-based dashboard option

## Quick Start

### 1. Initial Setup
Run the setup script to create all necessary files and directories:
```powershell
.\SetupRewardSharing.ps1
```

### 2. Configure Miner Wallets
Edit `Database\miner-wallets.csv` to register miner wallet addresses:
```csv
RigId,WalletAddress,RegistrationDate,Status,Notes
MINER-PC,4ABC123...,2025-01-20,Active,John's mining rig
```

### 3. Configure Reward Settings
Edit `Config\reward-config.json` to adjust:
- Operator fee percentage
- Minimum payout amounts
- Distribution schedule
- Wallet connection settings

### 4. Start Tracking
Begin tracking mining contributions:
```powershell
.\Scripts\start-tracking.ps1
```

### 5. Monitor Progress
View real-time dashboard:
```powershell
.\Scripts\show-dashboard.ps1
```

For web dashboard:
```powershell
.\Scripts\show-dashboard.ps1 -Web -Port 8080
```

### 6. Calculate Rewards
Generate reward distribution calculations:
```powershell
.\Scripts\calculate-rewards.ps1
```

### 7. Send Payments (Manual)
After reviewing calculations, send actual payments:
```powershell
.\MoneroRewardSender.ps1
```

## Configuration Files

### reward-config.json
Main configuration file with:
- Wallet connection settings
- Distribution parameters
- Calculation weights
- Security settings

### miner-wallets.csv
Registry of miner wallet addresses for reward distribution.

### tracking-schedule.json
Automation and scheduling settings for tracking and calculations.

## Database Files

All tracking data is stored in CSV format in the `Database` folder:
- `shares.csv` - Share submissions by miner
- `hashrate.csv` - Hashrate measurements over time
- `sessions.csv` - Mining session events
- `reward-distributions.csv` - Calculated and sent rewards

## Security Notes

1. **Wallet Password**: Never commit wallet passwords to version control
2. **Private Keys**: Keep wallet files secure and backed up
3. **Network Access**: Consider firewall rules for web dashboard
4. **Data Backup**: Regularly backup the Database folder

## Support

For issues or questions:
1. Check the log files in the `Logs` folder
2. Verify configuration in `Config` files
3. Review database contents for tracking accuracy
4. Contact the system administrator

---

**Version**: 1.0
**Created**: $(Get-Date -Format 'yyyy-MM-dd')
**Author**: EZ Fed Mine Reward Sharing System
"@
    
    $readmeContent | Out-File -FilePath $readmePath -Encoding UTF8
    Write-Log "Created documentation: $readmePath" "SUCCESS"
}

function Show-SetupSummary {
    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host "REWARD SHARING SYSTEM SETUP COMPLETE" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Cyan
    
    Write-Host "`n📁 Installation Directory:" -ForegroundColor Yellow
    Write-Host "   $InstallPath" -ForegroundColor White
    
    Write-Host "`n📋 Next Steps:" -ForegroundColor Yellow
    Write-Host "   1. Edit Config\reward-config.json to set your wallet password" -ForegroundColor White
    Write-Host "   2. Register miner wallets in Database\miner-wallets.csv" -ForegroundColor White
    Write-Host "   3. Start tracking: .\Scripts\start-tracking.ps1" -ForegroundColor White
    Write-Host "   4. Monitor dashboard: .\Scripts\show-dashboard.ps1" -ForegroundColor White
    
    Write-Host "`n🔧 Configuration Files:" -ForegroundColor Yellow
    Write-Host "   • Config\reward-config.json (main settings)" -ForegroundColor White
    Write-Host "   • Database\miner-wallets.csv (wallet registry)" -ForegroundColor White
    Write-Host "   • Config\tracking-schedule.json (automation)" -ForegroundColor White
    
    Write-Host "`n📊 Management Scripts:" -ForegroundColor Yellow
    Write-Host "   • Scripts\start-tracking.ps1 (begin tracking)" -ForegroundColor White
    Write-Host "   • Scripts\calculate-rewards.ps1 (reward calculation)" -ForegroundColor White
    Write-Host "   • Scripts\show-dashboard.ps1 (monitoring)" -ForegroundColor White
    
    Write-Host "`n📖 Documentation:" -ForegroundColor Yellow
    Write-Host "   • README-RewardSharing.md (complete guide)" -ForegroundColor White
    
    if ($AutoStart) {
        Write-Host "`n🚀 Auto-starting tracking system..." -ForegroundColor Green
        $startScript = Join-Path $InstallPath "Scripts\start-tracking.ps1"
        if (Test-Path $startScript) {
            & $startScript
        }
    }
    
    Write-Host "`n✅ Setup completed successfully!" -ForegroundColor Green
    Write-Host "="*60 -ForegroundColor Cyan
}

# Main execution
try {
    Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║            EZ Fed Mine - Reward Sharing Setup                ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Log "Starting reward sharing system setup..." "INFO"
    Write-Log "Installation path: $InstallPath"
    
    # Run setup steps
    if (-not (Test-Prerequisites)) {
        Write-Log "Prerequisites check failed" "ERROR"
        exit 1
    }
    
    Create-DirectoryStructure
    Create-ConfigurationFiles
    Create-LauncherScripts
    Create-ReadmeFile
    
    Show-SetupSummary
    
} catch {
    Write-Log "Setup failed: $($_.Exception.Message)" "ERROR"
    exit 1
}