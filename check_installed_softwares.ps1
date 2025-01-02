# Ensure PSWriteColor is imported
Import-Module PSWriteColor

# Define the time range to check for recent installations
$daysToCheck = 7
$startTime = (Get-Date).AddDays(-$daysToCheck)

# Define registry paths for installed software
$uninstallPaths = @(
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

# Function to get installed software from registry
function Get-InstalledSoftware {
    param (
        [string[]]$Paths
    )

    $installedSoftware = @()

    foreach ($path in $Paths) {
        $installedSoftware += Get-ItemProperty -Path $path -ErrorAction SilentlyContinue |
            Where-Object { $_.InstallDate -ge $startTime } |
            Select-Object DisplayName, InstallDate, DisplayVersion, Description
    }

    return $installedSoftware
}

# Get installed software for all users
$softwareList = Get-InstalledSoftware -Paths $uninstallPaths

# Sort the software list by install date in descending order
$sortedSoftwareList = $softwareList | Sort-Object InstallDate -Descending

# Define a function to write color headers
function Write-ColorHeader {
    param (
        [string]$Text,
        [string]$Color
    )
    Write-Color -Text $Text -Color $Color -NoNewline
    Write-Host "`t"
}

# Define a function to write color data
function Write-ColorData {
    param (
        [string]$Text,
        [string]$Color
    )
    Write-Color -Text $Text -Color $Color -NoNewline
    Write-Host "`t"
}

# Output header with colors
Write-Host ""
Write-ColorHeader "Software Name" "Cyan"
Write-ColorHeader "Install Date" "Cyan"
Write-ColorHeader "Version" "Cyan"
Write-ColorHeader "Description" "Cyan"
Write-Host ""

# Output results in a formatted table with colors
$sortedSoftwareList | ForEach-Object {
    Write-Host ""
    Write-ColorData $_.DisplayName "Yellow"
    Write-ColorData $_.InstallDate "Green"
    Write-ColorData $_.DisplayVersion "Magenta"
    Write-ColorData $_.Description "Blue"
    Write-Host ""
}

# Save to a CSV file if needed
$csvPath = "C:\Users\username\Downloads\InstalledSoftware.csv"
$sortedSoftwareList | Export-Csv -Path $csvPath -NoTypeInformation

Write-Output "Installed software details have been saved to $csvPath"
