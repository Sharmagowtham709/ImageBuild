# Build and validation script for Azure Image Builder

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
    
    [Parameter()]
    [string]$LogPath = "build.log"
)

# Function for consistent logging
function Write-Log {
    param([string]$Message)
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    
    Write-Host $logMessage
    if ($LogPath) {
        $logMessage | Out-File -FilePath $LogPath -Append
    }
}

$ErrorActionPreference = 'Stop'
$templatePath = Join-Path $PSScriptRoot ".." "templates"

function Build-Image {
    param(
        [string]$Type,
        [string]$Version
    )
    
    try {
        Write-Log "Starting build process for image type: $Type"
        
        $template = Join-Path $templatePath "$Type.json"
        if (-not (Test-Path $template)) {
            throw "Template not found: $template"
        }

        Write-Log "Using template: $template"
        
        # Validate template JSON
        try {
            $null = Get-Content $template | ConvertFrom-Json
            Write-Log "Template validation successful"
        }
        catch {
            throw "Invalid template JSON: $_"
        }
    
    # Update template distribute section with gallery info
    $content = Get-Content $template | ConvertFrom-Json
    $content.properties.distribute[0] | Add-Member -NotePropertyName "galleryImageId" -NotePropertyValue "/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$GalleryResourceGroup/providers/Microsoft.Compute/galleries/$GalleryName/images/$Type" -Force
    $content.properties.distribute[0].runOutputName = "$($Type)_$Version"
    
    $tempTemplate = Join-Path $env:TEMP "template_$Type.json"
    $content | ConvertTo-Json -Depth 10 | Out-File $tempTemplate -Force

        # Create image version
        Write-Log "Creating image version..."
        $result = az image builder create `
            --resource-group $GalleryResourceGroup `
            --image-template $tempTemplate `
            --no-wait

        if ($LASTEXITCODE -eq 0) {
            Write-Log "Successfully initiated build for $Type version $Version"
            return $true
        }
        else {
            throw "Failed to create image version. Exit code: $LASTEXITCODE"
        }
    }
    catch {
        Write-Log "ERROR: $($_.Exception.Message)"
        Write-Error $_.Exception.Message
        return $false
    }
}

# Main execution
if ($ImageType -eq 'all') {
    $imageTypes = @('windows2022', 'ubuntu2004', 'rhel8')
    foreach ($type in $imageTypes) {
        if (Build-Image -Type $type -Version $Version) {
            Write-Host "Successfully started build for $type"
        }
    }
} else {
    if (Build-Image -Type $ImageType -Version $Version) {
        Write-Host "Successfully started build for $ImageType"
    }
}
