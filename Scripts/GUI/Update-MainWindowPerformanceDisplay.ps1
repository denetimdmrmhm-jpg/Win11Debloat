function Update-MainWindowPerformanceDisplay {
    <#
        .SYNOPSIS
            Updates the read-only CPU and memory indicators on the main window.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Window]$Window
    )

    $cpuValueText = $Window.FindName('CpuUsageText')
    $cpuUsageBar = $Window.FindName('CpuUsageBar')
    $memoryValueText = $Window.FindName('MemoryUsageText')
    $memoryUsageBar = $Window.FindName('MemoryUsageBar')
    $updatedText = $Window.FindName('PerformanceUpdatedText')

    if (-not $cpuValueText -or -not $cpuUsageBar -or -not $memoryValueText -or -not $memoryUsageBar) {
        return
    }

    try {
        $snapshot = Get-SystemPerformanceSnapshot

        if ($null -ne $snapshot.CPUPercent) {
            $cpuUsageBar.Value = $snapshot.CPUPercent
            $cpuValueText.Text = '{0:N0}%' -f $snapshot.CPUPercent
        }
        else {
            $cpuUsageBar.Value = 0
            $cpuValueText.Text = Get-Translation -Key 'PerformanceUnavailable'
        }

        if ($null -ne $snapshot.MemoryUsedPercent) {
            $memoryUsageBar.Value = $snapshot.MemoryUsedPercent
            $memoryValueText.Text = Get-Translation -Key 'PerformanceMemoryValue' -FormatArgs @(
                $snapshot.MemoryUsedGB, $snapshot.MemoryTotalGB, $snapshot.MemoryUsedPercent
            )
        }
        else {
            $memoryUsageBar.Value = 0
            $memoryValueText.Text = Get-Translation -Key 'PerformanceUnavailable'
        }

        if ($updatedText) {
            $updatedText.Text = Get-Translation -Key 'PerformanceUpdated' -FormatArgs @((Get-Date).ToString('T'))
        }
    }
    catch {
        Write-Verbose "Unable to update the system performance display: $($_.Exception.Message)"
        $cpuUsageBar.Value = 0
        $memoryUsageBar.Value = 0
        $cpuValueText.Text = Get-Translation -Key 'PerformanceUnavailable'
        $memoryValueText.Text = Get-Translation -Key 'PerformanceUnavailable'
        if ($updatedText) {
            $updatedText.Text = Get-Translation -Key 'PerformanceUnavailable'
        }
    }
}
