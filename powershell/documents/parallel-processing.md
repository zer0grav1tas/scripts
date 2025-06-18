# PowerShell Parallel Processing Guide

Parallel processing refers to executing multiple operations simultaneously across different computational units. It is used to divide computationally intensive operations into smaller parts that are processed at the same time, dramatically reducing execution time for tasks that can be parallelized.

## When to Use Parallel Processing

**Good candidates for parallel processing:**
- Processing large collections of independent items
- Network operations (web requests, server management)
- File operations across multiple files/directories
- Data processing tasks that can be split

**Avoid parallel processing when:**
- Operations depend on each other (sequential dependencies)
- Working with shared resources that aren't thread-safe
- The overhead of parallelization exceeds the benefits (small datasets)

## PowerShell 7: ForEach-Object -Parallel

The modern and recommended approach for parallel processing in PowerShell 7+.

```powershell
$servers = "Server1", "Server2", "Server3", "Server4"

$servers | ForEach-Object -Parallel {
    try {
        $result = Invoke-Command -ComputerName $_ -ScriptBlock {
            param($SoftwareName)
            # Your installation commands here
            Install-Software -Name $SoftwareName
            return "Success on $env:COMPUTERNAME"
        } -ArgumentList "ExampleApp" -ErrorAction Stop
        
        Write-Host "✓ $result" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed on ${_}: $($_.Exception.Message)" -ForegroundColor Red
    }
} -ThrottleLimit 4
```

### Key Parameters:
- **-ThrottleLimit**: Controls maximum concurrent operations (default: 5)
- **-TimeoutSeconds**: Sets timeout for parallel operations
- **-AsJob**: Runs as background job for very long operations

### Advanced Example with Error Handling and Results:

```powershell
$servers = "Server1", "Server2", "Server3", "Server4"

$results = $servers | ForEach-Object -Parallel {
    $server = $_
    try {
        # Test connectivity first
        if (Test-Connection $server -Count 1 -Quiet -TimeoutSeconds 5) {
            $result = Invoke-Command -ComputerName $server -ScriptBlock {
                param($Software)
                $before = Get-Process | Measure-Object | Select-Object -ExpandProperty Count
                Install-Software -Name $Software
                $after = Get-Process | Measure-Object | Select-Object -ExpandProperty Count
                return @{
                    Server = $env:COMPUTERNAME
                    Status = "Success"
                    ProcessesBefore = $before
                    ProcessesAfter = $after
                    Timestamp = Get-Date
                }
            } -ArgumentList "ExampleApp" -ErrorAction Stop
            return $result
        } else {
            return @{
                Server = $server
                Status = "Unreachable"
                Error = "Connection timeout"
                Timestamp = Get-Date
            }
        }
    } catch {
        return @{
            Server = $server
            Status = "Failed"
            Error = $_.Exception.Message
            Timestamp = Get-Date
        }
    }
} -ThrottleLimit 4

# Process results
$results | ForEach-Object {
    Write-Host "$($_.Server): $($_.Status)" -ForegroundColor $(
        switch ($_.Status) {
            "Success" { "Green" }
            "Failed" { "Red" }
            "Unreachable" { "Yellow" }
        }
    )
}
```

## Pre-PowerShell 7: Runspaces

The traditional method for parallel processing, still useful for PowerShell 5.1 environments.

```powershell
$runspacePool = [runspacefactory]::CreateRunspacePool(1, 10)  # Create a pool with 10 max runspaces
$runspacePool.Open()
$runspaces = @()

$servers = "Server1", "Server2", "Server3", "Server4"

$servers | ForEach-Object {
    $powershell = [powershell]::Create().AddScript({
        param($server, $softwareName)
        try {
            $result = Invoke-Command -ComputerName $server -ScriptBlock {
                param($software)
                Install-Software -Name $software
                return "Success on $env:COMPUTERNAME"
            } -ArgumentList $softwareName -ErrorAction Stop
            return @{ Server = $server; Status = "Success"; Message = $result }
        } catch {
            return @{ Server = $server; Status = "Failed"; Message = $_.Exception.Message }
        }
    }).AddArgument($_).AddArgument("ExampleApp")
    
    $powershell.RunspacePool = $runspacePool
    
    $runspace = [PSCustomObject]@{
        Pipe = $powershell
        Handle = $powershell.BeginInvoke()
        Server = $_
    }
    $runspaces += $runspace
}

# Wait for all runspaces to complete and collect results
$results = $runspaces | ForEach-Object {
    try {
        $result = $_.Pipe.EndInvoke($_.Handle)
        return $result
    } catch {
        return @{ Server = $_.Server; Status = "Failed"; Message = $_.Exception.Message }
    } finally {
        $_.Pipe.Dispose()
    }
}

$runspacePool.Close()
$runspacePool.Dispose()

# Display results
$results | ForEach-Object {
    Write-Host "$($_.Server): $($_.Status) - $($_.Message)"
}
```

## PowerShell Workflows (Deprecated)

**Note: Workflows are deprecated and removed in PowerShell 6+. Included for historical reference only.**

