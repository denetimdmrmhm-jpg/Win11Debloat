function ConvertTo-SystemPerformanceSnapshot {
    <#
        .SYNOPSIS
            Converts Windows performance provider data into a read-only CPU and memory snapshot.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [object]$OperatingSystem,

        [Parameter()]
        [object]$Processor
    )

    $cpuPercent = $null
    if ($null -ne $Processor -and $null -ne $Processor.PercentProcessorTime) {
        try {
            $cpuPercent = [Math]::Max(0, [Math]::Min(100, [double]$Processor.PercentProcessorTime))
        }
        catch {
            $cpuPercent = $null
        }
    }

    $memoryTotalGB = $null
    $memoryUsedGB = $null
    $memoryUsedPercent = $null

    if ($null -ne $OperatingSystem -and
        $null -ne $OperatingSystem.TotalVisibleMemorySize -and
        $null -ne $OperatingSystem.FreePhysicalMemory) {
        try {
            $totalKB = [double]$OperatingSystem.TotalVisibleMemorySize
            $freeKB = [double]$OperatingSystem.FreePhysicalMemory

            if ($totalKB -gt 0 -and $freeKB -ge 0) {
                $freeKB = [Math]::Min($totalKB, $freeKB)
                $usedKB = $totalKB - $freeKB
                $memoryTotalGB = [Math]::Round($totalKB / 1MB, 2)
                $memoryUsedGB = [Math]::Round($usedKB / 1MB, 2)
                $memoryUsedPercent = [Math]::Round(($usedKB / $totalKB) * 100, 1)
            }
        }
        catch {
            $memoryTotalGB = $null
            $memoryUsedGB = $null
            $memoryUsedPercent = $null
        }
    }

    [PSCustomObject]@{
        CPUPercent        = $cpuPercent
        MemoryUsedPercent = $memoryUsedPercent
        MemoryTotalGB     = $memoryTotalGB
        MemoryUsedGB      = $memoryUsedGB
        SampledAtUtc      = [DateTime]::UtcNow
    }
}

function Get-SystemPerformanceSnapshot {
    <#
        .SYNOPSIS
            Collects a read-only CPU and memory snapshot from Windows CIM performance providers.
        .DESCRIPTION
            This function only reads operating-system counters. It does not modify services,
            registry values, processes, scheduled tasks, or Windows configuration.
    #>
    [CmdletBinding()]
    param()

    $operatingSystem = $null
    $processor = $null

    try {
        $operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    }
    catch {
        Write-Verbose "Unable to read Windows memory counters: $($_.Exception.Message)"
    }

    try {
        $processor = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction Stop
    }
    catch {
        Write-Verbose "Unable to read Windows CPU counters: $($_.Exception.Message)"
    }

    return ConvertTo-SystemPerformanceSnapshot -OperatingSystem $operatingSystem -Processor $processor
}
