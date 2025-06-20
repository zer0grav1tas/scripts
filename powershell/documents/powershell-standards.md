# PowerShell Coding Standards and Best Practices

*A work in progress - evolving standards for professional PowerShell development*

## Naming Conventions

### 1. Use PascalCase for Functions, Variables, and Parameters
```powershell
# Good
function Get-UserAccount { }
$UserName = "JohnDoe"
$DatabaseConnection = "Server01"

# Avoid
function get_user_account { }
$userName = "JohnDoe"
$database_connection = "Server01"
```

### 2. Functions Should Follow Verb-Noun Pattern
```powershell
# Good - Use approved PowerShell verbs
Get-User
Set-Configuration  
New-Database
Remove-TempFiles
Test-Connection
Invoke-Backup

# Avoid - Non-standard verbs
Fetch-User
Configure-Settings
Create-Database
Delete-TempFiles
```

**Common Approved Verbs:**
- **Get**: Retrieve data
- **Set**: Modify data  
- **New**: Create something
- **Remove**: Delete something
- **Test**: Validate or check
- **Invoke**: Execute or run
- **Start/Stop**: Control services/processes
- **Import/Export**: Data transfer operations

## Documentation Standards

### 3. Always Add Header Comments
```powershell
<#
.SYNOPSIS
    This script performs an automated backup of selected files.

.DESCRIPTION
    The script Backup-Files.ps1 is designed to copy files from a specified source directory
    to a designated backup directory. It includes options for logging and error handling.
    
    The script validates input paths, creates backup directories if needed, and provides
    detailed logging of all operations performed.

.PARAMETER SourcePath
    The path of the directory where the source files are located.
    Must be a valid, accessible directory path.

.PARAMETER BackupPath
    The path of the directory where the files will be copied to.
    Directory will be created if it doesn't exist.

.PARAMETER LogPath
    Optional. Path for the log file. Defaults to script directory.

.PARAMETER ExcludePatterns
    Optional. Array of file patterns to exclude from backup.

.EXAMPLE
    .\Backup-Files.ps1 -SourcePath "C:\Documents" -BackupPath "D:\Backup"
    
    This command runs the script with the specified source and backup paths using default settings.

.EXAMPLE
    .\Backup-Files.ps1 -SourcePath "C:\Documents" -BackupPath "D:\Backup" -LogPath "C:\Logs\backup.log" -ExcludePatterns @("*.tmp", "*.log")
    
    This command runs the script with custom log path and excludes temporary and log files.

.INPUTS
    None. You cannot pipe objects to this script.

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns backup summary with files processed, errors encountered, and completion status.

.NOTES
    Version:        1.2
    Author:         Your Name
    Creation Date:  2024-04-21
    Last Modified:  2024-06-18
    
    Requires:       PowerShell 5.1 or later
    Dependencies:   None
    
    Change Log:
    1.0 - Initial version
    1.1 - Added exclude patterns functionality
    1.2 - Enhanced error handling and logging

.LINK
    https://github.com/yourusername/powershell-scripts

.COMPONENT
    File Management

.FUNCTIONALITY
    Backup and Archive Operations
#>
```

## Code Organization

### 4. One Task Per Script - Break Tasks into Small Units
```powershell
# Good - Focused, single-purpose scripts
.\Get-SystemInfo.ps1          # Only retrieves system information
.\Backup-UserData.ps1         # Only handles user data backup
.\Send-StatusReport.ps1       # Only sends reports

# Avoid - Monolithic scripts doing everything
.\MasterMaintenanceScript.ps1 # Does backup, cleanup, reporting, updates, etc.
```

