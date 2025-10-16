# PowerShell script to set up test environment and validate images

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('windows2022', 'ubuntu2004', 'rhel8', 'all')]
    [string]$ImageType,
    
    [Parameter(Mandatory=$true)]
    [string]$Version,
    
    [Parameter(Mandatory=$true)]
    [string]$GalleryName,
    
    [Parameter(Mandatory=$true)]
    [string]$GalleryResourceGroup,
    
    [string]$TestResourceGroup = "ImageTestRG",
    [string]$Location = "eastus",
    [string]$VMSize = "Standard_D2s_v3"
)

$ErrorActionPreference = 'Stop'

function Test-Image {
    param(
        [string]$Type,
        [string]$Version
    )
    
    $imageId = "/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$GalleryResourceGroup/providers/Microsoft.Compute/galleries/$GalleryName/images/$Type/versions/$Version"
    $vmName = "test-$Type-$Version".ToLower()
    
    Write-Host "Testing image: $Type version $Version"`
    --generate-ssh-keys `
    --size $VMSize

# Run validation tests
$testResults = @()

# Test 1: Verify Azure Monitor Agent
$amaStatus = az vm extension show `
    --resource-group $ResourceGroup `
    --vm-name $VMName `
    --name AzureMonitorAgent
$testResults += @{
    "Test" = "Azure Monitor Agent"
    "Status" = if ($amaStatus) { "Installed" } else { "Missing" }
}

# Test 2: Check Security Configuration
$securityStatus = az vm run-command invoke `
    --resource-group $ResourceGroup `
    --name $VMName `
    --command-id RunShellScript `
    --scripts @"
        if [ -f /etc/ssh/sshd_config ]; then
            grep PermitRootLogin /etc/ssh/sshd_config
            grep PasswordAuthentication /etc/ssh/sshd_config
        elif [ -f C:\\Windows\\System32\\config\\system ]; then
            echo "Windows System"
            Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
        fi
"@
$testResults += @{
    "Test" = "Security Configuration"
    "Status" = "See detailed output"
    "Details" = $securityStatus
}

# Test 3: Check Updates
$updateStatus = az vm run-command invoke `
    --resource-group $ResourceGroup `
    --name $VMName `
    --command-id RunShellScript `
    --scripts "if command -v apt-get; then apt list --upgradable; elif command -v dnf; then dnf check-update; else echo 'Windows Update Status'; fi"
$testResults += @{
    "Test" = "System Updates"
    "Status" = "See detailed output"
    "Details" = $updateStatus
}

# Output results
$testResults | Format-Table -AutoSize

# Cleanup (optional)
# az group delete --name $ResourceGroup --yes --no-wait
