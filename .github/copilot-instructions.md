# EZ Fed Mine - GitHub Copilot Instructions

**ALWAYS** follow these instructions first and fallback to additional search and context gathering only if the information here is incomplete or found to be in error.

## Project Overview

EZ Fed Mine is a Windows-only PowerShell application that creates a one-click Monero P2Pool miner. The application downloads XMRig automatically and connects to Ralph's P2Pool node for hashpower donation. The project compiles PowerShell scripts to Windows executables using ps2exe.

## Critical Platform Requirements

**WINDOWS ONLY**: This project ONLY works on Windows. Do NOT attempt to build or run on Linux/macOS.

- **Operating System**: Windows 10/11 (64-bit) REQUIRED
- **PowerShell**: Windows PowerShell 5.1 or PowerShell 7+ on Windows
- **ps2exe Module**: Required for compilation (Windows-only module)
- **Architecture**: Windows x64 only (mining software is Windows x64 specific)

## Working Effectively

### Bootstrap and Setup (Windows Only)

Run these commands in PowerShell as Administrator:

```powershell
# Install ps2exe module - NEVER CANCEL: Takes 2-5 minutes
Install-Module ps2exe -Force -Scope CurrentUser

# Verify installation
Get-Command ps2exe
```

**NEVER CANCEL**: Module installation takes 2-5 minutes. Set timeout to 10+ minutes.

### Build Process (Windows Only)

**CRITICAL**: All build commands must run on Windows. Set timeout to 30+ minutes for compilation.

```powershell
# Quick build with latest script - NEVER CANCEL: Takes 10-20 minutes
.\quick-release.ps1

# Custom build with specific version - NEVER CANCEL: Takes 15-25 minutes  
.\build-release.ps1 -Version "v1.0.test"

# Build without recompiling (use existing EXE)
.\build-release.ps1 -SkipCompile
```

**NEVER CANCEL**: Build process takes 15-25 minutes including compilation. Always set timeout to 30+ minutes.

### Development Workflow

```powershell
# Find the latest PowerShell script (by version number, not timestamp)
$latest = Get-ChildItem .\Archive\*.ps1 | Sort-Object { if ($_.Name -match '_v(\d+)([a-z]?)\.ps1$') { $matches[1] + $matches[2] } else { '0' } } -Descending | Select-Object -First 1
notepad $latest.FullName

# Test script directly (will fail on non-Windows but shows syntax errors)
powershell -File $latest.FullName

# Compile to EXE for testing - NEVER CANCEL: Takes 5-10 minutes
ps2exe -inputFile $latest.FullName -outputFile ".\test-build.exe" -noConsole:$false -requireAdmin:$false
```

## Validation and Testing

### Build Validation

**MANUAL VALIDATION REQUIRED**: After every build, you MUST test the actual mining functionality:

1. **Extract and Run Test**:
   ```powershell
   # Extract the built ZIP package
   Expand-Archive -Path ".\Release\*\*.zip" -DestinationPath ".\test-extract"
   
   # Run the executable
   .\test-extract\ezFedMine\ezFedMine.exe
   ```

