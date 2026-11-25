BeforeAll {
    $performanceHelperPath = Join-Path $PSScriptRoot '..\Scripts\Helpers\Get-SystemPerformanceSnapshot.ps1'
    . $performanceHelperPath
}

Describe 'ConvertTo-SystemPerformanceSnapshot' {
    It 'calculates CPU and memory usage from Windows provider data' {
        $operatingSystem = [PSCustomObject]@{
            TotalVisibleMemorySize = 8 * 1024 * 1024
            FreePhysicalMemory = 2 * 1024 * 1024
        }
        $processor = [PSCustomObject]@{ PercentProcessorTime = 37 }

        $result = ConvertTo-SystemPerformanceSnapshot -OperatingSystem $operatingSystem -Processor $processor

        $result.CPUPercent | Should -Be 37
        $result.MemoryTotalGB | Should -Be 8
        $result.MemoryUsedGB | Should -Be 6
        $result.MemoryUsedPercent | Should -Be 75
        $result.SampledAtUtc.Kind | Should -Be ([DateTimeKind]::Utc)
    }

    It 'clamps provider values to valid percentage ranges' {
        $operatingSystem = [PSCustomObject]@{
            TotalVisibleMemorySize = 1024
            FreePhysicalMemory = 2048
        }
        $processor = [PSCustomObject]@{ PercentProcessorTime = 125 }

        $result = ConvertTo-SystemPerformanceSnapshot -OperatingSystem $operatingSystem -Processor $processor

        $result.CPUPercent | Should -Be 100
        $result.MemoryUsedPercent | Should -Be 0
        $result.MemoryUsedGB | Should -Be 0
    }

    It 'returns null for unavailable or invalid provider values' {
        $operatingSystem = [PSCustomObject]@{
            TotalVisibleMemorySize = 0
            FreePhysicalMemory = 0
        }
        $processor = [PSCustomObject]@{ PercentProcessorTime = 'not-a-number' }

        $result = ConvertTo-SystemPerformanceSnapshot -OperatingSystem $operatingSystem -Processor $processor

        $result.CPUPercent | Should -BeNullOrEmpty
        $result.MemoryUsedPercent | Should -BeNullOrEmpty
        $result.MemoryTotalGB | Should -BeNullOrEmpty
        $result.MemoryUsedGB | Should -BeNullOrEmpty
    }
}

Describe 'Get-SystemPerformanceSnapshot' {
    It 'reads only the Windows operating-system and total-CPU providers' {
        Mock Get-CimInstance {
            if ($ClassName -eq 'Win32_OperatingSystem') {
                return [PSCustomObject]@{
                    TotalVisibleMemorySize = 4 * 1024 * 1024
                    FreePhysicalMemory = 1 * 1024 * 1024
                }
            }

            if ($ClassName -eq 'Win32_PerfFormattedData_PerfOS_Processor') {
                return [PSCustomObject]@{ PercentProcessorTime = 22 }
            }
        }

        $result = Get-SystemPerformanceSnapshot

        $result.CPUPercent | Should -Be 22
        $result.MemoryUsedPercent | Should -Be 75
        Should -Invoke Get-CimInstance -Times 1 -Exactly -ParameterFilter {
            $ClassName -eq 'Win32_OperatingSystem'
        }
        Should -Invoke Get-CimInstance -Times 1 -Exactly -ParameterFilter {
            $ClassName -eq 'Win32_PerfFormattedData_PerfOS_Processor' -and $Filter -eq "Name='_Total'"
        }
    }
}

Describe 'Get-SystemPerformanceSnapshot source safety' {
    It 'contains no system mutation commands' {
        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($performanceHelperPath, [ref]$tokens, [ref]$parseErrors)
        $parseErrors | Should -BeNullOrEmpty

        $mutationCommands = @(
            'Set-ItemProperty', 'New-ItemProperty', 'Remove-ItemProperty',
            'Set-Service', 'Start-Service', 'Stop-Service', 'Stop-Process',
            'Remove-AppxPackage', 'Disable-ScheduledTask', 'Enable-ScheduledTask',
            'reg.exe', 'schtasks.exe', 'dism.exe'
        )
        $found = @(
            $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true) |
                ForEach-Object { $_.GetCommandName() } |
                Where-Object { $mutationCommands -contains $_ }
        )

        $found | Should -BeNullOrEmpty
    }
}
