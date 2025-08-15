#!/usr/bin/env pwsh
# Quick Release Script for EZ Fed Mine
# Usage: .\quick-release.ps1 [version]

param(
    [Parameter(Position=0)]
    [string]$Version = ""
)

if ([string]::IsNullOrEmpty($Version)) {
    $Version = "v1.0.$(Get-Date -Format 'yyyyMMdd')"
    Write-Host "No version specified, using: $Version" -ForegroundColor Yellow
}

Write-Host "🚀 EZ Fed Mine Quick Release" -ForegroundColor Cyan
Write-Host "Version: $Version" -ForegroundColor Green

# Find the latest PowerShell script
$LatestScript = Get-ChildItem .\Archive\*.ps1 | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $LatestScript) {
    Write-Error "No PowerShell scripts found in Archive folder!"
    exit 1
}

Write-Host "Using source: $($LatestScript.Name)" -ForegroundColor Yellow

# Run the full build script
try {
    .\build-release.ps1 -Version $Version -SourceScript $LatestScript.FullName
    
    Write-Host "`n✅ Quick release complete!" -ForegroundColor Green
    Write-Host "📦 Package: .\Release\$Version\ezFedMine-$Version-windows-x64.zip" -ForegroundColor Cyan
    
    # Open the release folder
    Invoke-Item ".\Release\$Version"
    
} catch {
    Write-Error "Release failed: $_"
    exit 1
}

Write-Host "`n🎯 Next steps:" -ForegroundColor Cyan
Write-Host "1. Test the package by extracting and running it" -ForegroundColor White
Write-Host "2. Upload to GitHub releases if everything works" -ForegroundColor White
Write-Host "3. Tag the commit: git tag $Version && git push origin $Version" -ForegroundColor White
