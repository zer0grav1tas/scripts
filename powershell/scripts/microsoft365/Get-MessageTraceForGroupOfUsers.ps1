<#
.SYNOPSIS
    This script gets the inbound and outbound messages for all members of an Exchange Online Distribution Group.

.DESCRIPTION
    This script will use the Exchange PowerShell module to get members of a Distribution Group, and pass this list into a Get-MessageTrace query to get a count of the emails sent and recieved by this group.
    
.PARAMETER Organization
    The name of your Entra organization.

.PARAMETER ClientId
    The Client Id or App Id of the App Registration.

.PARAMETER CertificateThumbprint
    The thumprint of the certificate that has been added to the App Registration.

.PARAMETER DistributionGroup
    The name of the Distribution group you want to query.

.PARAMETER StartDateTime
    The start date and time that the query should return results from in format "MM/DD/YYYY HH:MM AM/PM"

.PARAMETER EndDateTime
    The end date and time that the query should return results from in format "MM/DD/YYYY HH:MM AM/PM"

.EXAMPLE
    .\Get-MessageTraceForGroupOfUsers.ps1 Organizaation "your organization name" `
        -ClientId "your client id" `
        -CertificateThumbprint "your certificate thumbprint" `
        -DistributionGroup "QueryGroup" `
        -StartDateTime "06/20/2025 09:00 AM" `
        -EndDateTime "06/20/2025 05:00 PM"
    
.INPUTS
    None. You cannot pipe objects to this script.

.OUTPUTS
    Returns counts of in and out messages

.NOTES
    Version:        1.0
    Author:         Zero
    Creation Date:  2025-06-20
    Last Modified:  2025-06-20
    
    Requires:       PowerShell 5.1 or later
    Dependencies:   ExchangeOnlineManagement
    
    Change Log:
    1.0 - Initial version

.LINK
    https://github.com/zer0grav1tas/scripts/blob/main/powershell/scripts/Get-DataFromGraph.ps1

.COMPONENT
    Graph API

.FUNCTIONALITY
    Query Graph API
#>

params(
    [Parameter(Mandatory)]
    [string]$Organization,
    
    [Parameter(Mandatory)]
    [string]$ClientId,
    
    [Parameter(Mandatory)]
    [string]$CertificateThumbprint,
    
    [Parameter(Mandatory)]
    [string]$DistributionGroup,

    [Parameter(Mandatory)]
    [string]$StartDateTime,

    [Parameter(Mandatory)]
    [string]$EndDateTime
)

# ===============================================================================
# VARIABLES AND CONFIGURATION
# ===============================================================================
$MembersList = @()

# ===============================================================================
# Connect to Exchange Online
# ===============================================================================

Connect-ExchangeOnline `
    -CertificateThumbprint $CertificateThumbprint `
    -AppId $ClientId `
    -Organization $Organization

# ===============================================================================
# MAIN EXECUTION
# ===============================================================================

# Get members of the Distribution Group
try {
    $members = Get-DistributionGroupMember $DistributionGroup -ErrorAction Stop
} catch {
    Write-Error "Error getting Distribution Group: $($_.Exception.Message)" -Level "ERROR"
}

# Add PrimarySMTP addresses to list.
$MembersList = foreach($member in $members){
    $member.PrimarySMTPAddress
}

# Run message trace
try{
    
    # Validate that Distribution Group contains members
    if($MembersList.count -LE 0){
        throw "No members in Distribution Group"
    }

    # Validate date format
    $StartDate = [DateTime]::Parse($StartDateTime)
    $EndDate = [DateTime]::Parse($EndDateTime)
    
    if ($StartDate -gt $EndDate) {
        throw "Start date cannot be after end date"
    }

    $SentMessageTrace = Get-MessageTrace -SenderAddress $MembersList -StartDate $StartDateTime -EndDate $EndDateTime -ErrorAction Stop
    $ReceivedMessageTrace = Get-MessageTrace RecipientAddress $MembersList -StartDate $StartDateTime -EndDate $EndDateTime -ErrorAction Stop
    
    $Record = [PSCustomObject]@{
        DistributionGroup = $DistributionGroup
        MemberCount = $MembersList.Count
        TimeRange = "$StartDateTime to $EndDateTime"
        MessagesSent = $SentMessageTrace.Count
        MessagesReceived = $ReceivedMessageTrace.Count
        Timestamp = Get-Date
    }

    Write-Output $Record
} catch {
    Write-Error "Message trace failed: $($_.Exception.Message)" -Level "ERROR"
    return $null
}