2. **Verify Mining Connection** (5-10 minutes):
   - Look for `url=ralphfederated.duckdns.org:3333` in console output
   - Verify wallet address: `user=48ZRL...` (Ralph's wallet)
   - Wait for "accepted" share count to increase
   - Confirm hashrate display (H/s values)
   - **NEVER CANCEL**: XMRig warmup takes 2-3 minutes, full validation takes 5-10 minutes

3. **Connection Test** (Windows only):
   ```powershell
   # Test pool connectivity (Windows only - Test-NetConnection not available on Linux)
   Test-NetConnection ralphfederated.duckdns.org -Port 3333
   
   # Alternative test using basic connectivity
   try { (New-Object System.Net.Sockets.TcpClient).Connect('ralphfederated.duckdns.org', 3333); Write-Host 'Connection successful' } catch { Write-Host 'Connection failed' }
   ```

### GitHub Actions Testing

The project includes automated builds via GitHub Actions (`.github/workflows/release.yml`):

```bash
# Trigger manual build
gh workflow run release.yml -f version=v1.0.test

# Check build status - NEVER CANCEL: Takes 20-30 minutes on GitHub Actions
gh run list --workflow=release.yml

# Download artifacts after build completes
gh run download <run-id>
```

**NEVER CANCEL**: GitHub Actions builds take 20-30 minutes. Set timeout to 45+ minutes.

## Project Structure

```
FederateMining/
Archive/
├── ezFedMine_v4h.ps1      # Latest version (335 lines, 11KB) - use version-based sorting
├── ezFedMine_v4g.ps1      # Previous version (331 lines)
├── ezFedMine_v4f.ps1      # Previous version (335 lines)
└── ezFedMine_*.ps1        # Historical versions (150-210 lines each)
├── .github/workflows/         
│   └── release.yml            # Automated build workflow
├── build-release.ps1          # Manual build script
├── quick-release.ps1          # Fast build script
├── README.md                  # Project documentation
├── README_ezFedMine.md        # End-user documentation
└── Release/                   # Build outputs (gitignored)
```

### Key Files Reference

```powershell
# View latest source script (by version number)
$latest = Get-ChildItem .\Archive\*.ps1 | Sort-Object { if ($_.Name -match '_v(\d+)([a-z]?)\.ps1$') { $matches[1] + $matches[2] } else { '0' } } -Descending | Select-Object -First 1
Get-Content $latest.FullName

# View build configuration
Get-Content .\build-release.ps1

# View GitHub Actions workflow
Get-Content .\.github\workflows\release.yml
```

## Common Commands and Expected Timing

| Command | Expected Time | Timeout Setting | Platform |
|---------|---------------|-----------------|----------|
| `Install-Module ps2exe` | 2-5 minutes | 10 minutes | Windows only |
| `.\quick-release.ps1` | 15-25 minutes | 30 minutes | Windows only |
| `.\build-release.ps1` | 15-25 minutes | 30 minutes | Windows only |
| `ps2exe compilation` | 5-10 minutes | 15 minutes | Windows only |
| Mining validation | 5-10 minutes | 15 minutes | Windows only |
| GitHub Actions build | 20-30 minutes | 45 minutes | GitHub hosted |

**CRITICAL**: NEVER CANCEL any build operation. Mining software compilation and validation takes time.

## Troubleshooting

### Build Issues

```powershell
# Check ps2exe installation
Get-Module ps2exe -ListAvailable

# Reinstall if missing
Install-Module ps2exe -Force -Scope CurrentUser

# Check PowerShell version (needs 5.1+ on Windows)
$PSVersionTable

# Verify source script exists
Test-Path .\Archive\ezFedMine_v4h.ps1
```

### Platform Issues

- **Linux/macOS**: Project will NOT work. Use Windows or GitHub Actions for builds.
- **PowerShell Core on Linux**: Can read scripts but cannot compile or run mining functionality.
- **WSL**: Will not work for mining functionality, may work for script editing only.

## Development Guidelines

### Making Changes

```powershell
# Always work with the latest script version (by version number)
$latest = Get-ChildItem .\Archive\*.ps1 | Sort-Object { if ($_.Name -match '_v(\d+)([a-z]?)\.ps1$') { $matches[1] + $matches[2] } else { '0' } } -Descending | Select-Object -First 1

# Create new version when making changes
$newVersion = $latest.Name -replace '\.ps1$', '_new.ps1'
Copy-Item $latest.FullName ".\Archive\$newVersion"

# Edit the new version
notepad ".\Archive\$newVersion"

# Test compilation (Windows only)
ps2exe -inputFile ".\Archive\$newVersion" -outputFile ".\test.exe"
```

### Code Validation

```powershell
# Always run syntax check before building
powershell -File .\Archive\ezFedMine_new.ps1 -WhatIf

# Check for common issues
Select-String -Path .\Archive\*.ps1 -Pattern "TODO|FIXME|HACK"

# Validate pool configuration
Select-String -Path .\Archive\*.ps1 -Pattern "ralphfederated.duckdns.org|3333"
```

### Testing Scenarios

**MANDATORY**: Always test these scenarios after changes:

1. **First Run Scenario** (15-20 minutes):
   - Clean system without XMRig installed
   - Run ezFedMine.exe
   - Verify XMRig download (takes 5-10 minutes)
   - Confirm mining starts automatically
   - NEVER CANCEL during download/setup

2. **Subsequent Run Scenario** (2-3 minutes):
   - System with XMRig already downloaded
   - Run ezFedMine.exe
   - Should skip download and start mining immediately

3. **Network Issues Scenario**:
   - Test with DNS issues
   - Verify fallback pool connections work
   - Check error handling and user guidance

4. **Administrative Rights Testing**:
   - Test without admin rights (normal operation)
   - Test with admin rights (huge pages optimization)
   - Verify appropriate messaging for both scenarios

### Script Validation Commands

```powershell
# Check for syntax errors (works on any platform)
powershell -File .\Archive\ezFedMine_latest.ps1 -WhatIf

# Look for development issues
Select-String -Path .\Archive\*.ps1 -Pattern "TODO|FIXME|HACK"

# Validate pool configuration across all versions
Select-String -Path .\Archive\*.ps1 -Pattern "ralphfederated.duckdns.org|3333|37888"

# Check wallet address consistency
Select-String -Path .\Archive\*.ps1 -Pattern "48ZRL.*"

# Verify XMRig download URLs are current
Select-String -Path .\Archive\*.ps1 -Pattern "github.com/xmrig/xmrig"
```

## Release Process

### Manual Release

```powershell
# 1. Create release build - NEVER CANCEL: 15-25 minutes
.\quick-release.ps1 v1.0.$(Get-Date -Format yyyyMMdd)

# 2. Test the release package manually (REQUIRED)
$releaseZip = Get-ChildItem .\Release\*\*.zip | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Expand-Archive $releaseZip.FullName -DestinationPath .\test-release
.\test-release\ezFedMine\ezFedMine.exe

# 3. Create Git tag after successful test
git tag v1.0.$(Get-Date -Format yyyyMMdd)
git push origin --tags
```

### Automated Release

```bash
# Trigger GitHub Actions release
gh workflow run release.yml -f version=v1.0.$(date +%Y%m%d)

# Monitor progress - NEVER CANCEL: 20-30 minutes
gh run watch
```

## File Exclusions

The following files are gitignored and should NOT be committed:

```
Release/          # Build outputs
*.exe            # Compiled executables  
*.zip            # Distribution packages
xmrig/           # Downloaded mining software
*.log            # Log files
test-*           # Testing artifacts
```

## Common File Operations

### Viewing and Navigating Code

```powershell
# List all script versions sorted by version number
Get-ChildItem .\Archive\*.ps1 | Sort-Object { if ($_.Name -match '_v(\d+)([a-z]?)\.ps1$') { $matches[1] + $matches[2] } else { '0' } } -Descending | Format-Table Name, Length, LastWriteTime

# Compare two script versions
$v1 = ".\Archive\ezFedMine_v4g.ps1"
$v2 = ".\Archive\ezFedMine_v4h.ps1"
Compare-Object (Get-Content $v1) (Get-Content $v2) -IncludeEqual | Where-Object SideIndicator -ne "=="

# View specific configuration sections
Select-String -Path .\Archive\ezFedMine_v4h.ps1 -Pattern "SETTINGS" -Context 10,20

# Check file sizes and complexity
Get-ChildItem .\Archive\*.ps1 | Select-Object Name, @{Name="Lines";Expression={(Get-Content $_.FullName | Measure-Object).Count}}, @{Name="SizeKB";Expression={[math]::Round($_.Length/1024,1)}}
```

### Working with Build Outputs

```powershell
# List recent releases
Get-ChildItem .\Release\* -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 5

# Check release package contents
$latestRelease = Get-ChildItem .\Release\*\*.zip | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($latestRelease) { 
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::OpenRead($latestRelease.FullName).Entries | Select-Object FullName, Length
}

# Clean up build artifacts
Remove-Item .\Release\* -Recurse -Force -Confirm:$false
Remove-Item .\test*.exe -Force -ErrorAction SilentlyContinue
```

1. **WINDOWS ONLY**: This project only works on Windows
2. **NEVER CANCEL**: All build operations take 15-30 minutes
3. **MANUAL TESTING**: Always test mining functionality after builds
4. **TIMEOUT SETTINGS**: Use 30+ minute timeouts for builds
5. **VALIDATION REQUIRED**: Test actual mining connection and functionality
6. **ps2exe DEPENDENCY**: Required for all compilation tasks

## Critical Reminders

- Main README: `.\README.md` - Project overview and development info
- User README: `.\README_ezFedMine.md` - End-user installation and troubleshooting
- GitHub Actions: `.\.github\workflows\release.yml` - Automated build configuration
- Source Code: `.\Archive\` - PowerShell source scripts (use latest by LastWriteTime)

## Support and Documentation

- Main README: `.\README.md` - Project overview and development info
- User README: `.\README_ezFedMine.md` - End-user installation and troubleshooting
- GitHub Actions: `.\.github\workflows\release.yml` - Automated build configuration
- Source Code: `.\Archive\` - PowerShell source scripts (use latest by version number)

**Always validate every command and instruction before using them in development.**