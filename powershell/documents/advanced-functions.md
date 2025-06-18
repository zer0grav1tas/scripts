# PowerShell Advanced Functions Guide

Advanced functions in PowerShell are designed to behave similarly to cmdlets, providing a powerful way to encapsulate logic into reusable scripts with robust functionality. These functions can leverage a range of features that are typically available to cmdlets, such as parameter binding, input validation, and pipeline support. Advanced functions are an excellent choice for creating complex scripts that need to handle various input scenarios and need the extra tools cmdlets offer.

## [CmdletBinding()] - The Foundation

By declaring `[CmdletBinding()]` at the top of your function, it can utilize cmdlet-like features such as `Write-Verbose`, `Write-Debug`, `Write-Warning`, and `Write-Error`. This also enables support for common parameters like `-Verbose`, `-Debug`, `-ErrorAction`, `-WarningAction`, and others.

```powershell
function Get-MyResource {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    Write-Verbose "Retrieving resource from $Path"
    
    try {
        if (Test-Path $Path) {
            Write-Debug "Path exists, proceeding with retrieval"
            return Get-Item $Path
        } else {
            Write-Warning "Path not found: $Path"
            return $null
        }
    } catch {
        Write-Error "Failed to retrieve resource: $($_.Exception.Message)"
        throw
    }
}

# Usage examples:
# Get-MyResource -Path "C:\temp\file.txt" -Verbose
# Get-MyResource -Path "C:\temp\file.txt" -Debug
```

### CmdletBinding Options

```powershell
function Advanced-Example {
    [CmdletBinding(
        SupportsShouldProcess = $true,  # Enables -WhatIf and -Confirm
        ConfirmImpact = 'High',         # Sets default confirmation level
        DefaultParameterSetName = 'ByName'  # Default parameter set
    )]
    param(
        [Parameter(ParameterSetName='ByName')]
        [string]$Name,
        
        [Parameter(ParameterSetName='ById')]
        [int]$Id
    )
    
    if ($PSCmdlet.ShouldProcess($Name, "Delete User")) {
        Write-Host "Deleting user: $Name"
        # Actual deletion logic here
    }
}
```

## Parameter Attributes

Advanced parameter validation and configuration options:

```powershell
function New-UserAccount {
    [CmdletBinding()]
    param(
        # Mandatory parameter with help message
        [Parameter(
            Mandatory = $true,
            HelpMessage = "Enter the username for the new account",
            Position = 0
        )]
        [ValidatePattern("^[a-zA-Z][a-zA-Z0-9_-]{2,19}$")]
        [string]$Username,
        
        # Validate against specific set of values
        [Parameter(Mandatory = $true)]
        [ValidateSet("Development", "Production", "Testing")]
        [string]$Environment,
        
        # Validate numeric range
        [Parameter()]
        [ValidateRange(1, 10)]
        [int]$Priority = 5,
        
        # Validate pattern (email format)
        [Parameter()]
        [ValidatePattern("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")]
        [string]$Email,
        
        # Validate script block
        [Parameter()]
        [ValidateScript({
            if ($_ -match "^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[a-zA-Z\d@$!%*?&]{8,}$") {
                $true
            } else {
                throw "Password must be at least 8 characters with uppercase, lowercase, and number"
            }
        })]
        [string]$Password,
        
        # Validate not null or empty
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Department,
        
        # Validate count (for arrays)
        [Parameter()]
        [ValidateCount(1, 5)]
        [string[]]$Groups,
        
        # Transform parameter (automatically convert)
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            @('Admin', 'User', 'Guest', 'PowerUser') | Where-Object { $_ -like "$wordToComplete*" }
        })]
        [string]$Role = "User"
    )
    
    Write-Verbose "Creating user account for $Username in $Environment environment"
    Write-Debug "User details: Environment=$Environment, Priority=$Priority, Role=$Role"
    
    # Function implementation here
    return @{
        Username = $Username
        Environment = $Environment
        Priority = $Priority
        Email = $Email
        Department = $Department
        Groups = $Groups
        Role = $Role
        Created = Get-Date
    }
}
```

## Dynamic Parameters

Dynamic parameters are created at runtime based on other parameter values or external conditions:

