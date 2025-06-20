<#
.SYNOPSIS
    This script demonstrates a simple GET query against Microsoft Graph API.

.DESCRIPTION
    This script will conntect to Graph API using an Entra ID App Registration Client ID and Certificate and execute a GET.

.PARAMETER TenantId
    The TenantId of the Tenant where the App Registration has been created and where the data that is being queried exists.

.PARAMETER ClientId
    The Client Id or App Id of the App Registration.

.PARAMETER CertificateThumbprint
    The thumprint of the certificate that has been added to the App Registration.

.PARAMETER GraphEndpoint
    The Graph API endpoint that you want to query.

.EXAMPLE
    .\Get-DataFromGraph.ps1 -TenantId "you tenant id" -ClientId "your client id" -CertificateThumbprint "your certificate thumbprint" -GraphEndpoint "https://graph.microsoft.com/v1.0/me"
    
.INPUTS
    None. You cannot pipe objects to this script.

.OUTPUTS
    Returns graph query results.

.NOTES
    Version:        1.0
    Author:         Zero
    Creation Date:  2025-06-20
    Last Modified:  2025-06-20
    
    Requires:       PowerShell 5.1 or later
    Dependencies:   Microsoft.Graph
    
    Change Log:
    1.0 - Initial version

.LINK
    https://github.com/zer0grav1tas/scripts/blob/main/powershell/scripts/Get-DataFromGraph.ps1

.COMPONENT
    Graph API

.FUNCTIONALITY
    Query Graph API
#>

param(
    [Parameter(Mandatory)]
    [string]$TenantId,
    
    [Parameter(Mandatory)]
    [string]$ClientId,
    
    [Parameter(Mandatory)]
    [string]$CertificateThumbprint,
    
    [Parameter(Mandatory)]
    [string]$GraphEndpoint
)

try {
    Connect-MgGraph -ClientId $ClientId -TenantId $TenantId -CertificateThumbprint $CertThumbprint -NoWelcome -ErrorAction Stop
    $Result = Invoke-MgGraphRequest -Uri $GraphEndpoint -Method GET
    Disconnect-MgGraph
    return $Result
} catch {
    Write-LogMessage "Unexpected error: $($_.Exception.Message)" -Level "ERROR"
}