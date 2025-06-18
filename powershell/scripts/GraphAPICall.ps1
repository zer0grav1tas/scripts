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

Connect-MgGraph -ClientId $ClientId -TenantId $TenantId -CertificateThumbprint $CertThumbprint -NoWelcome
$result = Invoke-MgGraphRequest -Uri $Endpoint -Method GET
Disconnect-MgGraph
return $result