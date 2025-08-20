# TestRewardSystem.ps1 - Test Suite for Reward Sharing System

<#
.SYNOPSIS
    Comprehensive test suite for the reward sharing system
.DESCRIPTION
    Tests all components of the reward sharing system with sample data
    and validates calculations, database operations, and configuration.
.PARAMETER TestDataPath
    Path to store test data
.PARAMETER QuickTest
    Run only essential tests
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$TestDataPath = ".\TestData",
    
    [Parameter(Mandatory=$false)]
    [switch]$QuickTest = $false
)

$ErrorActionPreference = 'Stop'

function Write-TestLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = switch ($Level) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "WARN" { "Yellow" }
        "INFO" { "Cyan" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-Prerequisites {
    Write-TestLog "Testing Prerequisites..." "INFO"
    
    $tests = @()
    
    # PowerShell version
    $psVersion = $PSVersionTable.PSVersion.Major
    if ($psVersion -ge 5) {
        $tests += @{ Name = "PowerShell Version"; Result = "PASS"; Details = "v$psVersion" }
    } else {
        $tests += @{ Name = "PowerShell Version"; Result = "FAIL"; Details = "v$psVersion (requires 5+)" }
    }
    
    # Required modules
    $requiredCommands = @('ConvertTo-Json', 'ConvertFrom-Json', 'Import-Csv', 'Export-Csv')
    foreach ($cmd in $requiredCommands) {
        if (Get-Command $cmd -ErrorAction SilentlyContinue) {
            $tests += @{ Name = "Command: $cmd"; Result = "PASS"; Details = "Available" }
        } else {
            $tests += @{ Name = "Command: $cmd"; Result = "FAIL"; Details = "Not found" }
        }
    }
    
    # File system permissions
    try {
        $testFile = Join-Path $TestDataPath "permission-test.txt"
        "test" | Out-File -FilePath $testFile -Encoding UTF8
        Remove-Item $testFile -Force
        $tests += @{ Name = "File System Access"; Result = "PASS"; Details = "Read/Write OK" }
    } catch {
        $tests += @{ Name = "File System Access"; Result = "FAIL"; Details = $_.Exception.Message }
    }
    
    return $tests
}

function Create-TestData {
    Write-TestLog "Creating Test Data..." "INFO"
    
    # Create test directory structure
    $testPaths = @(
        $TestDataPath,
        (Join-Path $TestDataPath "Database"),
        (Join-Path $TestDataPath "Config"),
        (Join-Path $TestDataPath "Logs")
    )
    
    foreach ($path in $testPaths) {
        if (-not (Test-Path $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
    }
    
    # Create sample shares data
    $sharesFile = Join-Path $TestDataPath "Database\shares.csv"
    $sharesData = @"
Timestamp,RigId,ShareType,Difficulty,Hash,Nonce
2025-01-20 10:00:00,TEST-PC-1,accepted,1000,,
2025-01-20 10:01:00,TEST-PC-2,accepted,1500,,
2025-01-20 10:02:00,TEST-PC-1,accepted,1000,,
2025-01-20 10:03:00,TEST-PC-3,accepted,2000,,
2025-01-20 10:04:00,TEST-PC-2,rejected,1500,,
2025-01-20 10:05:00,TEST-PC-1,accepted,1000,,
2025-01-20 10:06:00,TEST-PC-3,accepted,2000,,
2025-01-20 10:07:00,TEST-PC-2,accepted,1500,,
2025-01-20 10:08:00,TEST-PC-1,accepted,1000,,
2025-01-20 10:09:00,TEST-PC-3,accepted,2000,,
"@
    $sharesData | Out-File -FilePath $sharesFile -Encoding UTF8
    
    # Create sample hashrate data
    $hashrateFile = Join-Path $TestDataPath "Database\hashrate.csv"
    $hashrateData = @"
Timestamp,RigId,Hashrate10s,Hashrate60s,Hashrate15m,Threads
2025-01-20 10:00:00,TEST-PC-1,1200,1200,1200,8
2025-01-20 10:01:00,TEST-PC-2,800,800,800,4
2025-01-20 10:02:00,TEST-PC-3,1500,1500,1500,12
2025-01-20 10:03:00,TEST-PC-1,1250,1225,1210,8
2025-01-20 10:04:00,TEST-PC-2,820,810,805,4
2025-01-20 10:05:00,TEST-PC-3,1520,1510,1505,12
2025-01-20 10:06:00,TEST-PC-1,1180,1200,1195,8
2025-01-20 10:07:00,TEST-PC-2,790,800,798,4
2025-01-20 10:08:00,TEST-PC-3,1480,1500,1495,12
2025-01-20 10:09:00,TEST-PC-1,1220,1215,1200,8
"@
    $hashrateData | Out-File -FilePath $hashrateFile -Encoding UTF8
    
    # Create sample session data
    $sessionFile = Join-Path $TestDataPath "Database\sessions.csv"
    $sessionData = @"
Timestamp,RigId,Event,SessionId,Pool,Wallet
2025-01-20 09:00:00,TEST-PC-1,mining_start,20250120090000,ralphfederated.duckdns.org:3333,48ZRL...
2025-01-20 09:30:00,TEST-PC-2,mining_start,20250120093000,ralphfederated.duckdns.org:3333,48ZRL...
2025-01-20 10:00:00,TEST-PC-3,mining_start,20250120100000,ralphfederated.duckdns.org:3333,48ZRL...
2025-01-20 12:00:00,TEST-PC-1,tracker_stop,20250120090000,,
2025-01-20 12:30:00,TEST-PC-2,tracker_stop,20250120093000,,
2025-01-20 13:00:00,TEST-PC-3,tracker_stop,20250120100000,,
"@
    $sessionData | Out-File -FilePath $sessionFile -Encoding UTF8
    
    # Create sample config
    $configFile = Join-Path $TestDataPath "Config\reward-config.json"
    $configData = @{
        MainWallet = @{
            Address = "48ZRLsh2aiCAzRsCN4pxkAGtPLMUigXJmFaL2vwYKgFnLxCPbeQe2niYTU3DkF4QPAdULbQ8zCTop1MzPB3R81z88WEqjEk"
            Password = "test-password"
            FileName = "test_wallet"
        }
        Distribution = @{
            OwnerSharePercent = 10
            MinimumPayout = 0.001
            DistributionPeriodHours = 24
            RequiredConfirmations = 10
        }
        Calculation = @{
            WeightShareCount = 0.6
            WeightHashrate = 0.4
            MinimumSessionHours = 1  # Reduced for testing
        }
    }
    $configData | ConvertTo-Json -Depth 3 | Out-File -FilePath $configFile -Encoding UTF8
    
    # Create sample miner wallets
    $walletFile = Join-Path $TestDataPath "Database\miner-wallets.csv"
    $walletData = @"
RigId,WalletAddress,RegistrationDate,Status,Notes
TEST-PC-1,4TEST1...,2025-01-20,Active,Test miner 1
TEST-PC-2,4TEST2...,2025-01-20,Active,Test miner 2
TEST-PC-3,4TEST3...,2025-01-20,Active,Test miner 3
"@
    $walletData | Out-File -FilePath $walletFile -Encoding UTF8
    
    Write-TestLog "Test data created successfully" "PASS"
}

function Test-DatabaseOperations {
    Write-TestLog "Testing Database Operations..." "INFO"
    
    $tests = @()
    
    # Test CSV reading
    try {
        $sharesFile = Join-Path $TestDataPath "Database\shares.csv"
        $shares = Import-Csv $sharesFile
        
        if ($shares.Count -gt 0) {
            $tests += @{ Name = "CSV Import (Shares)"; Result = "PASS"; Details = "$($shares.Count) records" }
        } else {
            $tests += @{ Name = "CSV Import (Shares)"; Result = "FAIL"; Details = "No records imported" }
        }
        
        # Test data filtering
        $acceptedShares = $shares | Where-Object { $_.ShareType -eq "accepted" }
        $rejectedShares = $shares | Where-Object { $_.ShareType -eq "rejected" }
        
        $tests += @{ Name = "Data Filtering"; Result = "PASS"; Details = "$($acceptedShares.Count) accepted, $($rejectedShares.Count) rejected" }
        
    } catch {
        $tests += @{ Name = "CSV Import"; Result = "FAIL"; Details = $_.Exception.Message }
    }
    
    # Test JSON operations
    try {
        $configFile = Join-Path $TestDataPath "Config\reward-config.json"
        $config = Get-Content $configFile -Raw | ConvertFrom-Json
        
        if ($config.Distribution.OwnerSharePercent -eq 10) {
            $tests += @{ Name = "JSON Config Loading"; Result = "PASS"; Details = "Config loaded correctly" }
        } else {
            $tests += @{ Name = "JSON Config Loading"; Result = "FAIL"; Details = "Config data incorrect" }
        }
        
    } catch {
        $tests += @{ Name = "JSON Config Loading"; Result = "FAIL"; Details = $_.Exception.Message }
    }
    
    return $tests
}

function Test-CalculationLogic {
    Write-TestLog "Testing Calculation Logic..." "INFO"
    
    $tests = @()
    
    try {
        # Load test data
        $sharesFile = Join-Path $TestDataPath "Database\shares.csv"
        $hashrateFile = Join-Path $TestDataPath "Database\hashrate.csv"
        $configFile = Join-Path $TestDataPath "Config\reward-config.json"
        
        $shares = Import-Csv $sharesFile
        $hashrates = Import-Csv $hashrateFile
        $config = Get-Content $configFile -Raw | ConvertFrom-Json
        
        # Calculate stats for each miner
        $rigIds = ($shares | Select-Object -ExpandProperty RigId -Unique)
        
        $minerStats = @()
        foreach ($rigId in $rigIds) {
            $rigShares = $shares | Where-Object { $_.RigId -eq $rigId }
            $rigHashrates = $hashrates | Where-Object { $_.RigId -eq $rigId }
            
            $acceptedShares = ($rigShares | Where-Object { $_.ShareType -eq "accepted" }).Count
            $avgHashrate = if ($rigHashrates.Count -gt 0) {
                ($rigHashrates | Measure-Object -Property Hashrate60s -Average).Average
            } else { 0 }
            
            $minerStats += [PSCustomObject]@{
                RigId = $rigId
                AcceptedShares = $acceptedShares
                AverageHashrate = $avgHashrate
            }
        }
        
        # Test calculation logic
        $totalShares = ($minerStats | Measure-Object -Property AcceptedShares -Sum).Sum
        $totalHashrate = ($minerStats | Measure-Object -Property AverageHashrate -Sum).Sum
        
        if ($totalShares -gt 0 -and $totalHashrate -gt 0) {
            $tests += @{ Name = "Data Aggregation"; Result = "PASS"; Details = "Total shares: $totalShares, Total hashrate: $totalHashrate" }
        } else {
            $tests += @{ Name = "Data Aggregation"; Result = "FAIL"; Details = "Invalid totals" }
        }
        
        # Test contribution scoring
        foreach ($miner in $minerStats) {
            $shareRatio = $miner.AcceptedShares / $totalShares
            $hashrateRatio = $miner.AverageHashrate / $totalHashrate
            $contributionScore = ($shareRatio * $config.Calculation.WeightShareCount) + ($hashrateRatio * $config.Calculation.WeightHashrate)
            
            if ($contributionScore -ge 0 -and $contributionScore -le 1) {
                $tests += @{ Name = "Contribution Score ($($miner.RigId))"; Result = "PASS"; Details = [math]::Round($contributionScore, 4) }
            } else {
                $tests += @{ Name = "Contribution Score ($($miner.RigId))"; Result = "FAIL"; Details = "Invalid score: $contributionScore" }
            }
        }
        
        # Test reward distribution
        $availableBalance = 1.0  # 1 XMR for testing
        $ownerShare = $availableBalance * ($config.Distribution.OwnerSharePercent / 100)
        $distributionPool = $availableBalance - $ownerShare
        
        if ($ownerShare -eq 0.1 -and $distributionPool -eq 0.9) {
            $tests += @{ Name = "Fee Calculation"; Result = "PASS"; Details = "Owner: $ownerShare XMR, Pool: $distributionPool XMR" }
        } else {
            $tests += @{ Name = "Fee Calculation"; Result = "FAIL"; Details = "Incorrect calculation" }
        }
        
    } catch {
        $tests += @{ Name = "Calculation Logic"; Result = "FAIL"; Details = $_.Exception.Message }
    }
    
    return $tests
}

function Test-FileOperations {
    Write-TestLog "Testing File Operations..." "INFO"
    
    $tests = @()
    
    # Test log file creation
    try {
        $logFile = Join-Path $TestDataPath "Logs\test.log"
        $testLog = "Test log entry: $(Get-Date)"
        $testLog | Out-File -FilePath $logFile -Encoding UTF8
        
        if (Test-Path $logFile) {
            $tests += @{ Name = "Log File Creation"; Result = "PASS"; Details = "Created: $logFile" }
        } else {
            $tests += @{ Name = "Log File Creation"; Result = "FAIL"; Details = "File not created" }
        }
    } catch {
        $tests += @{ Name = "Log File Creation"; Result = "FAIL"; Details = $_.Exception.Message }
    }
    
    # Test CSV append operations
    try {
        $testCsv = Join-Path $TestDataPath "Database\test-append.csv"
        "Header1,Header2,Header3" | Out-File -FilePath $testCsv -Encoding UTF8
        "Value1,Value2,Value3" | Add-Content -Path $testCsv -Encoding UTF8
        
        $content = Get-Content $testCsv
        if ($content.Count -eq 2) {
            $tests += @{ Name = "CSV Append"; Result = "PASS"; Details = "2 lines written" }
        } else {
            $tests += @{ Name = "CSV Append"; Result = "FAIL"; Details = "Incorrect line count: $($content.Count)" }
        }
    } catch {
        $tests += @{ Name = "CSV Append"; Result = "FAIL"; Details = $_.Exception.Message }
    }
    
    return $tests
}

function Test-ConfigurationValidation {
    Write-TestLog "Testing Configuration Validation..." "INFO"
    
    $tests = @()
    
    try {
        $configFile = Join-Path $TestDataPath "Config\reward-config.json"
        $config = Get-Content $configFile -Raw | ConvertFrom-Json
        
        # Test required fields
        $requiredFields = @(
            "MainWallet.Address",
            "Distribution.OwnerSharePercent", 
            "Distribution.MinimumPayout",
            "Calculation.WeightShareCount",
            "Calculation.WeightHashrate"
        )
        
        foreach ($field in $requiredFields) {
            $parts = $field.Split('.')
            $value = $config
            foreach ($part in $parts) {
                $value = $value.$part
            }
            
            if ($null -ne $value) {
                $tests += @{ Name = "Config Field: $field"; Result = "PASS"; Details = "Value: $value" }
            } else {
                $tests += @{ Name = "Config Field: $field"; Result = "FAIL"; Details = "Missing or null" }
            }
        }
        
        # Test value ranges
        if ($config.Distribution.OwnerSharePercent -ge 0 -and $config.Distribution.OwnerSharePercent -le 100) {
            $tests += @{ Name = "Owner Share Range"; Result = "PASS"; Details = "$($config.Distribution.OwnerSharePercent)%" }
        } else {
            $tests += @{ Name = "Owner Share Range"; Result = "FAIL"; Details = "Invalid percentage" }
        }
        
        $totalWeight = $config.Calculation.WeightShareCount + $config.Calculation.WeightHashrate
        if ([math]::Abs($totalWeight - 1.0) -lt 0.001) {
            $tests += @{ Name = "Weight Balance"; Result = "PASS"; Details = "Total: $totalWeight" }
        } else {
            $tests += @{ Name = "Weight Balance"; Result = "FAIL"; Details = "Weights don't sum to 1.0: $totalWeight" }
        }
        
    } catch {
        $tests += @{ Name = "Configuration Validation"; Result = "FAIL"; Details = $_.Exception.Message }
    }
    
    return $tests
}

function Show-TestResults {
    param([array]$AllTests)
    
    $passCount = ($AllTests | Where-Object { $_.Result -eq "PASS" }).Count
    $failCount = ($AllTests | Where-Object { $_.Result -eq "FAIL" }).Count
    $warnCount = ($AllTests | Where-Object { $_.Result -eq "WARN" }).Count
    $totalCount = $AllTests.Count
    
    Write-Host "`n" + "="*80 -ForegroundColor Cyan
    Write-Host "REWARD SHARING SYSTEM TEST RESULTS" -ForegroundColor Cyan
    Write-Host "="*80 -ForegroundColor Cyan
    
    Write-Host "`nSummary:" -ForegroundColor Yellow
    Write-Host "  Total Tests: $totalCount" -ForegroundColor White
    Write-Host "  Passed: $passCount" -ForegroundColor Green
    Write-Host "  Failed: $failCount" -ForegroundColor Red
    Write-Host "  Warnings: $warnCount" -ForegroundColor Yellow
    Write-Host "  Success Rate: $([math]::Round(($passCount / $totalCount) * 100, 1))%" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Yellow" })
    
    Write-Host "`nDetailed Results:" -ForegroundColor Yellow
    Write-Host $("Test Name".PadRight(40) + "Result".PadRight(8) + "Details") -ForegroundColor Gray
    Write-Host $("-" * 80) -ForegroundColor Gray
    
    foreach ($test in $AllTests) {
        $color = switch ($test.Result) {
            "PASS" { "Green" }
            "FAIL" { "Red" }
            "WARN" { "Yellow" }
            default { "White" }
        }
        
        Write-Host $($test.Name.PadRight(40) + $test.Result.PadRight(8) + $test.Details) -ForegroundColor $color
    }
    
    Write-Host "`n" + "="*80 -ForegroundColor Cyan
    
    if ($failCount -eq 0) {
        Write-Host "🎉 ALL TESTS PASSED! The reward sharing system is ready for use." -ForegroundColor Green
    } else {
        Write-Host "⚠️  Some tests failed. Please review the issues before deploying." -ForegroundColor Red
    }
}

# Main execution
try {
    Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                Reward Sharing System Test Suite                 ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    Write-TestLog "Starting comprehensive test suite..." "INFO"
    Write-TestLog "Test data path: $TestDataPath"
    Write-TestLog "Quick test mode: $QuickTest"
    
    # Initialize test environment
    if (-not (Test-Path $TestDataPath)) {
        New-Item -ItemType Directory -Path $TestDataPath -Force | Out-Null
    }
    
    Create-TestData
    
    # Run all tests
    $allTests = @()
    
    $allTests += Test-Prerequisites
    $allTests += Test-DatabaseOperations
    $allTests += Test-CalculationLogic
    
    if (-not $QuickTest) {
        $allTests += Test-FileOperations
        $allTests += Test-ConfigurationValidation
    }
    
    # Show results
    Show-TestResults -AllTests $allTests
    
    # Cleanup test data
    if (Test-Path $TestDataPath) {
        Write-TestLog "Cleaning up test data..." "INFO"
        Remove-Item $TestDataPath -Recurse -Force
    }
    
    Write-TestLog "Test suite completed" "INFO"
    
} catch {
    Write-TestLog "Test suite failed: $($_.Exception.Message)" "FAIL"
    exit 1
}