```powershell
function Connect-Service {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Development", "Production", "Testing")]
        [string]$Environment,
        
        [Parameter(Mandatory = $true)]
        [string]$ServiceName
    )
    
    dynamicparam {
        # Only require authentication token for Production environment
        if ($Environment -eq "Production") {
            # Create the parameter attribute
            $attributes = New-Object System.Management.Automation.ParameterAttribute
            $attributes.Mandatory = $true
            $attributes.HelpMessage = "Authentication token required for Production environment"
            
            # Create validation attribute
            $validateLength = New-Object System.Management.Automation.ValidateRangeAttribute(10, 100)
            
            # Create the attribute collection
            $attributesCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            $attributesCollection.Add($attributes)
            $attributesCollection.Add($validateLength)
            
            # Create the dynamic parameter
            $runtimeParam = New-Object System.Management.Automation.RuntimeDefinedParameter(
                'Token', [string], $attributesCollection
            )
            
            # Create and return the parameter dictionary
            $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
            $paramDictionary.Add('Token', $runtimeParam)
            return $paramDictionary
        }
        
        # Additional dynamic parameters for Testing environment
        if ($Environment -eq "Testing") {
            $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
            
            # Debug Mode parameter
            $debugAttrib = New-Object System.Management.Automation.ParameterAttribute
            $debugAttrib.Mandatory = $false
            $debugCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            $debugCollection.Add($debugAttrib)
            $debugParam = New-Object System.Management.Automation.RuntimeDefinedParameter(
                'DebugMode', [switch], $debugCollection
            )
            $paramDictionary.Add('DebugMode', $debugParam)
            
            return $paramDictionary
        }
    }
    
    begin {
        Write-Verbose "Connecting to $ServiceName in $Environment environment"
        
        # Access dynamic parameters
        if ($PSBoundParameters.ContainsKey('Token')) {
            Write-Debug "Using authentication token for Production"
            $token = $PSBoundParameters['Token']
        }
        
        if ($PSBoundParameters.ContainsKey('DebugMode')) {
            Write-Debug "Debug mode enabled for Testing environment"
            $debugMode = $PSBoundParameters['DebugMode']
        }
    }
    
    process {
        # Connection logic here
        $connectionString = switch ($Environment) {
            "Development" { "dev-$ServiceName.local" }
            "Testing" { "test-$ServiceName.local" }
            "Production" { "prod-$ServiceName.com" }
        }
        
        Write-Output "Connected to $connectionString"
    }
}
```

## Begin, Process, End Blocks

These script blocks manage the function lifecycle, especially useful when dealing with pipeline input:

```powershell
function Process-LogFiles {
    [CmdletBinding()]
    param(
        [Parameter(
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [Alias("FullName")]
        [string[]]$Path,
        
        [Parameter()]
        [string]$OutputPath = "C:\ProcessedLogs",
        
        [Parameter()]
        [switch]$IncludeErrorsOnly
    )
    
    begin {
        Write-Verbose "Starting log file processing..."
        $processedCount = 0
        $errorCount = 0
        $startTime = Get-Date
        
        # Ensure output directory exists
        if (-not (Test-Path $OutputPath)) {
            New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
            Write-Verbose "Created output directory: $OutputPath"
        }
        
        # Initialize results collection
        $results = @()
    }
    
    process {
        foreach ($filePath in $Path) {
            try {
                Write-Debug "Processing file: $filePath"
                
                if (-not (Test-Path $filePath)) {
                    Write-Warning "File not found: $filePath"
                    $errorCount++
                    continue
                }
                
                # Read and process log file
                $content = Get-Content $filePath
                $logEntries = $content | ForEach-Object {
                    if ($_ -match "^(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2})\s+(\w+)\s+(.+)$") {
                        [PSCustomObject]@{
                            Date = [DateTime]"$($Matches[1]) $($Matches[2])"
                            Level = $Matches[3]
                            Message = $Matches[4]
                            SourceFile = Split-Path $filePath -Leaf
                        }
                    }
                }
                
                # Filter if requested
                if ($IncludeErrorsOnly) {
                    $logEntries = $logEntries | Where-Object { $_.Level -eq "ERROR" }
                }
                
                # Save processed data
                $outputFile = Join-Path $OutputPath "processed_$(Split-Path $filePath -Leaf).csv"
                $logEntries | Export-Csv $outputFile -NoTypeInformation
                
                $results += [PSCustomObject]@{
                    SourceFile = $filePath
                    OutputFile = $outputFile
                    EntriesProcessed = $logEntries.Count
                    Status = "Success"
                }
                
                $processedCount++
                Write-Progress -Activity "Processing Log Files" -Status "Processed $processedCount files" -PercentComplete (($processedCount / ($processedCount + $errorCount)) * 100)
                
            } catch {
                Write-Error "Failed to process $filePath`: $($_.Exception.Message)"
                $results += [PSCustomObject]@{
                    SourceFile = $filePath
                    OutputFile = $null
                    EntriesProcessed = 0
                    Status = "Failed"
                    Error = $_.Exception.Message
                }
                $errorCount++
            }
        }
    }
    
    end {
        $endTime = Get-Date
        $duration = $endTime - $startTime
        
        Write-Verbose "Log file processing completed."
        Write-Verbose "Files processed: $processedCount"
        Write-Verbose "Errors encountered: $errorCount"
        Write-Verbose "Total duration: $($duration.TotalSeconds) seconds"
        
        # Return summary
        return [PSCustomObject]@{
            ProcessedFiles = $processedCount
            ErrorCount = $errorCount
            Duration = $duration
            Results = $results
            OutputPath = $OutputPath
        }
    }
}
```

## Pipeline Input - ValueFromPipeline vs ValueFromPipelineByPropertyName

### Basic Pipeline Support

```powershell
function Greet-User {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string]$Name
    )
    
    process {
        Write-Output "Hello, $Name!"
    }
}

