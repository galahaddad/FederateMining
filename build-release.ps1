# EZ Fed Mine Release Builder
# This script compiles the PowerShell source and creates a release package

param(
    [Parameter(Mandatory=$false)]
    [string]$Version = (Get-Date -Format "v1.0.yyyyMMdd"),
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipCompile = $false,
    
    [Parameter(Mandatory=$false)]
    [string]$SourceScript = ".\Archive\ezFedMine.ps1"
)

Write-Host "=== EZ Fed Mine Release Builder ===" -ForegroundColor Cyan
Write-Host "Version: $Version" -ForegroundColor Green

# Ensure we're in the correct directory
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ProjectRoot

# Check if ps2exe is available
try {
    Get-Command ps2exe -ErrorAction Stop
    Write-Host "✓ ps2exe found" -ForegroundColor Green
} catch {
    Write-Host "✗ ps2exe not found. Installing..." -ForegroundColor Yellow
    try {
        Install-Module ps2exe -Force -Scope CurrentUser
        Write-Host "✓ ps2exe installed" -ForegroundColor Green
    } catch {
        Write-Error "Failed to install ps2exe. Please install manually: Install-Module ps2exe"
        exit 1
    }
}

# Verify source script exists
if (-not (Test-Path $SourceScript)) {
    Write-Error "Source script not found: $SourceScript"
    Write-Host "Available scripts in Archive:"
    Get-ChildItem .\Archive\*.ps1 | ForEach-Object { Write-Host "  - $($_.Name)" }
    exit 1
}

Write-Host "Using source script: $SourceScript" -ForegroundColor Yellow

# Create release directory structure
$ReleaseDir = ".\Release\$Version"
$BuildDir = "$ReleaseDir\ezFedMine"

Write-Host "Creating release directory: $ReleaseDir" -ForegroundColor Yellow
New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null

