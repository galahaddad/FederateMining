# Installation Guide - EZ Fed Mine Reward Sharing System

## Quick Start Installation

### Step 1: Download and Setup
1. Ensure you have the complete ShareTracker directory
2. Place it in your EZ Fed Mine folder
3. Run the setup script in PowerShell as Administrator:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   .\ShareTracker\SetupRewardSharing.ps1
   ```

### Step 2: Configure Wallet (IMPORTANT)
1. Edit `ShareTracker\Config\reward-config.json`
2. Set your Monero wallet password (never commit this to version control)
3. Adjust reward distribution settings as needed

### Step 3: Register Miners
1. Each miner must provide their Monero wallet address
2. Add entries to `ShareTracker\Database\miner-wallets.csv`:
   ```csv
   RigId,WalletAddress,RegistrationDate,Status,Notes
   JOHN-PC,4ABC123...,2025-01-20,Active,John's gaming rig
   ```

### Step 4: Start Mining with Tracking
Replace your current ezFedMine.exe usage with:
```powershell
.\Archive\ezFedMine_v5_RewardSharing.ps1 -EnableTracking
```

### Step 5: Monitor Progress
View the dashboard:
```powershell
.\ShareTracker\Scripts\show-dashboard.ps1
```

### Step 6: Calculate and Distribute Rewards
Daily reward calculation:
```powershell
.\ShareTracker\Scripts\calculate-rewards.ps1
```

Send rewards (after review):
```powershell
.\ShareTracker\MoneroRewardSender.ps1
```

## File Structure Created

```
ShareTracker/
├── ShareTracker.ps1              # Core tracking engine
├── RewardDistributor.ps1         # Reward calculation
├── MoneroRewardSender.ps1        # Payment processing
├── RewardDashboard.ps1           # Monitoring dashboard
├── SetupRewardSharing.ps1        # Initial setup
├── TestRewardSystem.ps1          # System validation
├── Config/
│   ├── reward-config.json        # Main configuration
│   └── tracking-schedule.json    # Automation settings
├── Database/
│   ├── shares.csv               # Share tracking data
│   ├── hashrate.csv             # Hashrate measurements
│   ├── sessions.csv             # Mining sessions
│   ├── reward-distributions.csv # Payment records
│   └── miner-wallets.csv        # Wallet registry
├── Scripts/
│   ├── start-tracking.ps1       # Start tracking
│   ├── calculate-rewards.ps1    # Calculate rewards
│   └── show-dashboard.ps1       # Show dashboard
└── Logs/
    └── (various log files)
```

## Security Notes

1. **Never commit wallet passwords** to version control
2. **Backup your wallet files** regularly
3. **Test with small amounts** before full deployment
4. **Keep the Database folder** backed up
5. **Use strong passwords** for wallet files

## Troubleshooting

### Common Issues:

1. **PowerShell Execution Policy Error**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

2. **XMRig Log File Not Found**
   - Ensure XMRig is configured with `"log-file": "xmrig.log"`
   - Check the log path in tracking configuration

3. **No Mining Data Appearing**
   - Verify ShareTracker.ps1 is running
   - Check Windows Task Manager for background PowerShell processes
   - Ensure proper file permissions

4. **Wallet Connection Issues**
   - Verify Monero CLI tools are installed
   - Check wallet file paths and passwords
   - Ensure wallet is synchronized

### Getting Help:
1. Check log files in the Logs directory
2. Run the test suite: `.\ShareTracker\TestRewardSystem.ps1`
3. Verify configuration files are properly formatted
4. Ensure all required files are present

## System Requirements

- Windows 10/11 (64-bit)
- PowerShell 5.0 or higher
- Monero CLI tools (for payment processing)
- ~50MB disk space for tracking data
- Internet connection for pool access

## Configuration Examples

### Basic Configuration (reward-config.json):
```json
{
  "Distribution": {
    "OwnerSharePercent": 10,
    "MinimumPayout": 0.001,
    "DistributionPeriodHours": 24
  },
  "Calculation": {
    "WeightShareCount": 0.6,
    "WeightHashrate": 0.4,
    "MinimumSessionHours": 2
  }
}
```

### Miner Registration (miner-wallets.csv):
```csv
RigId,WalletAddress,RegistrationDate,Status,Notes
GAMING-PC,4A1B2C3D...,2025-01-20,Active,Main gaming rig
LAPTOP,4E5F6G7H...,2025-01-20,Active,Backup laptop
SERVER,4I9J0K1L...,2025-01-20,Active,Dedicated server
```

## Testing the System

Run the comprehensive test suite:
```powershell
.\ShareTracker\TestRewardSystem.ps1
```

For quick validation:
```powershell
.\ShareTracker\TestRewardSystem.ps1 -QuickTest
```

## Support

For issues or questions:
1. Review the complete documentation in README-RewardSharing-Complete.md
2. Check the troubleshooting section above
3. Validate your setup with the test suite
4. Ensure all configuration files are properly formatted

---

**Happy Mining with Fair Rewards!** 🎯⛏️💰