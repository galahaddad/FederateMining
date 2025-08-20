# EZ Fed Mine - Block Reward Sharing System

## Overview

The Block Reward Sharing System enables fair distribution of Monero mining rewards from Ralph's wallet to participating miners based on their hashpower contributions. This system tracks mining statistics, calculates proportional rewards, and handles automated distribution.

## Key Features

### 📊 Comprehensive Tracking
- **Share Monitoring**: Tracks accepted and rejected shares per miner
- **Hashrate Logging**: Records hashrate contributions over time
- **Session Tracking**: Monitors mining duration and connection events
- **Real-time Statistics**: Live dashboard with mining performance data

### 💰 Fair Reward Distribution
- **Proportional Calculation**: Rewards based on 60% share count + 40% hashrate
- **Configurable Parameters**: Adjustable operator fees and minimum payouts
- **Quality Requirements**: Minimum mining time to qualify for rewards
- **Automated Processing**: Scheduled calculations and distribution

### 🔒 Security & Transparency
- **Wallet Integration**: Secure Monero wallet CLI integration
- **Transaction Tracking**: Complete audit trail of all distributions
- **Address Verification**: Registered miner wallet validation
- **Manual Approval**: Optional manual review before payments

## System Components

### Core Scripts

#### 1. ShareTracker.ps1
**Purpose**: Monitors XMRig logs and tracks mining contributions
- Parses XMRig log files for share submissions
- Records hashrate measurements at regular intervals
- Tracks mining session start/stop events
- Stores all data in CSV format for analysis

**Usage**:
```powershell
.\ShareTracker.ps1 -RigId "MINER-PC" -LogPath ".\xmrig\xmrig.log"
```

#### 2. RewardDistributor.ps1
**Purpose**: Calculates proportional reward distributions
- Analyzes mining contributions over specified periods
- Applies configurable weighting for shares vs hashrate
- Calculates operator fees and minimum payout thresholds
- Generates distribution reports for review

**Usage**:
```powershell
.\RewardDistributor.ps1 -DatabasePath ".\Database" -ConfigPath ".\Config\reward-config.json"
```

#### 3. MoneroRewardSender.ps1
**Purpose**: Executes actual Monero transactions for reward payments
- Integrates with Monero wallet CLI/RPC
- Validates recipient wallet addresses
- Creates and broadcasts transactions
- Updates distribution status with transaction IDs

**Usage**:
```powershell
.\MoneroRewardSender.ps1 -DatabasePath ".\Database" -WalletPath ".\monero\monero-wallet-cli.exe"
```

#### 4. RewardDashboard.ps1
**Purpose**: Provides monitoring and reporting interface
- Real-time mining statistics display
- Historical contribution analysis
- Reward distribution summaries
- Web-based dashboard option

**Usage**:
```powershell
# Console dashboard
.\RewardDashboard.ps1 -DatabasePath ".\Database"

# Web dashboard
.\RewardDashboard.ps1 -DatabasePath ".\Database" -WebMode -Port 8080
```

#### 5. SetupRewardSharing.ps1
**Purpose**: Initial system setup and configuration
- Creates directory structure and configuration files
- Generates template files for miner registration
- Sets up launcher scripts and documentation
- Configures default reward distribution parameters

**Usage**:
```powershell
.\SetupRewardSharing.ps1 -InstallPath ".\ShareTracker" -AutoStart
```

### Enhanced Mining Script

#### ezFedMine_v5_RewardSharing.ps1
**Purpose**: Enhanced mining client with integrated tracking
- All existing ezFedMine functionality
- Automatic share tracking activation
- Reward sharing system initialization
- Enhanced logging for contribution tracking

**Features**:
- Backward compatible with existing setup
- Optional tracking (can be disabled)
- Automatic XMRig log configuration
- Real-time tracking status display

## Configuration System

### Primary Configuration (reward-config.json)

