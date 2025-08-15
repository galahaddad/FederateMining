# EZ Fed Mine — One‑Click Monero P2Pool Miner

[![Release](https://img.shields.io/github/v/release/galahaddad/FederateMining)](https://github.com/galahaddad/FederateMining/releases)
[![Downloads](https://img.shields.io/github/downloads/galahaddad/FederateMining/total)](https://github.com/galahaddad/FederateMining/releases)
[![License](https://img.shields.io/github/license/galahaddad/FederateMining)](LICENSE)

A simple, one-click Monero mining solution that automatically downloads XMRig and connects to Ralph's P2Pool mini node. Perfect for friends who want to donate hashpower with minimal setup.

## 🚀 Overview

**ezFedMine.exe** is a self-contained Windows executable that:
- ✅ Downloads XMRig automatically on first run
- ✅ Pre-configures mining to Ralph's P2Pool mini node
- ✅ Starts mining immediately with optimal settings
- ✅ No manual configuration required
- ✅ Clean uninstall (just delete the folder)

### Mining Details
- **Pool:** `ralphfederated.duckdns.org:37888` (P2Pool mini)
- **Wallet:** `48ZRLsh2aiCAzRsCN4pxkAGtPLMUigXJmFaL2vwYKgFnLxCPbeQe2niYTU3DkF4QPAdULbQ8zCTop1MzPB3R81z88WEqjEk`
- **Algorithm:** RandomX (CPU mining)
- **Rig ID:** Your Windows computer name

> **Note:** All mining rewards go directly to Ralph's wallet. This tool is designed for friends donating hashpower.

## 📋 System Requirements

- **OS:** Windows 10/11 (64-bit)
- **RAM:** ~300 MB free (more is better for RandomX)
- **Network:** Internet access for GitHub and pool connection
- **Optional:** Administrator rights for optimal performance (huge pages)

## 📥 Installation & Usage

### Quick Start
1. Download the latest `ezFedMine.zip` from [Releases](https://github.com/galahaddad/FederateMining/releases)
2. Extract to any folder
3. Double-click `ezFedMine.exe`
4. Wait for automatic setup (first run only)
5. Start mining! 🎉

### First Run Process
```
XMRig not found… downloading…
Extraction complete
Writing config.json…
Launching XMRig…
[XMRig output with hashrate and share information]
```

### Subsequent Runs
The program skips download and starts mining immediately.

## 📁 Files Created

After first run, you'll see:
```
your-folder/
├── ezFedMine.exe          # Main executable
└── xmrig/                 # Auto-created folder
    ├── xmrig.exe          # Mining software
    ├── config.json        # Pre-configured settings
    ├── WinRing0x64.sys    # Hardware access driver
    └── [other XMRig files]
```

## 🔧 Troubleshooting

### Windows SmartScreen/Antivirus Warnings
Cryptocurrency miners often trigger false positives:
- Click **"More info"** → **"Run anyway"** in SmartScreen
- Add the folder to Windows Defender exclusions if quarantined
- This is normal for mining software

### Connection Issues
Test pool connectivity:
```powershell
Test-NetConnection ralphfederated.duckdns.org -Port 37888
```

### Low Hashrate
- Wait 30-60 seconds for RandomX warmup
- Set Windows power plan to **"High Performance"**
- Close memory-intensive applications
- Run as Administrator for huge pages support

### Huge Pages Setup (Optional Performance Boost)
1. Run `ezFedMine.exe` as Administrator
2. Enable "Lock pages in memory":
   - Press `Win+R`, run `secpol.msc`
   - Navigate: Local Policies → User Rights Assignment → Lock pages in memory
   - Add your user account → Sign out/in
3. Re-run the miner

## 🔒 Privacy & Security

- Downloads XMRig from official GitHub releases only
- No telemetry or data collection added
- Open source PowerShell script available in Archive folder
- Connections: Your PC → Pool + Standard XMRig dev donation (1%)

## 🗑️ Uninstall

1. Close the mining window (Ctrl+C)
2. Delete the entire folder containing `ezFedMine.exe`
3. No registry entries or services to clean up

## ⚙️ Advanced Configuration

### Custom Rig Name
- Change your Windows computer name, or
- Edit `rig-id` in `xmrig/config.json` after first run

### Enable Logging
Add to `xmrig/config.json`:
```json
"log-file": "xmrig.log"
```

### CPU Thread Tuning
XMRig auto-configures threads. Advanced users can modify the `cpu` section in `config.json`.

## 📊 Verifying Mining Status

Look for these indicators in the console:
- `url=ralphfederated.duckdns.org:37888` (correct pool)
- `user=48ZRL...` (Ralph's wallet)
- Increasing "accepted" share count
- Hashrate display (H/s)

## 🛠️ Development

This project uses PowerShell and ps2exe for compilation.

### Building from Source
1. Edit the PowerShell script in the `Archive/` folder
2. Use ps2exe to compile:
   ```powershell
   ps2exe .\ezFedMine.ps1 .\ezFedMine.exe -noConsole:$false -requireAdmin:$false
   ```

### Release Process
Use the included `build-release.ps1` script to create distribution packages.

## 📞 Support

If you encounter issues, send Ralph:
- Screenshot of the first 30 lines of ezFedMine console output
- Screenshot of the last 20 lines of XMRig console output

## ⚖️ License

This project is open source. See the [LICENSE](LICENSE) file for details.

---

**Happy Mining!** 🚀⛏️

*This tool is designed for educational purposes and voluntary hashpower donation among friends.*
