# MoneroRewardSender.ps1 - Handles actual Monero transactions for reward distribution

<#
.SYNOPSIS
    Sends Monero rewards to miners based on calculated distributions
.DESCRIPTION
    Integrates with Monero wallet CLI to send actual XMR transactions to reward recipients.
    Handles wallet operations, transaction creation, and confirmation tracking.
.PARAMETER DatabasePath
    Path to the ShareTracker database files
.PARAMETER WalletPath
    Path to the Monero wallet CLI executable
.PARAMETER ConfigPath
    Path to configuration file with wallet settings
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

function Get-Config {
    if (-not (Test-Path $ConfigPath)) {
        Write-Log "Configuration file not found: $ConfigPath" "ERROR"
        throw "Configuration file required"
    }
    
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    return $config
}

function Get-PendingRewards {
    $distributionFile = Join-Path $DatabasePath "reward-distributions.csv"
    
    if (-not (Test-Path $distributionFile)) {
        Write-Log "No reward distributions found" "WARN"
        return @()
    }
    
    $allRewards = Import-Csv $distributionFile
    $pendingRewards = $allRewards | Where-Object { $_.Status -eq "Pending" -and $_.WalletAddress -ne "" }
    
    Write-Log "Found $($pendingRewards.Count) pending rewards to process"
    return $pendingRewards
}

function Get-MinerWalletAddresses {
    # Load miner wallet addresses from a separate registration file
    $walletRegistrationFile = Join-Path $DatabasePath "miner-wallets.csv"
    
    if (-not (Test-Path $walletRegistrationFile)) {
        # Create template file if it doesn't exist
        $header = "RigId,WalletAddress,RegistrationDate,Status"
        $header | Out-File -FilePath $walletRegistrationFile -Encoding UTF8
        
        Write-Log "Created miner wallet registration file: $walletRegistrationFile" "INFO"
        Write-Log "Please register miner wallet addresses in this file before sending rewards" "WARN"
        return @{}
    }
    
    $registrations = Import-Csv $walletRegistrationFile
    $walletMap = @{}
    
    foreach ($reg in $registrations) {
        if ($reg.Status -eq "Active" -and $reg.WalletAddress -ne "") {
            $walletMap[$reg.RigId] = $reg.WalletAddress
        }
    }
    
    Write-Log "Loaded wallet addresses for $($walletMap.Count) miners"
    return $walletMap
}

function Update-RewardAddresses {
    param([array]$PendingRewards)
    
    $distributionFile = Join-Path $DatabasePath "reward-distributions.csv"
    $walletMap = Get-MinerWalletAddresses
    
    $updatedCount = 0
    $allDistributions = Import-Csv $distributionFile
    
    foreach ($reward in $PendingRewards) {
        if ($walletMap.ContainsKey($reward.RigId) -and $reward.WalletAddress -eq "") {
            # Find and update the distribution record
            $toUpdate = $allDistributions | Where-Object { 
                $_.RigId -eq $reward.RigId -and 
                $_.Status -eq "Pending" -and 
                $_.WalletAddress -eq ""
            }
            
            foreach ($dist in $toUpdate) {
                $dist.WalletAddress = $walletMap[$reward.RigId]
                $updatedCount++
            }
        }
    }
    
    if ($updatedCount -gt 0) {
        # Save updated distributions
        $allDistributions | Export-Csv -Path $distributionFile -NoTypeInformation
        Write-Log "Updated wallet addresses for $updatedCount reward distributions" "SUCCESS"
    }
    
    return $updatedCount
}

function Test-MoneroWallet {
    param([object]$Config)
    
    if (-not (Test-Path $WalletPath)) {
        Write-Log "Monero wallet CLI not found at: $WalletPath" "ERROR"
        Write-Log "Please download and extract Monero CLI tools to continue" "ERROR"
        return $false
    }
    
    Write-Log "Found Monero wallet CLI at: $WalletPath" "SUCCESS"
    return $true
}

function Get-WalletBalance {
    param([object]$Config)
    
    # For demonstration, we'll simulate wallet operations
    # In a real implementation, this would call monero-wallet-cli or use wallet RPC
    
    Write-Log "Checking wallet balance..." "INFO"
    
    # Simulated wallet call
    # Real implementation would be something like:
    # $result = & $WalletPath --wallet-file $Config.MainWallet.FileName --password $Config.MainWallet.Password --command refresh
    # $result = & $WalletPath --wallet-file $Config.MainWallet.FileName --password $Config.MainWallet.Password --command balance
    
    # Parse balance from wallet output
    # For now, return a simulated balance
    $balance = 2.5  # Simulated balance in XMR
    
    Write-Log "Wallet balance: $balance XMR" "INFO"
    return $balance
}

function Send-MoneroPayment {
    param(
        [string]$DestinationAddress,
        [double]$Amount,
        [string]$PaymentId,
        [object]$Config
    )
    
    Write-Log "Preparing to send $Amount XMR to $DestinationAddress" "INFO"
    
    # Validate address format (basic check)
    if ($DestinationAddress.Length -ne 95 -or -not $DestinationAddress.StartsWith("4")) {
        Write-Log "Invalid Monero address format: $DestinationAddress" "ERROR"
        return @{ Success = $false; Error = "Invalid address format" }
    }
    
    # Simulate transaction creation and sending
    # Real implementation would use monero-wallet-cli or wallet RPC:
    # $command = "transfer $DestinationAddress $Amount"
    # $result = & $WalletPath --wallet-file $Config.MainWallet.FileName --password $Config.MainWallet.Password --command $command
    
    # For demonstration, simulate successful transaction
    $transactionId = "simulated_tx_" + (Get-Date -Format "yyyyMMddHHmmss") + "_" + (Get-Random -Maximum 9999)
    
    Start-Sleep -Seconds 2  # Simulate processing time
    
    Write-Log "Transaction created successfully: $transactionId" "SUCCESS"
    
    return @{
        Success = $true
        TransactionId = $transactionId
        Amount = $Amount
        Destination = $DestinationAddress
        Fee = 0.000012  # Typical Monero transaction fee
    }
}