### 5. Use Consistent Script Structure
```powershell
<#
.SYNOPSIS / .DESCRIPTION / etc.
#>

# ===============================================================================
# PARAMETERS
# ===============================================================================
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [string]$SourcePath,
    
    [Parameter(Mandatory = $true)]
    [string]$BackupPath
)

# ===============================================================================
# VARIABLES AND CONFIGURATION
# ===============================================================================
$Script:LogPath = Join-Path $PSScriptRoot "backup-$(Get-Date -Format 'yyyyMMdd-HHmm').log"
$Script:StartTime = Get-Date
$Script:ErrorCount = 0

# ===============================================================================
# FUNCTIONS
# ===============================================================================
function Write-LogMessage {
    [CmdletBinding()]
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    $logEntry | Out-File -FilePath $Script:LogPath -Append
    
    switch ($Level) {
        "INFO" { Write-Host $logEntry -ForegroundColor Green }
        "WARN" { Write-Warning $logEntry }
        "ERROR" { Write-Error $logEntry }
    }
}

function Test-Prerequisites {
    [CmdletBinding()]
    param()
    
    Write-LogMessage "Validating prerequisites..."
    
    # Validation logic here
    return $true
}

# ===============================================================================
# MAIN EXECUTION
# ===============================================================================
try {
    Write-LogMessage "Starting backup process"
    
    if (-not (Test-Prerequisites)) {
        throw "Prerequisites validation failed"
    }
    
    # Main script logic here
    
    Write-LogMessage "Backup completed successfully"
} catch {
    Write-LogMessage "Script failed: $($_.Exception.Message)" -Level "ERROR"
    exit 1
} finally {
    $duration = (Get-Date) - $Script:StartTime
    Write-LogMessage "Script execution completed in $($duration.TotalSeconds) seconds"
}
```

## Error Handling Standards

### 6. Always Use Try-Catch for Critical Operations
```powershell
# Good - Comprehensive error handling
try {
    $result = Invoke-RestMethod $apiUrl -ErrorAction Stop
    Write-LogMessage "API call successful"
} catch [System.Net.WebException] {
    Write-LogMessage "Network error: $($_.Exception.Message)" -Level "ERROR"
    # Handle network-specific errors
} catch {
    Write-LogMessage "Unexpected error: $($_.Exception.Message)" -Level "ERROR"
    throw
}

# Avoid - No error handling
$result = Invoke-RestMethod $apiUrl
```

### 7. Use Proper Error Actions
```powershell
# Good - Explicit error handling
Get-Item $path -ErrorAction Stop          # Convert to terminating error
Get-Process $name -ErrorAction SilentlyContinue  # Suppress expected errors
Copy-Item $source $dest -ErrorAction Continue    # Log but continue

# Avoid - Relying on defaults without consideration
Get-Item $path    # Unclear what happens on error
```

## Parameter and Validation Standards

### 8. Always Validate Parameters
```powershell
[CmdletBinding()]
param(
    # Good - Comprehensive validation
    [Parameter(
        Mandatory = $true,
        Position = 0,
        HelpMessage = "Enter the source directory path"
    )]
    [ValidateScript({
        if (Test-Path $_ -PathType Container) { $true }
        else { throw "Path '$_' is not a valid directory" }
    })]
    [string]$SourcePath,
    
    [Parameter()]
    [ValidateSet("Low", "Medium", "High")]
    [string]$Priority = "Medium",
    
    [Parameter()]
    [ValidateRange(1, 100)]
    [int]$RetryCount = 3
)
```

### 9. Use Meaningful Default Values
```powershell
# Good - Sensible defaults
param(
    [string]$LogPath = (Join-Path $PSScriptRoot "logs"),
    [int]$TimeoutSeconds = 30,
    [switch]$WhatIf = $false
)

# Avoid - No defaults for optional parameters
param(
    [string]$LogPath,
    [int]$TimeoutSeconds,
    [switch]$WhatIf
)
```

## Coding Style Standards

### 10. Use Consistent Indentation and Spacing
```powershell
# Good - Consistent 4-space indentation
if ($condition) {
    foreach ($item in $collection) {
        if ($item.Property -eq $value) {
            Write-Output $item
        }
    }
}

# Avoid - Inconsistent spacing
if($condition){
foreach($item in $collection){
if($item.Property-eq$value){
Write-Output $item
}}}
```

### 11. Use Splatting for Multiple Parameters
```powershell
# Good - Clean and readable
$copyParams = @{
    Path        = $sourcePath
    Destination = $destinationPath
    Recurse     = $true
    Force       = $true
    ErrorAction = "Stop"
}
Copy-Item @copyParams

# Avoid - Long parameter lines
Copy-Item -Path $sourcePath -Destination $destinationPath -Recurse -Force -ErrorAction Stop
```

