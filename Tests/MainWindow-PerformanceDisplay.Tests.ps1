BeforeAll {
    Add-Type -AssemblyName PresentationFramework
    . (Join-Path $PSScriptRoot '..\Scripts\GUI\Update-MainWindowPerformanceDisplay.ps1')

    function Get-Translation {
        param([string]$Key, [object[]]$FormatArgs, [string]$Section)
        if ($Key -eq 'PerformanceMemoryValue') {
            return '{0} GB / {1} GB ({2}%)' -f $FormatArgs
        }
        return $Key
    }

    function New-PerformanceTestWindow {
        $window = [System.Windows.Window]::new()
        [System.Windows.NameScope]::SetNameScope($window, [System.Windows.NameScope]::new())
        foreach ($entry in @(
            @{ Name = 'CpuUsageText'; Control = [System.Windows.Controls.TextBlock]::new() }
            @{ Name = 'CpuUsageBar'; Control = [System.Windows.Controls.ProgressBar]::new() }
            @{ Name = 'MemoryUsageText'; Control = [System.Windows.Controls.TextBlock]::new() }
            @{ Name = 'MemoryUsageBar'; Control = [System.Windows.Controls.ProgressBar]::new() }
            @{ Name = 'PerformanceUpdatedText'; Control = [System.Windows.Controls.TextBlock]::new() }
        )) {
            $window.RegisterName($entry.Name, $entry.Control)
        }
        return $window
    }
}

Describe 'Update-MainWindowPerformanceDisplay' {
    It 'updates CPU and memory labels and progress bars' {
        Mock Get-SystemPerformanceSnapshot {
            [PSCustomObject]@{
                CPUPercent = 42
                MemoryUsedPercent = 75
                MemoryUsedGB = 6
                MemoryTotalGB = 8
            }
        }
        $window = New-PerformanceTestWindow

        Update-MainWindowPerformanceDisplay -Window $window

        $window.FindName('CpuUsageText').Text | Should -BeLike '*42*%'
        $window.FindName('CpuUsageBar').Value | Should -Be 42
        $window.FindName('MemoryUsageText').Text | Should -Be '6 GB / 8 GB (75%)'
        $window.FindName('MemoryUsageBar').Value | Should -Be 75
        $window.FindName('PerformanceUpdatedText').Text | Should -BeLike 'PerformanceUpdated*'
    }

    It 'shows unavailable text when a provider has no data' {
        Mock Get-SystemPerformanceSnapshot {
            [PSCustomObject]@{
                CPUPercent = $null
                MemoryUsedPercent = $null
                MemoryUsedGB = $null
                MemoryTotalGB = $null
            }
        }
        $window = New-PerformanceTestWindow

        Update-MainWindowPerformanceDisplay -Window $window

        $window.FindName('CpuUsageText').Text | Should -Be 'PerformanceUnavailable'
        $window.FindName('CpuUsageBar').Value | Should -Be 0
        $window.FindName('MemoryUsageText').Text | Should -Be 'PerformanceUnavailable'
        $window.FindName('MemoryUsageBar').Value | Should -Be 0
    }
}
