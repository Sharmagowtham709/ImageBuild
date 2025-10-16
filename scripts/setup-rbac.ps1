# RBAC configuration script for Azure Image Builder

param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    [Parameter(Mandatory=$true)]
    [string]$GalleryResourceGroup,
    [Parameter(Mandatory=$true)]
    [string]$GalleryName,
    [Parameter(Mandatory=$true)]
    [string]$IdentityName = "ImageBuilder_ManagedIdentity"
)

# Create custom role definition
$roleDefinition = @{
    Name = "Azure Image Builder Custom Role"
    Description = "Custom role for Azure Image Builder service with minimum required permissions"
    Actions = @(
        "Microsoft.Compute/images/write",
        "Microsoft.Compute/images/read",
        "Microsoft.Compute/images/delete",
        "Microsoft.Compute/galleries/read",
        "Microsoft.Compute/galleries/images/read",
        "Microsoft.Compute/galleries/images/versions/read",
        "Microsoft.Compute/galleries/images/versions/write",
        "Microsoft.Network/virtualNetworks/read",
        "Microsoft.Network/virtualNetworks/subnets/join/action"
    )
    AssignableScopes = @(
        "/subscriptions/$SubscriptionId"
    )
}

# Create role definition
$roleDefinitionJson = $roleDefinition | ConvertTo-Json -Depth 10
$roleDefinitionJson | Out-File "imagebuilder-role.json"

Write-Host "Creating custom role definition..."
$role = az role definition create --role-definition "imagebuilder-role.json" | ConvertFrom-Json

# Create managed identity
Write-Host "Creating managed identity..."
$identity = az identity create `
    --resource-group $GalleryResourceGroup `
    --name $IdentityName | ConvertFrom-Json

# Wait for role definition to propagate
Start-Sleep -Seconds 30

# Assign role to managed identity
Write-Host "Assigning role to managed identity..."
az role assignment create `
    --assignee $identity.principalId `
    --role $role.roleName `
    --scope "/subscriptions/$SubscriptionId/resourceGroups/$GalleryResourceGroup/providers/Microsoft.Compute/galleries/$GalleryName"

# Output identity details
@{
    IdentityName = $IdentityName
    PrincipalId = $identity.principalId
    ClientId = $identity.clientId
    ResourceId = $identity.id
} | ConvertTo-Json | Out-File "identity-details.json"

Write-Host "RBAC setup complete. Identity details saved to identity-details.json"
