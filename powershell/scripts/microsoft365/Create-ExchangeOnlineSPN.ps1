<#
.SYNOPSIS
    This script will create an Entra ID app registration, with certificate and, generate an SPN and add the SPN to an Exchange Online Role Group.

.DESCRIPTION
    This script is used when you need to grant an Entra ID app registration membership of an Exchange Online role.

    This is useful when you want to use an app registration for automation tasks within Exchange, e.g. create distribution groups.

    This script will do the following:-
    - Create an Entra ID App registration
    - Create a certificate and add the public key to the App Registration.
    - Add the relevant API permissions to the App Registration.
    - Create the SPN and add the App Reg SPN to the desired Exchange role.

.PARAMETER CertificateExpirationDate
    Mandatory. The date that the certificates should expire.

.PARAMETER CertificateDNSName
    Mandatory. The DNS name of the certificate.

.PARAMETER CertificateStore
    Optional. The location to store the certificate defaults to "cert:\CurrentUser\My".

.PARAMETER CertOutputPath
    Optional. The location where the certificates will be output. Defaults to current user's temp folder.

.PARAMETER CertificatePassword
    Mandatory. The desired password for the certificate.
    
.PARAMETER CertificateName
    Mandatory. The name of the certificate.
    
.PARAMETER AppRegistrationName
    Mandatory. The name of the app registration.
    
.PARAMETER ExchangeGroupName
    Mandatory. The name of the Exchange admin role that you want to assign the SPN to.    

.EXAMPLE
    .\Create-ExchangeOnlineSPN.ps1 `
        -CertificateExpirationDate "21/06/2026" `
        -CertificateDNSName "MyAppCert" `
        -CertOutputPath "c:\temp" `
        -CertificatePassword "FredFlintstone99!" `
        -CertificateName "MyAppCert" `
        -AppRegistrationName "MyApplication" `
        -ExchangeGroupName "Security Reader"
    
.INPUTS
    None. You cannot pipe objects to this script.

.OUTPUTS
    Returns the App Id, and SPN Id.

.NOTES
    Version:        2.0
    Author:         Zero
    Creation Date:  2025-06-21
    Last Modified:  2025-06-21
    
    Requires:       PowerShell 7 or later
    Dependencies:   Microsoft.Graph, ExchangeOnlineManagement
    Roles: "Application.ReadWrite.All, AppRoleAssignment.ReadWrite.All"
    
    Change Log:
    1.0 - Initial version
    2.0 - Bug fixes and improvements

.LINK
    https://github.com/zer0grav1tas/scripts/blob/main/powershell/scripts/Create-ExchangeOnlineSPN.ps1
#>

# ===============================================================================
# Parameters
# ===============================================================================
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [DateTime]$CertificateExpirationDate,

    [Parameter(Mandatory = $true)]
    [string]$CertificateDNSName,

    [Parameter(Mandatory = $false)]
    [string]$CertificateStore = "Cert:\CurrentUser\My",

    [Parameter(Mandatory = $false)]
    [string]$CertOutputPath = [System.IO.Path]::GetTempPath(),

    [Parameter(Mandatory = $true)]
    [string]$CertificateName,

    [Parameter(Mandatory = $true)]
    [SecureString]$CertificatePassword,

    [Parameter(Mandatory = $true)]
    [string]$AppRegistrationName,
    
    [Parameter(Mandatory = $true)]
    [string]$ExchangeGroupName
)

# ===============================================================================
# VARIABLES AND CONFIGURATION
# ===============================================================================

$ExchangeAppId = "00000002-0000-0ff1-ce00-000000000000"

# ===============================================================================
# FUNCTIONS
# ===============================================================================

function Test-Prerequisites {
    Write-Verbose "Checking prerequisites..."
    
    # Check if required modules are installed
    $RequiredModules = @('Microsoft.Graph.Authentication', 'Microsoft.Graph.Applications', 'ExchangeOnlineManagement')
    
    foreach ($Module in $RequiredModules) {
        if (-not (Get-Module -ListAvailable -Name $Module)) {
            throw "Required module '$Module' is not installed. Please install it using: Install-Module -Name $Module"
        }
    }
    
    # Validate output path
    if (-not (Test-Path $CertOutputPath)) {
        try {
            New-Item -Path $CertOutputPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
            Write-Verbose "Created output directory: $CertOutputPath"
        } catch {
            throw "Cannot create or access output path: $CertOutputPath. Error: $($_.Exception.Message)"
        }
    }
    
    # Validate expiration date
    if ($CertificateExpirationDate -le (Get-Date)) {
        throw "Certificate expiration date must be in the future."
    }
}

function New-SelfSignedCertificateAdvanced {
    [CmdletBinding()]
    param(
        [DateTime]$ExpirationDate,
        [string]$DnsName,
        [string]$Store,
        [string]$OutputPath,
        [string]$Name,
        [SecureString]$Password
    )
    
    Write-Verbose "Creating self-signed certificate..."
    
    try {
        $SelfSignedCert = New-SelfSignedCertificate `
            -DnsName $DnsName `
            -CertStoreLocation $Store `
            -NotAfter $ExpirationDate `
            -KeySpec KeyExchange `
            -KeyLength 2048 `
            -KeyAlgorithm RSA `
            -HashAlgorithm SHA256 `
            -Subject "CN=$DnsName" `
            -ErrorAction Stop
            
        Write-Verbose "Certificate created with thumbprint: $($SelfSignedCert.Thumbprint)"
    } catch {
        throw "Failed to create certificate: $($_.Exception.Message)"
    }

    # Export Private Key (PFX)
    try {
        $PfxPath = Join-Path $OutputPath "$Name.pfx"
        $SelfSignedCert | Export-PfxCertificate -FilePath $PfxPath -Password $Password -ErrorAction Stop | Out-Null
        Write-Verbose "Private key exported to: $PfxPath"
    } catch {
        throw "Unable to export private key: $($_.Exception.Message)"
    }

    # Export Public Key (CER)
    try {
        $CerPath = Join-Path $OutputPath "$Name.cer"
        $SelfSignedCert | Export-Certificate -FilePath $CerPath -ErrorAction Stop | Out-Null
        Write-Verbose "Public key exported to: $CerPath"
    } catch {
        throw "Unable to export public key: $($_.Exception.Message)"
    }

    return $SelfSignedCert
}

