# Image lifecycle management script

param(
    [Parameter(Mandatory=$true)]
    [string]$GalleryResourceGroup,
    [Parameter(Mandatory=$true)]
    [string]$GalleryName,
    [Parameter()]
    [int]$RetentionDays = 30,
    [Parameter()]
    [int]$MaxVersions = 3
)

function Remove-OldVersions {
    param(
        [string]$ImageDefinition
    )
    
    Write-Host "Processing image definition: $ImageDefinition"
    
    # Get all versions
    $versions = az sig image-version list `
        --resource-group $GalleryResourceGroup `
        --gallery-name $GalleryName `
        --gallery-image-definition $ImageDefinition | ConvertFrom-Json
    
    if ($versions.Count -gt $MaxVersions) {
        # Sort by creation time descending
        $sortedVersions = $versions | Sort-Object { $_.publishingProfile.publishedDate } -Descending
        
        # Keep the latest versions according to policy
        $versionsToDelete = $sortedVersions[$MaxVersions..($sortedVersions.Count-1)]
        
        foreach ($version in $versionsToDelete) {
            Write-Host "Deleting version: $($version.name)"
            az sig image-version delete `
                --resource-group $GalleryResourceGroup `
                --gallery-name $GalleryName `
                --gallery-image-definition $ImageDefinition `
                --gallery-image-version $version.name
        }
    }
    
    # Check for old versions based on date
    $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
    foreach ($version in $versions) {
        $publishDate = [DateTime]::Parse($version.publishingProfile.publishedDate)
        if ($publishDate -lt $cutoffDate) {
            Write-Host "Deleting old version: $($version.name)"
            az sig image-version delete `
                --resource-group $GalleryResourceGroup `
                --gallery-name $GalleryName `
                --gallery-image-definition $ImageDefinition `
                --gallery-image-version $version.name
        }
    }
}

# Get all image definitions
$imageDefinitions = az sig image-definition list `
    --resource-group $GalleryResourceGroup `
    --gallery-name $GalleryName | ConvertFrom-Json

# Process each definition
foreach ($definition in $imageDefinitions) {
    Remove-OldVersions -ImageDefinition $definition.name
}

# Generate report
$report = @{
    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    retentionPolicy = @{
        maxDays = $RetentionDays
        maxVersions = $MaxVersions
    }
    imageDefinitions = @()
}

foreach ($definition in $imageDefinitions) {
    $versions = az sig image-version list `
        --resource-group $GalleryResourceGroup `
        --gallery-name $GalleryName `
        --gallery-image-definition $definition.name | ConvertFrom-Json
    
    $report.imageDefinitions += @{
        name = $definition.name
        versionCount = $versions.Count
        latestVersion = ($versions | Sort-Object { $_.publishingProfile.publishedDate } -Descending)[0].name
    }
}

# Save report
$reportPath = "cleanup-report-$(Get-Date -Format 'yyyyMMdd').json"
$report | ConvertTo-Json -Depth 10 | Out-File $reportPath
Write-Host "Cleanup complete. Report saved to $reportPath"
