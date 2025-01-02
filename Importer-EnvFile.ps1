# Import the dotenv module
function Import-DotEnv {
    param(
        [string]$Path = ".\.env"
    )
    
    if (Test-Path $Path) {
        Get-Content $Path | Where-Object { 
            $_ -match '^([^=]+)=(.*)$' 
        } | ForEach-Object {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            [System.Environment]::SetEnvironmentVariable($name, $value, "Process")
        }
    }
}

# Call the function
Import-DotEnv

# Assign environment variables to PowerShell variables
$CROWDSTRIKE_CLIENT_ID = $env:CROWDSTRIKE_CLIENT_ID
$CROWDSTRIKE_CLIENT_SECRET = $env:CROWDSTRIKE_CLIENT_SECRET
$apiToken = $env:APITOKEN
$managementUri = $env:MANAGEMENTURI
$tagToCheck = $env:TAGTOCHECK

# Output the variables
Write-Output $CROWDSTRIKE_CLIENT_ID
Write-Output $CROWDSTRIKE_CLIENT_SECRET
Write-Output $apiToken
Write-Output $managementUri
Write-Output $tagToCheck