function New-EntraAppRegistration {
    [CmdletBinding()]
    param(
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,
        [string]$AppName,
        [string]$OutputPath,
        [string]$CertName
    )
    
    Write-Verbose "Creating Entra ID App Registration..."
    
    try {
        # Check if app already exists
        $ExistingApp = Get-MgApplication -Filter "DisplayName eq '$AppName'" -ErrorAction SilentlyContinue
        if ($ExistingApp) {
            throw "An application with the name '$AppName' already exists."
        }
        
        # Create App Registration with certificate
        $AppParams = @{
            DisplayName = $AppName
            KeyCredentials = @(
                @{
                    Type = "AsymmetricX509Cert"
                    Usage = "Verify"
                    Key = $Certificate.RawData
                    DisplayName = "$CertName Certificate"
                }
            )
        }     
        
        $Application = New-MgApplication @AppParams -ErrorAction Stop
        Write-Verbose "App registration created with ID: $($Application.Id)"
        
        # Create Service Principal
        $ServicePrincipal = New-MgServicePrincipal -AppId $Application.AppId -ErrorAction Stop
        Write-Verbose "Service Principal created with ID: $($ServicePrincipal.Id)"
        
    } catch {
        throw "Failed to create app registration: $($_.Exception.Message)"
    }

    # Add Exchange API permissions
    try {
        Write-Verbose "Adding Exchange API permissions..."
        
        $ExchangeApp = Get-MgServicePrincipal -Filter "DisplayName eq 'Office 365 Exchange Online'" -ErrorAction Stop
        $ExchangeManagePermission = $ExchangeApp.AppRoles | Where-Object { $_.Value -eq "Exchange.ManageAsApp" }

        if (-not $ExchangeManagePermission) {
            throw "Exchange.ManageAsApp permission not found in Office 365 Exchange Online service principal!"
        }

        $ApiPermission = @{
            RequiredResourceAccess = @(
                @{
                    ResourceAppId = $ExchangeApp.AppId
                    ResourceAccess = @(
                        @{
                            Id = $ExchangeManagePermission.Id
                            Type = "Role"
                        }
                    )
                }
            )
        }
    
        Update-MgApplication -ApplicationId $Application.Id @ApiPermission -ErrorAction Stop
        Write-Verbose "API permissions added successfully"
        
    } catch {
        # Clean up on failure
        try {
            Remove-MgApplication -ApplicationId $Application.Id -ErrorAction SilentlyContinue
        } catch { }
        throw "Failed to add API permissions: $($_.Exception.Message)"
    }

    return @{
        Application = $Application
        ServicePrincipal = $ServicePrincipal
    }
}