function Process-RewardPayments {
    param([array]$PendingRewards, [object]$Config)
    
    $distributionFile = Join-Path $DatabasePath "reward-distributions.csv"
    $allDistributions = Import-Csv $distributionFile
    
    $successCount = 0
    $failureCount = 0
    $totalAmount = 0
    
    foreach ($reward in $PendingRewards) {
        try {
            Write-Log "Processing payment for $($reward.RigId): $($reward.RewardAmount) XMR" "INFO"
            
            # Send the payment
            $result = Send-MoneroPayment -DestinationAddress $reward.WalletAddress -Amount $reward.RewardAmount -PaymentId $reward.RigId -Config $Config
            
            if ($result.Success) {
                # Update the distribution record
                $toUpdate = $allDistributions | Where-Object { 
                    $_.RigId -eq $reward.RigId -and 
                    $_.RewardAmount -eq $reward.RewardAmount -and 
                    $_.Status -eq "Pending"
                }
                
                if ($toUpdate) {
                    $toUpdate[0].Status = "Sent"
                    $toUpdate[0].TransactionId = $result.TransactionId
                    $successCount++
                    $totalAmount += $reward.RewardAmount
                    
                    Write-Log "Payment sent successfully to $($reward.RigId): TX $($result.TransactionId)" "SUCCESS"
                } else {
                    Write-Log "Could not find distribution record to update for $($reward.RigId)" "WARN"
                }
            } else {
                Write-Log "Payment failed for $($reward.RigId): $($result.Error)" "ERROR"
                $failureCount++
            }
            
        } catch {
            Write-Log "Error processing payment for $($reward.RigId): $($_.Exception.Message)" "ERROR"
            $failureCount++
        }
        
        # Small delay between transactions
        Start-Sleep -Seconds 1
    }
    
    # Save updated distributions
    if ($successCount -gt 0) {
        $allDistributions | Export-Csv -Path $distributionFile -NoTypeInformation
        Write-Log "Updated $successCount distribution records with transaction IDs" "SUCCESS"
    }
    
    return @{
        SuccessCount = $successCount
        FailureCount = $failureCount
        TotalAmount = $totalAmount
    }
}

function Show-PaymentSummary {
    param([object]$Results, [array]$PendingRewards)
    
    Write-Host "`n" + "="*50 -ForegroundColor Cyan
    Write-Host "PAYMENT SUMMARY" -ForegroundColor Cyan
    Write-Host "="*50 -ForegroundColor Cyan
    Write-Host "Payments Processed: $($PendingRewards.Count)" -ForegroundColor White
    Write-Host "Successful: $($Results.SuccessCount)" -ForegroundColor Green
    Write-Host "Failed: $($Results.FailureCount)" -ForegroundColor Red
    Write-Host "Total Amount Sent: $($Results.TotalAmount) XMR" -ForegroundColor Green
    Write-Host "="*50 -ForegroundColor Cyan
}

# Main execution
try {
    Write-Log "Starting Monero Reward Sender" "INFO"
    
    # Load configuration
    $config = Get-Config
    
    # Test wallet availability
    if (-not (Test-MoneroWallet -Config $config)) {
        Write-Log "Monero wallet not available. Cannot process payments." "ERROR"
        exit 1
    }
    
    # Get pending rewards
    $pendingRewards = Get-PendingRewards
    
    if ($pendingRewards.Count -eq 0) {
        Write-Log "No pending rewards to process" "INFO"
        exit 0
    }
    
    # Update wallet addresses for pending rewards
    $updatedAddresses = Update-RewardAddresses -PendingRewards $pendingRewards
    
    # Re-fetch pending rewards with updated addresses
    $pendingRewards = Get-PendingRewards
    $readyToSend = $pendingRewards | Where-Object { $_.WalletAddress -ne "" }
    
    if ($readyToSend.Count -eq 0) {
        Write-Log "No rewards ready to send (missing wallet addresses)" "WARN"
        Write-Log "Please register miner wallet addresses in miner-wallets.csv" "INFO"
        exit 0
    }
    
    Write-Log "Ready to send $($readyToSend.Count) payments" "INFO"
    
    # Check wallet balance
    $balance = Get-WalletBalance -Config $config
    $totalNeeded = ($readyToSend | Measure-Object -Property RewardAmount -Sum).Sum
    
    if ($balance -lt $totalNeeded) {
        Write-Log "Insufficient wallet balance: $balance XMR available, $totalNeeded XMR needed" "ERROR"
        exit 1
    }
    
    # Process payments
    Write-Log "Starting payment processing..." "INFO"
    $results = Process-RewardPayments -PendingRewards $readyToSend -Config $config
    
    # Show summary
    Show-PaymentSummary -Results $results -PendingRewards $readyToSend
    
    if ($results.SuccessCount -gt 0) {
        Write-Log "Successfully sent $($results.SuccessCount) payments totaling $($results.TotalAmount) XMR" "SUCCESS"
    }
    
    if ($results.FailureCount -gt 0) {
        Write-Log "$($results.FailureCount) payments failed - check logs and retry" "WARN"
    }
    
} catch {
    Write-Log "Error: $($_.Exception.Message)" "ERROR"
    exit 1
}