```json
{
  "MainWallet": {
    "Address": "48ZRLsh2aiCAzRsCN4pxkAGtPLMUigXJmFaL2vwYKgFnLxCPbeQe2niYTU3DkF4QPAdULbQ8zCTop1MzPB3R81z88WEqjEk",
    "Password": "",
    "FileName": "ralph_wallet",
    "RpcPort": 18082
  },
  "Distribution": {
    "OwnerSharePercent": 10,
    "MinimumPayout": 0.001,
    "DistributionPeriodHours": 24,
    "RequiredConfirmations": 10,
    "AutoDistribute": false
  },
  "Calculation": {
    "WeightShareCount": 0.6,
    "WeightHashrate": 0.4,
    "MinimumSessionHours": 2,
    "DifficultyWeight": true
  }
}
```

### Miner Registration (miner-wallets.csv)

```csv
RigId,WalletAddress,RegistrationDate,Status,Notes
JOHN-PC,4ABC123...,2025-01-20,Active,John's gaming rig
MARY-LAPTOP,4DEF456...,2025-01-20,Active,Mary's laptop
SERVER-01,4GHI789...,2025-01-20,Active,Office server
```

## Data Storage Structure

### Database Files

All tracking data is stored in CSV format for transparency and portability:

#### shares.csv
```csv
Timestamp,RigId,ShareType,Difficulty,Hash,Nonce
2025-01-20 14:30:15,JOHN-PC,accepted,1000,,
2025-01-20 14:30:45,MARY-LAPTOP,accepted,1500,,
2025-01-20 14:31:02,JOHN-PC,rejected,1000,,
```

#### hashrate.csv
```csv
Timestamp,RigId,Hashrate10s,Hashrate60s,Hashrate15m,Threads
2025-01-20 14:30:00,JOHN-PC,1250.5,1200.3,1180.7,8
2025-01-20 14:30:00,MARY-LAPTOP,800.2,785.1,790.4,4
```

#### sessions.csv
```csv
Timestamp,RigId,Event,SessionId,Pool,Wallet
2025-01-20 14:00:00,JOHN-PC,mining_start,20250120140000,ralphfederated.duckdns.org:3333,48ZRL...
2025-01-20 16:00:00,JOHN-PC,tracker_stop,20250120140000,,
```

#### reward-distributions.csv
```csv
Timestamp,PeriodStart,PeriodEnd,RigId,ContributionScore,RewardAmount,WalletAddress,Status,TransactionId
2025-01-20 02:00:00,2025-01-19 02:00:00,2025-01-20 02:00:00,JOHN-PC,0.45,0.0045,4ABC123...,Sent,tx_abc123...
```

## Installation & Setup Guide

### 1. Initial Setup

1. **Download the reward sharing system** to your EZ Fed Mine directory
2. **Run the setup script**:
   ```powershell
   .\ShareTracker\SetupRewardSharing.ps1
   ```
3. **Configure your wallet** in `ShareTracker\Config\reward-config.json`
4. **Register miner wallets** in `ShareTracker\Database\miner-wallets.csv`

### 2. Miner Registration

Each miner who wants to receive rewards must:
1. **Generate a Monero wallet** using the official Monero GUI or CLI
2. **Provide their wallet address** to be added to miner-wallets.csv
3. **Use the enhanced mining script** (ezFedMine_v5_RewardSharing.ps1)
4. **Mine for minimum required time** (default: 2 hours per day)

### 3. Operator Setup (Ralph)

1. **Install Monero CLI tools** in the `monero` directory
2. **Configure wallet connection** in reward-config.json
3. **Set distribution parameters** (fees, minimums, schedule)
4. **Test the system** with small amounts before full deployment

### 4. Running the System

#### For Miners:
```powershell
# Use the enhanced mining script with tracking
.\ezFedMine_v5_RewardSharing.ps1 -EnableTracking
```

#### For Monitoring (Optional):
```powershell
# Console dashboard
.\ShareTracker\Scripts\show-dashboard.ps1

# Web dashboard
.\ShareTracker\Scripts\show-dashboard.ps1 -Web -Port 8080
```

