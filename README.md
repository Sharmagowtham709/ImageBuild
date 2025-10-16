# Azure Image Builder Project

## Project Structure
```
azure-image-build/
├── templates/                 # Image definition templates
│   ├── win2022.json          # Windows Server 2022
│   ├── ubuntu2004.json       # Ubuntu 20.04
│   └── rhel8.json           # RHEL 8
├── scripts/                  # Build and management scripts
│   ├── setup-infrastructure.ps1  # Initial setup
│   ├── setup-rbac.ps1           # RBAC configuration
│   ├── build-image.ps1          # Image building
│   └── cleanup-images.ps1       # Image lifecycle management
├── tests/                    # Validation and compliance
│   ├── validate-image.ps1
│   └── compliance/
│       ├── windows-cis-check.ps1
│       └── linux-cis-check.sh
└── azure-pipelines.yml       # Main build pipeline
```

## Quick Start

1. Setup Infrastructure and RBAC
```powershell
# Setup infrastructure
./scripts/setup-infrastructure.ps1 `
    -SubscriptionId "<sub-id>" `
    -ResourceGroupName "ImageBuilderRG" `
    -ExistingGalleryName "<gallery-name>" `
    -ExistingGalleryRG "<gallery-rg>"

# Configure RBAC
./scripts/setup-rbac.ps1 `
    -SubscriptionId "<sub-id>" `
    -GalleryResourceGroup "<gallery-rg>" `
    -GalleryName "<gallery-name>"
```

2. Configure Azure DevOps Pipeline
- Create variable group "ImageBuilder-Variables" with:
  - galleryName
  - galleryResourceGroup
- Create service connection "Azure-Connection"
- Import and run pipeline

3. Build Images
```bash
# Build all images
az pipelines run --name image-builder

# Build specific image
az pipelines run --name image-builder --parameters imageType=windows2022
```

4. Manage Image Lifecycle
```powershell
# Cleanup old versions
./scripts/cleanup-images.ps1 `
    -GalleryResourceGroup "<gallery-rg>" `
    -GalleryName "<gallery-name>" `
    -RetentionDays 30 `
    -MaxVersions 3
```

## Maintenance

- Image validation tests are in `tests/`
- CIS compliance checks in `tests/compliance/`
- Customize image templates in `templates/`
- Pipeline configuration in `azure-pipelines.yml`

## Setup Steps

1. Infrastructure Setup
```powershell
./setup-infrastructure.ps1 `
    -SubscriptionId "<sub-id>" `
    -ResourceGroupName "ImageBuilderRG" `
    -ExistingGalleryName "<gallery-name>" `
    -ExistingGalleryRG "<gallery-rg>"
```

2. Configure Azure DevOps
- Create variable group "ImageBuilder-Variables"
- Set up service connection "Azure-Connection"
- Import pipeline from azure-pipelines.yml

3. Run Pipeline
```bash
# Build all images
az pipelines run --name image-builder

# Build specific image
az pipelines run --name image-builder --parameters imageType=windows2022
```

4. Validate Images
```powershell
./validate-image.ps1 -ImageType windows2022 -Version 1.0.0
```