```powershell
workflow Install-SoftwareOnServers {
    Param(
        [string[]]$ServerList,
        [string]$SoftwareName
    )
    
    foreach -parallel ($Server in $ServerList) {
        InlineScript {
            try {
                Invoke-Command -ComputerName $Using:Server -ScriptBlock {
                    param($Software)
                    Install-Software -Name $Software
                    Write-Output "Success on $env:COMPUTERNAME"
                } -ArgumentList $Using:SoftwareName -ErrorAction Stop
            } catch {
                Write-Warning "Failed on $Using:Server: $($_.Exception.Message)"
            }
        }
    }
}

# Usage
Install-SoftwareOnServers -ServerList "Server1", "Server2", "Server3" -SoftwareName "ExampleApp"
```

## Performance Comparison Example

```powershell
# Test data: 100 web requests
$urls = 1..100 | ForEach-Object { "https://httpbin.org/delay/1" }

# Sequential processing
$sequentialTime = Measure-Command {
    $urls | ForEach-Object {
        try {
            Invoke-RestMethod $_ -TimeoutSec 5 -ErrorAction SilentlyContinue
        } catch {
            # Handle errors silently for demo
        }
    }
}

# Parallel processing (PowerShell 7)
$parallelTime = Measure-Command {
    $urls | ForEach-Object -Parallel {
        try {
            Invoke-RestMethod $_ -TimeoutSec 5 -ErrorAction SilentlyContinue
        } catch {
            # Handle errors silently for demo
        }
    } -ThrottleLimit 10
}

Write-Host "Sequential: $($sequentialTime.TotalSeconds) seconds"
Write-Host "Parallel: $($parallelTime.TotalSeconds) seconds"
Write-Host "Speedup: $([math]::Round($sequentialTime.TotalSeconds / $parallelTime.TotalSeconds, 2))x"
```

## Real-World Use Cases

### 1. Server Health Check

```powershell
$servers = Get-Content "servers.txt"

$healthResults = $servers | ForEach-Object -Parallel {
    $server = $_
    $health = @{
        Server = $server
        Timestamp = Get-Date
    }
    
    try {
        # Test basic connectivity
        $ping = Test-Connection $server -Count 1 -Quiet -TimeoutSeconds 3
        $health.Ping = $ping
        
        if ($ping) {
            # Get system info
            $sysInfo = Invoke-Command -ComputerName $server -ScriptBlock {
                @{
                    CPU = (Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
                    Memory = [math]::Round((Get-WmiObject Win32_OperatingSystem).FreePhysicalMemory / 1MB, 2)
                    Disk = (Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" | 
                           Select-Object @{n="FreeGB";e={[math]::Round($_.FreeSpace/1GB,2)}}).FreeGB
                    Uptime = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
                }
            } -ErrorAction Stop
            
            $health += $sysInfo
            $health.Status = "Healthy"
        } else {
            $health.Status = "Unreachable"
        }
    } catch {
        $health.Status = "Error"
        $health.Error = $_.Exception.Message
    }
    
    return $health
} -ThrottleLimit 20

# Generate report
$healthResults | Export-Csv "server-health-$(Get-Date -Format 'yyyyMMdd-HHmm').csv" -NoTypeInformation
```

### 2. File Processing

```powershell
$files = Get-ChildItem "C:\DataFiles\*.csv"

$processedFiles = $files | ForEach-Object -Parallel {
    $file = $_
    try {
        # Process each CSV file
        $data = Import-Csv $file.FullName
        $processedData = $data | Where-Object { $_.Status -eq "Active" } | 
                               Select-Object Name, ID, @{n="ProcessedDate";e={Get-Date}}
        
        $outputPath = $file.FullName -replace "\.csv$", "_processed.csv"
        $processedData | Export-Csv $outputPath -NoTypeInformation
        
        return @{
            File = $file.Name
            Status = "Success"
            RecordsProcessed = $processedData.Count
            OutputFile = $outputPath
        }
    } catch {
        return @{
            File = $file.Name
            Status = "Failed"
            Error = $_.Exception.Message
        }
    }
} -ThrottleLimit 8

$processedFiles | Format-Table -AutoSize
```

## Best Practices

### 1. Choose Appropriate Throttle Limits
```powershell
# For CPU-intensive tasks: Number of cores
$cpuCores = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
$throttleLimit = $cpuCores

# For I/O operations: Higher limits often acceptable
$throttleLimit = 20

# For network operations: Test what works best
$throttleLimit = 10
```

### 2. Handle Shared Resources Carefully
```powershell
# Use thread-safe collections or synchronization
$synchronizedHashtable = [hashtable]::Synchronized(@{})

1..100 | ForEach-Object -Parallel {
    $num = $_
    $synchronized = $using:synchronizedHashtable
    $synchronized[$num] = "Processed $num"
} -ThrottleLimit 10
```

### 3. Monitor Resource Usage
```powershell
# Monitor memory usage during parallel operations
$before = Get-Process PowerShell | Measure-Object WorkingSet -Sum
# ... parallel operations ...
$after = Get-Process PowerShell | Measure-Object WorkingSet -Sum
Write-Host "Memory increase: $([math]::Round(($after.Sum - $before.Sum) / 1MB, 2)) MB"
```

## Summary

- **PowerShell 7+**: Use `ForEach-Object -Parallel` for new projects
- **PowerShell 5.1**: Use runspaces for parallel processing
- **Always** include proper error handling in parallel operations
- **Test** throttle limits to find optimal performance
- **Monitor** resource usage to avoid overwhelming the system
- **Consider** whether parallelization actually provides benefits for your specific use case

Parallel processing can dramatically improve performance for the right workloads, but it requires careful consideration of error handling, resource management, and throttling to be effective in production environments.