#### For Operators:
```powershell
# Calculate rewards (daily)
.\ShareTracker\Scripts\calculate-rewards.ps1

# Send rewards (after review)
.\ShareTracker\MoneroRewardSender.ps1
```

## Reward Calculation Algorithm

### Contribution Score Formula

For each miner over a distribution period:

```
ContributionScore = (ShareRatio × 0.6) + (HashrateRatio × 0.4)

Where:
- ShareRatio = MinerAcceptedShares / TotalNetworkShares
- HashrateRatio = MinerAverageHashrate / TotalNetworkHashrate
```

### Reward Amount Calculation

```
MinerReward = DistributionPool × MinerContributionScore

Where:
- DistributionPool = AvailableBalance × (1 - OperatorFeePercent)
- OperatorFeePercent = 10% (default, configurable)
```

### Qualification Requirements

- **Minimum session time**: 2 hours within distribution period
- **Minimum payout**: 0.001 XMR (configurable)
- **Active wallet registration**: Valid entry in miner-wallets.csv
- **Valid contribution data**: Tracked shares and hashrate available

## Security Considerations

### Wallet Security
- **Never commit wallet passwords** to version control
- **Use separate mining and reward wallets** for security
- **Enable wallet encryption** and use strong passwords
- **Regular backups** of wallet files and seeds

### Network Security
- **Firewall protection** for web dashboard if enabled
- **VPN access** for remote monitoring (recommended)
- **Regular updates** of system components

### Data Integrity
- **Regular database backups** to prevent data loss
- **Audit trail maintenance** for all transactions
- **Verification mechanisms** for tracking accuracy

## Troubleshooting Guide

### Common Issues

#### 1. Tracking Not Working
**Symptoms**: No data in shares.csv or hashrate.csv
**Solutions**:
- Verify XMRig logging is enabled in config.json
- Check ShareTracker.ps1 is running
- Ensure correct log file path
- Verify database directory permissions

#### 2. Missing Wallet Addresses
**Symptoms**: "Below minimum payout" for all miners
**Solutions**:
- Add wallet addresses to miner-wallets.csv
- Set Status to "Active" for registered miners
- Verify wallet address format (95 characters, starts with '4')

#### 3. Transaction Failures
**Symptoms**: Payments marked as failed
**Solutions**:
- Check Monero wallet connectivity
- Verify sufficient balance for payments + fees
- Ensure wallet is synchronized with network
- Check recipient address validity

#### 4. Dashboard Not Loading
**Symptoms**: Web dashboard shows errors
**Solutions**:
- Verify port availability (default 8080)
- Check Windows Firewall settings
- Ensure database files exist and are readable
- Try console dashboard mode instead

### Log File Locations

- **ShareTracker logs**: `ShareTracker\Logs\`
- **XMRig logs**: `xmrig\xmrig.log`
- **Reward calculation logs**: Console output during execution
- **Transaction logs**: Stored in reward-distributions.csv

## Maintenance Tasks

### Daily
- Monitor mining dashboard for activity
- Check tracking system status
- Review any error logs

### Weekly
- Calculate reward distributions
- Review miner contributions
- Backup database files

### Monthly
- Update miner wallet registrations
- Review and adjust configuration
- Check system performance and optimization
- Audit transaction history

## Support & Community

### Getting Help
1. **Check log files** for error messages
2. **Review configuration** files for accuracy
3. **Verify prerequisites** (PowerShell version, permissions)
4. **Test with minimal setup** before full deployment

### Contributing
- **Report issues** with detailed logs and steps to reproduce
- **Suggest improvements** to calculation algorithms or features
- **Share configuration templates** for different use cases
- **Contribute code** following existing script patterns

---

**System Version**: 1.0  
**Last Updated**: January 2025  
**Compatibility**: Windows 10/11, PowerShell 5.0+, Monero CLI  
**License**: MIT (same as EZ Fed Mine)