### 12. Use Here-Strings for Multi-line Text
```powershell
# Good - Clean multi-line strings
$emailBody = @"
Backup Process Completed

Summary:
- Files processed: $fileCount
- Duration: $duration
- Status: $status

Please review the attached log file for details.
"@

# Avoid - Concatenated strings
$emailBody = "Backup Process Completed`n`n" + 
             "Summary:`n" + 
             "- Files processed: $fileCount`n" + 
             "- Duration: $duration`n"
```

## Performance and Best Practices

### 13. Use Pipeline Efficiently
```powershell
# Good - Efficient pipeline usage
Get-ChildItem $path -Recurse | 
    Where-Object { $_.Extension -eq '.log' } | 
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
    Remove-Item -WhatIf

# Avoid - Multiple iterations
$files = Get-ChildItem $path -Recurse
$logFiles = @()
foreach ($file in $files) {
    if ($file.Extension -eq '.log') {
        $logFiles += $file
    }
}
```

### 14. Use Approved Cmdlets Over .NET Methods When Available
```powershell
# Good - PowerShell native cmdlets
$content = Get-Content $filePath
Set-Content $outputPath -Value $processedContent

# Avoid when PowerShell alternatives exist
$content = [System.IO.File]::ReadAllText($filePath)
[System.IO.File]::WriteAllText($outputPath, $processedContent)
```

### 15. Use Write-Verbose and Write-Debug Appropriately
```powershell
function Process-Data {
    [CmdletBinding()]
    param($Data)
    
    Write-Verbose "Processing $($Data.Count) items"
    
    foreach ($item in $Data) {
        Write-Debug "Processing item: $($item.Name)"
        
        # Processing logic
        
        Write-Verbose "Completed processing: $($item.Name)"
    }
}
```

## Security Standards

### 16. Handle Credentials Securely
```powershell
# Good - Secure credential handling
$credential = Get-Credential -Message "Enter service account credentials"
Invoke-Command -ComputerName $server -Credential $credential -ScriptBlock { }

# Avoid - Plain text credentials
$password = "MyPassword123"
$username = "ServiceAccount"
```

### 17. Validate User Input
```powershell
# Good - Input validation
[ValidatePattern("^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")]
[string]$EmailAddress

[ValidateScript({
    if ($_ -match "^[a-zA-Z][a-zA-Z0-9_-]{2,19}$") { $true }
    else { throw "Username must be 3-20 characters, start with letter, contain only letters, numbers, underscore, hyphen" }
})]
[string]$Username
```

## Testing and Debugging Standards

### 18. Include WhatIf Support for Destructive Operations
```powershell
function Remove-OldLogFiles {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Path,
        [int]$DaysOld = 30
    )
    
    Get-ChildItem $Path -Recurse | 
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$DaysOld) } |
        ForEach-Object {
            if ($PSCmdlet.ShouldProcess($_.FullName, "Delete old log file")) {
                Remove-Item $_.FullName -Force
            }
        }
}
```

### 19. Use Consistent Return Objects
```powershell
# Good - Consistent object structure
function Get-BackupStatus {
    [CmdletBinding()]
    param([string]$Path)
    
    try {
        # Processing logic
        return [PSCustomObject]@{
            Path = $Path
            Status = "Success"
            FileCount = $fileCount
            TotalSize = $totalSize
            Duration = $duration
            Timestamp = Get-Date
            Error = $null
        }
    } catch {
        return [PSCustomObject]@{
            Path = $Path
            Status = "Failed"
            FileCount = 0
            TotalSize = 0
            Duration = $null
            Timestamp = Get-Date
            Error = $_.Exception.Message
        }
    }
}
```

## Summary Checklist

Before considering a PowerShell script complete:

- [ ] **Naming**: PascalCase used consistently
- [ ] **Functions**: Follow Verb-Noun pattern with approved verbs
- [ ] **Documentation**: Complete header with Synopsis, Description, Examples
- [ ] **Single Purpose**: Script does one thing well
- [ ] **Error Handling**: Try-catch blocks around critical operations
- [ ] **Parameter Validation**: All parameters properly validated
- [ ] **Logging**: Appropriate use of Write-Verbose, Write-Debug, Write-Warning
- [ ] **Security**: Credentials handled securely, input validated
- [ ] **Testing**: WhatIf support for destructive operations
- [ ] **Consistency**: Consistent indentation, spacing, and formatting
- [ ] **Performance**: Efficient use of pipeline and PowerShell idioms

---

*This document is a living standard that evolves with experience and PowerShell best practices.*