$sharePointAdminUrl = ""
$clientId = ""
$tenantId = ""
$thumbPrint = ""

$directorySiteUrl = ""
$directoryListName = ""

Connect-PnPOnline `
  -Url $sharePointAdminUrl `
  -ClientID $clientId `
  -Tenant $tenantId `
  -Thumbprint $thumbPrint

$allSharePointSites = Get-PnPTenantSite -Detailed
$allSharePointTeamSites = $allSharePointSites | Where { $_.url -Like "*/sites/*" }
# Iterate through each and get the required data
$siteConfigurationList = @()
foreach($site in $allSharePointTeamSites){
    Write-Output $site.Url
    $title = $site.Title
    $url = $site.Url
    $caPolicy = $site.ConditionalAccessPolicy
    $storageQuota = $site.StorageQuota
    $scriptsSetting = $site.DenyAddAndCustomizePages
    $description = (Get-PnPMicrosoft365Group -Identity $title).Description
    $sharing = $site.SharingCapability
    
    # Get Owners
    $siteGroupOwners = Get-PnPMicrosoft365GroupOwner -Identity $title
    $siteGroupOwnersDisplayNames = ""
    foreach($owner in $siteGroupOwners){
        $siteGroupOwnersDisplayNames += $owner.DisplayName + ";"
    }
    
    $owners = $siteGroupOwnersDisplayNames.TrimEnd(";")

    Connect-PnPOnline `
        -Url $url `
        -ClientID $clientId `
        -Tenant $tenantId `
        -Thumbprint $thumbPrint

    # Get Sensitivity Label
    $label = (Get-PnPSiteSensitivityLabel).DisplayName

    $sitesObj = [PSCustomObject]@{
        Title = $title
        Url = $url
        ConditionalAccessPolicy = $caPolicy
        StorageQuota = $storageQuota
        CustomScripts = $scriptsSetting
        Description = $description
        SharingSetting = $sharing
        Owners = $owners
        SensitivityLabel = $label
    }
    $siteConfigurationList += $sitesObj
}

# Populate SharePoint List
Connect-PnPOnline `
    -Url $directorySiteUrl `
    -ClientID $clientId `
    -Tenant $tenantId `
    -Thumbprint $thumbPrint

# Remove directory items that no longer exist
$allDirectoryItems = Get-PnPListItem -List $directoryListName
foreach($item in $allDirectoryItems){
    $listItemTitle = $item.FieldValues.Title
    $listItemId = $item.Id

    $validateItem = $null
    $validateItem = $siteConfigurationList | Where-Object { $_.Title -EQ $listItemTitle }
    if(-not ($validateItem)){
        Remove-PnPListItem -List $directoryListName -Identity $listItemId
        Write-Output "Removed Item."
    }
}

# Add new items
foreach($site in $siteConfigurationList ){
    # Check to see if item already exists
    if(-not ((Get-PnPListItem -List $directoryListName).FieldValues.Title | Where-Object { $_ -EQ $site.Title }  )){
        $includedProperties = $site | select Title, Url, Description, Owners, SensitivityLabel
        $listItemHash = @{}
        $includedProperties.PSObject.Properties | Foreach-Object {
            $listItemHash[$_.Name] = $_.Value
        }
        Add-PnPListItem -List $directoryListName -Values $listItemHash
    } else {
        Write-Output "$($site.Title) already exists."
    }
}

# Generate Error Report
$DefaultSettings = [PSCustomObject]@{
    ConditionalAccessPolicy = "AllowFullAccess"
    StorageQuota = 102400
    CustomScripts = "Disabled"
    Description = 10
    SharingSetting = "Disabled"
    Owners = 2
    SensitivityLabel = "Exist"
}

$misconfiguratedSiteCollections = $siteConfigurationList | 
    Where-Object { 
        $_.ConditionalAccessPolicy -NE $DefaultSettings.ConditionalAccessPolicy -or
        $_.StorageQuota -GT $DefaultSettings.StorageQuota -or
        $_.CustomScripts -NE $DefaultSettings.CustomScripts -or
        $_.Description.Length -LT $DefaultSettings.Description -or
        $_.SharingSetting -NE $DefaultSettings.SharingSetting -or
        $_.Owners.Count -LT $DefaultSettings.Owners -or
        [string]::IsNullOrEmpty($_.SensitivityLabel)
    } | Select-Object *, @{
        Name = 'Violations'
        Expression = { 
            @(
                if ($_.ConditionalAccessPolicy -NE $DefaultSettings.ConditionalAccessPolicy) { "Conditional Access Policy Incorrect" }
                if ($_.StorageQuota -GT $DefaultSettings.StorageQuota) { "Storage Quota Exceeded" }
                if ($_.CustomScripts -NE $DefaultSettings.CustomScripts) { "Custom Scripts Enabled" }
                if ($_.Description.Length -LT $DefaultSettings.Description) { "Description Too Short" }
                if ($_.SharingSetting -NE $DefaultSettings.SharingSetting) { "Sharing Too permissive" }
                if ($_.Owners.Count -LT $DefaultSettings.Owners) { "Insufficient Owners" }
                if ([string]::IsNullOrEmpty($_.SensitivityLabel)) { "Missing Sensitivity Label" }
            ) -join "; "
        }
    }

if($misconfiguratedSiteCollections.count -GT 0){
    $reportRows = ""

    foreach($site in $misconfiguratedSiteCollections){
        $site.Title
        $violations = ""        
        foreach($violation in $site.violations){
            $violations += "<span class='violation'>$violation</span>"
        }

        $row = "<tr>
            <td>$($site.Title)</td>
            <td><a href=$($site.Url) class='site-url'>View Site</a></td>
            <td>$($site.Owners)</td>
            <td>
                $violations
            </td>
        </tr>"

        $reportRows += $row
    }
}

$reportDate = Get-Date -Format yyyy-MM-dd

$html = Get-Content reportTemplate.html
$htmlReport = $html.replace("[DATE]", $reportDate)
$htmlReport = $htmlReport.replace("[x]", $($misconfiguratedSiteCollections.count) )
$htmlReport = $htmlReport.replace("[content]", $reportRows)   
$htmlReport | Out-File ErrorReport.html -Encoding UTF8