function Add-SPNToExchangeRole {
    [CmdletBinding()]
    param(
        [string]$AppId,
        [string]$DisplayName,
        [string]$RoleGroupName
    )
    
    Write-Verbose "Adding SPN to Exchange Online role group..."
    
    try {
        # Create Service Principal in Exchange Online
        $ExchangeSPN = New-ServicePrincipal -AppId $AppId -DisplayName $DisplayName -ErrorAction Stop
        Write-Verbose "Exchange Service Principal created: $($ExchangeSPN.Identity)"
        
        # Add to role group
        Add-RoleGroupMember -Identity $RoleGroupName -Member $ExchangeSPN.Identity -ErrorAction Stop
        Write-Verbose "Added SPN to role group: $RoleGroupName"
        
        return $ExchangeSPN
        
    } catch {
        throw "Failed to add SPN to Exchange role: $($_.Exception.Message)"
    }
}

function Write-Summary {
    param(
        [object]$Application,
        [object]$ServicePrincipal,
        [object]$ExchangeSPN,
        [string]$RoleGroup,
        [string]$CertPath
    )
    
    Write-Host "`n" -ForegroundColor Green
    Write-Host "=====================================" -ForegroundColor Green
    Write-Host "     DEPLOYMENT SUMMARY" -ForegroundColor Green
    Write-Host "=====================================" -ForegroundColor Green
    Write-Host "App Registration Name: " -NoNewline -ForegroundColor Yellow
    Write-Host $Application.DisplayName -ForegroundColor White
    Write-Host "Application ID: " -NoNewline -ForegroundColor Yellow
    Write-Host $Application.AppId -ForegroundColor White
    Write-Host "Service Principal ID: " -NoNewline -ForegroundColor Yellow
    Write-Host $ServicePrincipal.Id -ForegroundColor White
    Write-Host "Exchange Role Group: " -NoNewline -ForegroundColor Yellow
    Write-Host $RoleGroup -ForegroundColor White
    Write-Host "Certificate Location: " -NoNewline -ForegroundColor Yellow
    Write-Host $CertPath -ForegroundColor White
    Write-Host "=====================================" -ForegroundColor Green
    Write-Host "`nIMPORTANT: Admin consent is required for the API permissions!" -ForegroundColor Red
    Write-Host "Visit: https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/CallAnAPI/appId/$($Application.AppId)" -ForegroundColor Cyan
}

# ===============================================================================
# MAIN EXECUTION
# ===============================================================================

try {
    Write-Host "Starting Exchange Online SPN creation process..." -ForegroundColor Green
    
    # Check prerequisites
    Test-Prerequisites
    
    # Connect to services
    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
    Connect-MgGraph -Scopes "Application.ReadWrite.All", "AppRoleAssignment.ReadWrite.All" -NoWelcome
    
    Write-Host "Connecting to Exchange Online..." -ForegroundColor Yellow
    Connect-ExchangeOnline -ShowBanner:$false
    
    # Create certificate
    Write-Host "Creating self-signed certificate..." -ForegroundColor Yellow
    $Certificate = New-SelfSignedCertificateAdvanced -ExpirationDate $CertificateExpirationDate -DnsName $CertificateDNSName -Store $CertificateStore -OutputPath $CertOutputPath -Name $CertificateName -Password $CertificatePassword
    
    # Create app registration
    Write-Host "Creating Entra ID App Registration..." -ForegroundColor Yellow
    $AppObjects = New-EntraAppRegistration -Certificate $Certificate -AppName $AppRegistrationName -OutputPath $CertOutputPath -CertName $CertificateName
    
    # Wait for propagation
    Write-Host "Waiting for Azure AD propagation..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
    
    # Add to Exchange role
    Write-Host "Adding SPN to Exchange Online role group..." -ForegroundColor Yellow
    $ExchangeSPN = Add-SPNToExchangeRole -AppId $AppObjects.Application.AppId -DisplayName $AppObjects.Application.DisplayName -RoleGroupName $ExchangeGroupName
    
    # Display summary
    Write-Summary -Application $AppObjects.Application -ServicePrincipal $AppObjects.ServicePrincipal -ExchangeSPN $ExchangeSPN -RoleGroup $ExchangeGroupName -CertPath $CertOutputPath
    
    Write-Host "`nTask completed successfully!" -ForegroundColor Green
    
} catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    Write-Host "Please check the error details above and try again." -ForegroundColor Red
    exit 1
} finally {
    # Disconnect sessions
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    } catch { }
}