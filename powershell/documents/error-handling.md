# PowerShell Error Handling Guide

Error handling in PowerShell is crucial for writing robust and reliable scripts, especially in production environments where unexpected issues can arise. PowerShell provides several mechanisms to help manage and handle errors effectively.

## Types of Errors in PowerShell

**Terminating Errors:** These errors stop execution unless they are caught in a try-catch block. They typically arise from cmdlet calls that explicitly throw exceptions or from calling the throw keyword in scripts.

**Non-Terminating Errors:** These are more common and occur when a command can continue execution even in the face of errors. For example, if you attempt to process several files and one file is not accessible, a non-terminating error might occur for that file while others are still processed.

## -ErrorAction Parameter

Most cmdlets support the `-ErrorAction` parameter, which allows you to specify how PowerShell should handle errors for that specific command.

```powershell
Get-Item "nonexistentfile.txt" -ErrorAction Stop
```

### Options for -ErrorAction:

- **Stop:** Treats the error as a terminating error.
- **Continue (default for most cmdlets):** Continues execution, reporting the error at the command line.
- **SilentlyContinue:** Ignores the error and continues execution without any error message.
- **Inquire:** Asks the user what to do for each error.

### Practical Examples:

```powershell
# Continue - shows error but keeps going
Get-ChildItem "C:\BadPath", "C:\Windows" -ErrorAction Continue

# SilentlyContinue - useful for testing file existence
$fileExists = Get-Item "test.txt" -ErrorAction SilentlyContinue
if ($fileExists) { "File found" } else { "File not found" }

# Stop - converts non-terminating error to terminating error
Get-Item "nonexistentfile.txt" -ErrorAction Stop  # This will throw an exception
```

## $ErrorActionPreference

Set script-wide error handling behavior:

```powershell
# Set for entire script
$ErrorActionPreference = "Stop"  # All errors become terminating
$ErrorActionPreference = "Continue"  # Default behavior
$ErrorActionPreference = "SilentlyContinue"  # Suppress all error messages

# Best practice: Save and restore original preference
$originalErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Stop"

# Your script logic here

# Restore original setting
$ErrorActionPreference = $originalErrorActionPreference
```

## Try-Catch-Finally

```powershell
try {
    # Code that might cause an error
    Get-Item "nonexistentfile.txt" -ErrorAction Stop
} catch {
    # Code to handle the error
    Write-Error "The file was not found."
} finally {
    # Code that always runs after the try and catch blocks, regardless of whether an error occurred
    Write-Host "Operation attempted."
}
```

### Capturing Detailed Error Information

```powershell
try {
    Get-Item "nonexistentfile.txt" -ErrorAction Stop
} catch {
    Write-Host "Error occurred: $($_.Exception.Message)"
    Write-Host "Error type: $($_.Exception.GetType().Name)"
    Write-Host "Line number: $($_.InvocationInfo.ScriptLineNumber)"
    Write-Host "Command: $($_.InvocationInfo.MyCommand)"
}
```

### Handling Specific Exception Types

```powershell
try {
    # Some operation that might fail
    Invoke-RestMethod "https://api.example.com/data" -ErrorAction Stop
} catch [System.Net.WebException] {
    Write-Host "Network error occurred: $($_.Exception.Message)"
} catch [System.UnauthorizedAccessException] {
    Write-Host "Access denied: $($_.Exception.Message)"
} catch {
    Write-Host "Unexpected error: $($_.Exception.Message)"
}
```

## Best Practices for Production Scripts

### 1. Logging Error Details

```powershell
function Write-ErrorLog {
    param(
        [string]$Message,
        [string]$LogPath = "C:\Logs\script-errors.log"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - ERROR: $Message" | Out-File -FilePath $LogPath -Append
}

try {
    # Your code here
    Get-Item "nonexistentfile.txt" -ErrorAction Stop
} catch {
    $errorMessage = "Failed to get file: $($_.Exception.Message)"
    Write-ErrorLog -Message $errorMessage
    Write-Host $errorMessage -ForegroundColor Red
}
```

### 2. Graceful Degradation

```powershell
function Get-FileWithFallback {
    param(
        [string]$PrimaryPath,
        [string]$BackupPath
    )
    
    try {
        return Get-Item $PrimaryPath -ErrorAction Stop
    } catch {
        Write-Warning "Primary file not found, trying backup location"
        try {
            return Get-Item $BackupPath -ErrorAction Stop
        } catch {
            throw "Neither primary nor backup file could be found"
        }
    }
}
```

### 3. Validation and Early Exit

```powershell
function Process-Files {
    param(
        [string[]]$FilePaths
    )
    
    # Validate input early
    if (-not $FilePaths -or $FilePaths.Count -eq 0) {
        throw "No file paths provided"
    }
    
    foreach ($path in $FilePaths) {
        if (-not (Test-Path $path)) {
            Write-Warning "Skipping non-existent file: $path"
            continue
        }
        
        try {
            # Process the file
            $content = Get-Content $path -ErrorAction Stop
            # Do something with content
        } catch {
            Write-Error "Failed to process $path`: $($_.Exception.Message)"
            # Continue with next file instead of stopping entire operation
        }
    }
}
```

## Common Error Scenarios and Solutions

### File Operations
```powershell
# Check if file exists before processing
if (Test-Path $filePath) {
    try {
        $content = Get-Content $filePath -ErrorAction Stop
    } catch {
        Write-Error "Failed to read file: $($_.Exception.Message)"
    }
} else {
    Write-Warning "File does not exist: $filePath"
}
```

### Network Operations
```powershell
# Retry logic for network calls
$maxRetries = 3
$retryCount = 0

do {
    try {
        $result = Invoke-RestMethod $apiUrl -ErrorAction Stop
        break  # Success, exit loop
    } catch {
        $retryCount++
        if ($retryCount -ge $maxRetries) {
            throw "API call failed after $maxRetries attempts: $($_.Exception.Message)"
        }
        Write-Warning "API call failed, retrying in 5 seconds... (Attempt $retryCount of $maxRetries)"
        Start-Sleep -Seconds 5
    }
} while ($retryCount -lt $maxRetries)
```

## Summary

Effective error handling in PowerShell involves:

1. Understanding the difference between terminating and non-terminating errors
2. Using `-ErrorAction` parameter appropriately for each situation
3. Implementing try-catch blocks for critical operations
4. Capturing detailed error information for troubleshooting
5. Logging errors for production monitoring
6. Implementing graceful degradation and retry logic
7. Validating inputs early to prevent errors

Good error handling makes the difference between scripts that work in development and scripts that are reliable in production environments.