# Compile the PowerShell script to EXE (unless skipped)
if (-not $SkipCompile) {
    Write-Host "Compiling PowerShell script to EXE..." -ForegroundColor Yellow
    
    $ExePath = "$BuildDir\ezFedMine.exe"
    
    try {
        # Compile with ps2exe
        ps2exe -inputFile $SourceScript -outputFile $ExePath `
               -noConsole:$false `
               -requireAdmin:$false `
               -title "EZ Fed Mine" `
               -description "One-Click Monero P2Pool Miner" `
               -company "Ralph's Mining Tools" `
               -version "1.0.0.0" `
               -copyright "Open Source"
        
        if (Test-Path $ExePath) {
            Write-Host "✓ Compilation successful: $ExePath" -ForegroundColor Green
        } else {
            throw "Compilation failed - output file not created"
        }
    } catch {
        Write-Error "Compilation failed: $_"
        exit 1
    }
} else {
    Write-Host "Skipping compilation (using existing EXE)" -ForegroundColor Yellow
    # Copy existing EXE if available
    if (Test-Path ".\ezFedMine.exe") {
        Copy-Item ".\ezFedMine.exe" "$BuildDir\ezFedMine.exe"
        Write-Host "✓ Copied existing EXE" -ForegroundColor Green
    } elseif (Test-Path ".\ezFedMine\ezFedMine.exe") {
        Copy-Item ".\ezFedMine\ezFedMine.exe" "$BuildDir\ezFedMine.exe"
        Write-Host "✓ Copied existing EXE from ezFedMine folder" -ForegroundColor Green
    } else {
        Write-Error "No existing EXE found to copy"
        exit 1
    }
}

# Copy README
Write-Host "Copying documentation..." -ForegroundColor Yellow
Copy-Item ".\README_ezFedMine.md" "$BuildDir\README_ezFedMine.md"

# Create version info file
$VersionInfo = @"
EZ Fed Mine - Release Information
================================

Version: $Version
Build Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Build Machine: $env:COMPUTERNAME
Build User: $env:USERNAME

Contents:
- ezFedMine.exe      Main executable
- README_ezFedMine.md   User documentation

Installation:
1. Extract this ZIP to any folder
2. Double-click ezFedMine.exe
3. First run will download XMRig automatically
4. Mining starts immediately after setup

Pool Target: ralphfederated.duckdns.org:37888
Wallet: 48ZRLsh2aiCAzRsCN4pxkAGtPLMUigXJmFaL2vwYKgFnLxCPbeQe2niYTU3DkF4QPAdULbQ8zCTop1MzPB3R81z88WEqjEk

For support, contact Ralph with screenshots of any errors.
"@

$VersionInfo | Out-File -FilePath "$BuildDir\VERSION.txt" -Encoding UTF8

# Create the ZIP package
$ZipPath = "$ReleaseDir\ezFedMine-$Version-windows-x64.zip"
Write-Host "Creating release package: $ZipPath" -ForegroundColor Yellow

try {
    # Remove existing ZIP if it exists
    if (Test-Path $ZipPath) {
        Remove-Item $ZipPath -Force
    }
    
    # Create ZIP using .NET compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($BuildDir, $ZipPath)
    
    Write-Host "✓ Release package created successfully" -ForegroundColor Green
} catch {
    Write-Error "Failed to create ZIP package: $_"
    exit 1
}

# Calculate file sizes and checksums
$ExeSize = (Get-Item "$BuildDir\ezFedMine.exe").Length
$ZipSize = (Get-Item $ZipPath).Length
$ZipHash = Get-FileHash $ZipPath -Algorithm SHA256

# Display summary
Write-Host "`n=== Release Summary ===" -ForegroundColor Cyan
Write-Host "Version: $Version" -ForegroundColor White
Write-Host "EXE Size: $([math]::Round($ExeSize / 1MB, 2)) MB" -ForegroundColor White
Write-Host "ZIP Size: $([math]::Round($ZipSize / 1MB, 2)) MB" -ForegroundColor White
Write-Host "SHA256: $($ZipHash.Hash)" -ForegroundColor White
Write-Host "Location: $ZipPath" -ForegroundColor White

# Create release notes
$ReleaseNotes = @"
# Release $Version

## What's New
- Updated build from $(Get-Date -Format "MMMM dd, yyyy")
- Fresh compilation with latest ps2exe
- Tested on Windows 10/11 x64

## Download
- **File:** ezFedMine-$Version-windows-x64.zip
- **Size:** $([math]::Round($ZipSize / 1MB, 2)) MB
- **SHA256:** $($ZipHash.Hash)

## Installation
1. Download and extract the ZIP file
2. Double-click ``ezFedMine.exe``
3. First run automatically downloads XMRig
4. Mining begins immediately after setup

## Mining Details
- **Pool:** ralphfederated.duckdns.org:37888
- **Algorithm:** RandomX (CPU only)
- **Target Wallet:** Ralph's wallet (for hashpower donation)

## System Requirements
- Windows 10/11 (64-bit)
- ~300 MB RAM for RandomX
- Internet connection
- Optional: Admin rights for huge pages

## Troubleshooting
If Windows SmartScreen blocks the file:
1. Click "More info"
2. Click "Run anyway"
3. Add folder to antivirus exclusions if needed

Mining software commonly triggers false positives.

---
*Happy mining! 🚀*
"@

$ReleaseNotes | Out-File -FilePath "$ReleaseDir\RELEASE_NOTES.md" -Encoding UTF8

Write-Host "`n=== Next Steps ===" -ForegroundColor Cyan
Write-Host "1. Test the release: Extract and run $ZipPath" -ForegroundColor White
Write-Host "2. Upload to GitHub Releases with the notes from RELEASE_NOTES.md" -ForegroundColor White
Write-Host "3. Update any download links in documentation" -ForegroundColor White

Write-Host "`nRelease build complete! 🎉" -ForegroundColor Green
