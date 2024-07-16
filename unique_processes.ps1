$processes = Get-Process | Sort-Object Name, StartTime

$uniqueProcesses = @{}

foreach ($process in $processes) {
    if (-not $uniqueProcesses.ContainsKey($process.Name)) {
        $parent = Get-Process -Id $process.Id -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Parent -ErrorAction SilentlyContinue
        $uniqueProcesses[$process.Name] = [PSCustomObject]@{
            Name = $process.Name
            Id = $process.Id
            StartTime = $process.StartTime
            ParentId = if ($parent) { $parent.Id } else { $null }
        }
    }
}

$uniqueProcesses.Values | Sort-Object StartTime | Format-Table -Property Name, Id, StartTime, ParentId -AutoSize