# Usage:
"John", "Paul", "George" | Greet-User
```

### Advanced Pipeline Support with Property Binding

```powershell
function Get-UserDetails {
    [CmdletBinding()]
    param(
        [Parameter(
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [Alias("Username", "Login")]
        [string]$Name,
        
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]$Department,
        
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias("ID")]
        [int]$EmployeeId
    )
    
    process {
        Write-Verbose "Processing user: $Name"
        
        # Simulate getting user details
        [PSCustomObject]@{
            Name = $Name
            Department = $Department
            EmployeeId = $EmployeeId
            Status = "Active"
            LastLogin = Get-Date
            ProcessedBy = $env:USERNAME
        }
    }
}

# Usage with objects from pipeline:
$users = @(
    [PSCustomObject]@{ Name = "Alice"; Department = "IT"; EmployeeId = 101 }
    [PSCustomObject]@{ Username = "Bob"; Department = "HR"; ID = 102 }
    [PSCustomObject]@{ Login = "Charlie"; Department = "Finance"; EmployeeId = 103 }
)

$users | Get-UserDetails -Verbose
```

## Real-World Advanced Function Example

```powershell
function Backup-UserProfile {
    <#
    .SYNOPSIS
    Creates a backup of user profile data with compression and logging.
    
    .DESCRIPTION
    This advanced function backs up user profile directories with options for compression,
    encryption, and detailed logging. Supports pipeline input and progress reporting.
    
    .PARAMETER Username
    The username whose profile should be backed up.
    
    .PARAMETER BackupPath
    The destination path for backup files.
    
    .PARAMETER Compress
    Enable compression for backup files.
    
    .PARAMETER ExcludeTemp
    Exclude temporary files and folders from backup.
    
    .EXAMPLE
    Backup-UserProfile -Username "jdoe" -BackupPath "\\server\backups"
    
    .EXAMPLE
    Get-ADUser -Filter * | Backup-UserProfile -BackupPath "C:\Backups" -Compress -Verbose
    #>
    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'Medium'
    )]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [Alias("SamAccountName", "Name")]
        [ValidatePattern("^[a-zA-Z][a-zA-Z0-9._-]{1,19}$")]
        [string]$Username,
        
        [Parameter(Mandatory = $true)]
        [ValidateScript({
            if (Test-Path $_ -PathType Container) { $true }
            else { throw "Backup path must be a valid directory: $_" }
        })]
        [string]$BackupPath,
        
        [Parameter()]
        [switch]$Compress,
        
        [Parameter()]
        [switch]$ExcludeTemp,
        
        [Parameter()]
        [ValidateRange(1, 9)]
        [int]$CompressionLevel = 5
    )
    
    begin {
        Write-Verbose "Starting user profile backup process"
        $totalUsers = 0
        $successCount = 0
        $failureCount = 0
        $startTime = Get-Date
        
        # Initialize logging
        $logPath = Join-Path $BackupPath "backup-log-$(Get-Date -Format 'yyyyMMdd-HHmm').txt"
        "Backup process started at $startTime" | Out-File $logPath
    }
    
    process {
        $totalUsers++
        
        try {
            Write-Progress -Activity "Backing up user profiles" -Status "Processing $Username" -PercentComplete (($successCount + $failureCount) / $totalUsers * 100)
            
            $userProfilePath = "C:\Users\$Username"
            
            if (-not (Test-Path $userProfilePath)) {
                Write-Warning "Profile path not found for user: $Username"
                "WARNING: Profile not found for $Username" | Out-File $logPath -Append
                return
            }
            
            if ($PSCmdlet.ShouldProcess($Username, "Backup user profile")) {
                Write-Verbose "Backing up profile for $Username"
                
                # Create backup filename
                $timestamp = Get-Date -Format "yyyyMMdd-HHmm"
                $backupFileName = if ($Compress) {
                    "$Username-profile-$timestamp.zip"
                } else {
                    "$Username-profile-$timestamp"
                }
                
                $destinationPath = Join-Path $BackupPath $backupFileName
                
                if ($Compress) {
                    # Use compression
                    $excludePatterns = if ($ExcludeTemp) {
                        @("*\Temp\*", "*\AppData\Local\Temp\*", "*\.tmp")
                    } else {
                        @()
                    }
                    
                    Add-Type -AssemblyName System.IO.Compression.FileSystem
                    [System.IO.Compression.ZipFile]::CreateFromDirectory(
                        $userProfilePath,
                        $destinationPath,
                        [System.IO.Compression.CompressionLevel]::Optimal,
                        $false
                    )
                } else {
                    # Regular copy
                    $copyParams = @{
                        Path = $userProfilePath
                        Destination = $destinationPath
                        Recurse = $true
                        Force = $true
                    }
                    
                    if ($ExcludeTemp) {
                        $copyParams.Exclude = @("Temp", "*.tmp")
                    }
                    
                    Copy-Item @copyParams
                }
                
                # Verify backup
                if (Test-Path $destinationPath) {
                    $backupSize = if ($Compress) {
                        (Get-Item $destinationPath).Length
                    } else {
                        (Get-ChildItem $destinationPath -Recurse | Measure-Object -Property Length -Sum).Sum
                    }
                    
                    $result = [PSCustomObject]@{
                        Username = $Username
                        BackupPath = $destinationPath
                        BackupSize = [math]::Round($backupSize / 1MB, 2)
                        Compressed = $Compress.IsPresent
                        Timestamp = Get-Date
                        Status = "Success"
                    }
                    
                    Write-Output $result
                    "SUCCESS: Backed up $Username to $destinationPath ($(result.BackupSize) MB)" | Out-File $logPath -Append
                    $successCount++
                } else {
                    throw "Backup file was not created successfully"
                }
            }
        } catch {
            Write-Error "Failed to backup profile for $Username`: $($_.Exception.Message)"
            "ERROR: Failed to backup $Username - $($_.Exception.Message)" | Out-File $logPath -Append
            $failureCount++
        }
    }
    
    end {
        $endTime = Get-Date
        $duration = $endTime - $startTime
        
        $summary = @"
Backup process completed at $endTime
Duration: $($duration.TotalMinutes.ToString("F2")) minutes
Total users processed: $totalUsers
Successful backups: $successCount
Failed backups: $failureCount
"@
        
        Write-Verbose $summary
        $summary | Out-File $logPath -Append
        
        # Return summary object
        [PSCustomObject]@{
            TotalUsers = $totalUsers
            SuccessfulBackups = $successCount
            FailedBackups = $failureCount
            Duration = $duration
            LogFile = $logPath
        }
    }
}
```

## Best Practices for Advanced Functions

### 1. Always Include Help Documentation
```powershell
function My-Function {
    <#
    .SYNOPSIS
    Brief description
    
    .DESCRIPTION
    Detailed description
    
    .PARAMETER ParameterName
    Description of parameter
    
    .EXAMPLE
    Example usage
    
    .NOTES
    Additional notes
    #>
    [CmdletBinding()]
    param()
}
```

### 2. Use Proper Error Handling
```powershell
function Safe-Function {
    [CmdletBinding()]
    param([string]$Path)
    
    try {
        # Risky operation
        $result = Get-Item $Path -ErrorAction Stop
        return $result
    } catch [System.Management.Automation.ItemNotFoundException] {
        Write-Error "Path not found: $Path"
        return $null
    } catch {
        Write-Error "Unexpected error: $($_.Exception.Message)"
        throw
    }
}
```

### 3. Support Common Parameters
```powershell
function Well-Behaved-Function {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Name
    )
    
    if ($PSCmdlet.ShouldProcess($Name, "Process Item")) {
        # Do the work
        Write-Verbose "Processing $Name"
        Write-Debug "Debug information for $Name"
    }
}
```

### 4. Return Consistent Object Types
```powershell
function Get-SystemInfo {
    [CmdletBinding()]
    param([string[]]$ComputerName = $env:COMPUTERNAME)
    
    foreach ($computer in $ComputerName) {
        try {
            # Always return the same object structure
            [PSCustomObject]@{
                ComputerName = $computer
                OS = (Get-CimInstance Win32_OperatingSystem -ComputerName $computer).Caption
                Memory = [math]::Round((Get-CimInstance Win32_ComputerSystem -ComputerName $computer).TotalPhysicalMemory / 1GB, 2)
                Status = "Online"
                Error = $null
            }
        } catch {
            [PSCustomObject]@{
                ComputerName = $computer
                OS = $null
                Memory = $null
                Status = "Offline"
                Error = $_.Exception.Message
            }
        }
    }
}
```

## Summary

Advanced functions provide:
- **Cmdlet-like behavior** with common parameters
- **Robust parameter validation** and transformation
- **Pipeline support** for processing collections
- **Dynamic parameters** for conditional functionality
- **Lifecycle management** with begin/process/end blocks
- **Professional error handling** and logging capabilities

These features make advanced functions ideal for creating reusable, production-ready PowerShell tools that integrate seamlessly with the PowerShell ecosystem.