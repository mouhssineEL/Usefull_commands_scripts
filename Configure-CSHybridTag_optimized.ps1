# Requires CrowdStrike PSFalcon module
# Install the module (first-time setup)
# Install-Module -Name PSFalcon -Scope CurrentUser -Force
# Import the module
Import-Module PSFalcon


# Call the function
Import-DotEnv -Path ".\.env"

# Assign environment variables to PowerShell variables
$CROWDSTRIKE_CLIENT_ID = $env:CROWDSTRIKE_CLIENT_ID
$CROWDSTRIKE_CLIENT_SECRET = $env:CROWDSTRIKE_CLIENT_SECRET
$apiToken = $env:APITOKEN
$managementUri = $env:MANAGEMENTURI
$tagToCheck = $env:TAGTOCHECK

$headers = @{ "Authorization" = "Bearer $apiToken" }
$sentineloneHostDictionary = @{}
$crowdstrikeHostDictionary = @{}

function Import-DotEnv {
    param(
        [string]$Path = ".\.env"
    )
    
    # Resolve the full path to handle relative and absolute paths
    $fullPath = Resolve-Path $Path -ErrorAction SilentlyContinue
    
    if ($fullPath) {
        Get-Content $fullPath | Where-Object { 
            # Ignore empty lines and comments
            $_ -match '^([^#\s][^=]*?)=(.*)$' 
        } | ForEach-Object {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            
            # Remove quotes if present
            $value = $value -replace '^["'']|["'']$'
            
            [System.Environment]::SetEnvironmentVariable($name, $value, "Process")
        }
        Write-Host "Environment variables imported from $fullPath"
    }
    else {
        Write-Error "Environment file not found at $Path"
    }
}

function Get-CrowdStrikeHosts {
    param (
        [hashtable]$hostDictionary
    )
    # Test falcon API connection
    #Test-FalconToken

    # Connect to CrowdStrike API
    #Request-FalconToken -ClientId $env:CROWDSTRIKE_CLIENT_ID -ClientSecret $env:CROWDSTRIKE_CLIENT_SECRET

    # Export hosts
    Write-Output "Requesting hosts from CrowdStrike ..."

    $crowdstrikeHosts = Get-FalconHost -Detailed | Select-Object -Property hostname, device_id, tags, product_type_desc

    # Populate the dictionary with hostnames and ids
    foreach ($currentHost in $crowdstrikeHosts) {
        $hostname = $currentHost.hostname
        $deviceId = $currentHost.device_id
        $tags = $currentHost.tags
        $productType = $currentHost.product_type_desc

        # Add to the dictionary
        $hostDictionary[$hostname] = @{
            "device_id" = $deviceId
            "tags" = if ($tags -ne $null) { @($tags | ForEach-Object { $_.ToString() }) } else { @() }
            "product_type_desc" = $productType
        }
    }

    # Save hostnames and ids to CSV file
    $crowdstrikeCsvPath = ".\crowdstrike_hostnames.csv"
    $crowdstrikeHosts | Export-Csv -Path $crowdstrikeCsvPath -NoTypeInformation -Force

    Write-Output "CrowdStrike hosts saved to $crowdstrikeCsvPath"
}

function Get-AllSentinelPassphrases {
    param (
        [int]$limit = 1000
    )
    
    $allPassphrases = @()
    $nextCursor = $null
    
    Write-Output "Requesting passphrases from SentinelOne..."
    do {
        $passphraseUrl = "$managementUri/web/api/v2.1/agents/passphrases?limit=$limit"
        if ($nextCursor) {
            $passphraseUrl += "&cursor=$nextCursor"
        }
        
        try {
            $response = Invoke-RestMethod -Uri $passphraseUrl -Headers $headers -Method Get
            
            # Check if the response contains passphrases
            if ($response.data) {
                $currentBatch = $response.data | Select-Object @{Name="ComputerName";Expression={$_.computerName}}, @{Name="Passphrase";Expression={$_.passphrase}},@{Name="UUID";Expression={$_.uuid}}
                $allPassphrases += $currentBatch
                
                # Update cursor for next request
                $nextCursor = $response.pagination.nextCursor
            } else {
                Write-Error "Passphrases not found in the response."
                break
            }
        }
        catch {
            Write-Error "Error making API request: $_"
            break
        }
    } while ($nextCursor -ne $null -and $nextCursor -ne "")
    
    # Save all passphrases to CSV file
    $passphraseCsvPath = "all_passphrases_sentinel.csv"
    $allPassphrases | Export-Csv -Path $passphraseCsvPath -NoTypeInformation -Force
    Write-Output "All passphrases saved successfully to $passphraseCsvPath"
}

function Get-AllSentinelHosts {
    param (
        [int]$limitCount = 1000,
        [hashtable]$hostDictionary
    )
    
    $allHosts = @()
    $nextCursor = $null

    Write-Output "Requesting hosts from SentinelOne..."
    do {
        $apiUrl = "$managementUri/web/api/v2.1/agents?limit=$limitCount"
        if ($nextCursor) {
            $apiUrl += "&cursor=$nextCursor"
        }
        
        try {
            $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get
            
            # Get total count from response if available
            if ($response.pagination.totalItems) {
                $totalItems = $response.pagination.totalItems
                Write-Output "Total hosts available: $totalItems"
            }
            
            # Check if the response contains data
            if ($response.data) {
                $currentBatch = $response.data
                $allHosts += $currentBatch
                
                # Update cursor for next request
                $nextCursor = $response.pagination.nextCursor

                # Add to dictionary
                foreach ($currentHost in $currentBatch) {
                    $hostDictionary[$currentHost.computerName] = $currentHost.id
                }
            } else {
                Write-Error "Failed to retrieve hosts or no more hosts available"
                break
            }
        }
        catch {
            Write-Error "Error making API request: $_"
            break
        }
    } while ($nextCursor -ne $null -and $nextCursor -ne "")

    # Save all hosts to CSV file
    $csvPath = "sentinel_hostnames.csv"
    if ($allHosts.Count -gt 0) {
        $hostData = $allHosts | Select-Object @{Name="Hostname";Expression={$_.computerName}}, @{Name="id";Expression={$_.id}}, @{Name="UUID";Expression={$_.uuid}}, @{Name="siteName";Expression={$_.siteName}}
        
        try {
            $hostData | Export-Csv -Path $csvPath -NoTypeInformation -Force
            Write-Output "Sentinel Hostnames successfully saved to $csvPath"
            
            Write-Output "Total hosts saved: $($hostData.Count)"
            
            if ($totalItems) {
                Write-Output "Expected total from API: $totalItems"
                if ($hostData.Count -ne $totalItems) {
                    Write-Warning "Number of retrieved hosts differs from expected total!"
                }
            }
        }
        catch {
            Write-Error "Error saving to file: $_"
        }
    } else {
        Write-Error "No hosts were retrieved"
    }

    Write-Output "Returning host dictionary with $($hostDictionary.Count) entries"
}

function Uninstall-SentinelOneAgent {
    param (
        [string]$Hostname,
        [hashtable]$HostDictionary
    )
    
    $agentId = $HostDictionary[$Hostname]
    if ($null -eq $agentId) {
        Write-Host "Agent not found for hostname: $Hostname"
        return $null
    }
    
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/json")
    $headers.Add("Authorization", "Bearer $apiToken")
    
    $body = @"
    {
        `"filter`": {
            `"ids`": [
                `"$agentId`"
            ]
        }
    }
"@
    
    try {
        $response = Invoke-RestMethod -Uri "$managementUri/web/api/v2.1/agents/actions/uninstall" -Method 'POST' -Headers $headers -Body $body
        return $response
    } catch {
        Write-Error "Error making API request: $_"
        return $null
    }
}

function Uninstall-SentinelOneAgentBatch {
    param (
        [Parameter(Mandatory=$true)]
        [string[]]$Hostnames,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$HostDictionary,
        
        [switch]$PassThru
    )

    # Initialize counters
    $affectedCount = 0
    $notAffectedCount = 0
    $affectedHosts = @()

    foreach ($hostname in $Hostnames) {
        $response = Uninstall-SentinelOneAgent -Hostname $hostname -HostDictionary $HostDictionary
        
        if ($response -and $response.data) {
            $affected = $response.data.affected
            if ($affected -gt 0) {
                $affectedCount += $affected
                $affectedHosts += $hostname
            }
        }
    }

    # Display final results
    Write-Host "Total number of hosts affected: $affectedCount"
    Write-Host "List of affected hosts: $($affectedHosts -join ', ')"

    if ($PassThru) {
        return @{
            AffectedCount = $affectedCount
            NotAffectedCount = $notAffectedCount
            AffectedHosts = $affectedHosts
        }
    }
}

function Remove-FalconTag {
    param (
        [string[]]$HostIds  # List of host IDs
    )

    # Define the constant tag
    $Tag = "FalconGroupingTags/nosentinel"

    Write-Output "Removing FalconGroupingTag from hosts in CrowdStrike by host IDs ..."

    foreach ($id in $HostIds) {
        Write-Output "Removing tag from host with ID: $id"
        # Remove the tag from the host
        Remove-FalconGroupingTag -Id $id -Tags $Tag
    }

    Write-Output "Tag removal completed."
}

function Add-FalconTag {
    param (
        [string[]]$HostIds  # List of host IDs
    )

    # Define the constant tag
    $Tag = "FalconGroupingTags/nosentinel"

    # Test falcon API connection
    #Test-FalconToken

    # Connect to CrowdStrike API
    # Request-FalconToken -ClientId $env:CROWDSTRIKE_CLIENT_ID -ClientSecret $env:CROWDSTRIKE_CLIENT_SECRET
   
    Write-Output "Adding FalconGroupingTag to hosts in CrowdStrike by host IDs ..."

    foreach ($id in $HostIds) {
        # Add the tag to the host
        Add-FalconGroupingTag -Id $id -Tags $Tag
    }

    Write-Output "Tagging completed Total hosts affected: $($HostIds.Count)"
}

function Get-ValuesFromDictionary {
    param (
        [hashtable]$Dictionary,  # The dictionary to search
        [string[]]$Keys          # List of keys to retrieve values for
    )

    $values = @()  # Initialize an array to store the values

    foreach ($key in $Keys) {
        if ($Dictionary.ContainsKey($key)) {
            $values += $Dictionary[$key]
        } else {
            Write-Output "Key '$key' not found in the dictionary."
        }
    }

    return $values
}

function Export-Data {
    param (
        [string]$baseName,
        [array]$data
    )

    # Define the pattern for the CSV files
    $pattern = ".\${baseName}_*.csv"

    # Remove any existing files that match the pattern
    Get-ChildItem -Path $pattern | Remove-Item -ErrorAction SilentlyContinue

    # Get the current date and time
    $currentDateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

    # Create a list object and export it with the current date and time
    $listObject = $data | ForEach-Object { [PSCustomObject]@{($baseName)=$_} }
    $listObject | Export-Csv -Path ".\${baseName}_$currentDateTime.csv" -NoTypeInformation -Force
}

function Add_FalconTagFromList{
    # From a list , here we change to our list and don't forget to change the "{ $_."Hostname" }" by your column name ! 
    $csvData1 = Import-Csv -Path "C:\Users\usernaùe\Downloads\PROJECTS\falcon_api\add_tag_list.csv"
    $list1 = $csvData1 | ForEach-Object { $_."Hostname" }

    # Retrieve the IDs for hosts only in CrowdStrike and filter out those that already have the tag or are of product type "Server"
    $onlyInCrowdstrikeIdsList1 = $list1 | ForEach-Object {
        $hostDetails = $crowdstrikeHostDictionary[$_]
        if ($hostDetails["tags"] -notcontains $tagToCheck -and $hostDetails["product_type_desc"] -ne "Server") {
            $hostDetails["device_id"]
        }
    }

    # Remove null values from the list
    $onlyInCrowdstrikeIdsList1 = $onlyInCrowdstrikeIdsList1 | Where-Object { $_ -ne $null }

    # Apply the grouping tag to hosts only in CrowdStrike that do not have the tag and are not servers on a specific list
    Add-FalconTag -HostIds $onlyInCrowdstrikeIdsList1

}
# ###################################################### Example usage ##############################################

# Call the function Get-CrowdStrikeHosts
Get-CrowdStrikeHosts  -hostDictionary $crowdstrikeHostDictionary
$crowdstrikeHosts = $crowdstrikeHostDictionary.Keys
# Write-Output $crowdstrikeHostDictionary.Values

# Call the function Get-AllSentinelPassphrases
Get-AllSentinelPassphrases

# Call the function Get-AllSentinelHosts and pass the variable
Get-AllSentinelHosts  -hostDictionary $sentineloneHostDictionary
$sentineloneHosts = $sentineloneHostDictionary.Keys
#Write-Output $sentineloneHosts

# Compare the two lists
Write-Output "`n #### Comparing CrowdStrike and SentinelOne hosts ####"

# Convert lists to sets for comparison
$crowdstrikeSet = $crowdstrikeHosts | Sort-Object -Unique
$sentineloneSet = $sentineloneHosts | Sort-Object -Unique

# Find hosts that are in CrowdStrike but not in SentinelOne
$onlyInCrowdstrike = $crowdstrikeSet | Where-Object { $_ -notin $sentineloneSet }

# Find hosts that are in SentinelOne but not in CrowdStrike
$onlyInSentinelone = $sentineloneSet | Where-Object { $_ -notin $crowdstrikeSet }

# Find hosts that are in both lists
$inBoth = $crowdstrikeSet | Where-Object { $_ -in $sentineloneSet }

# Display the results
Write-Output "`nHosts only in CrowdStrike : $($onlyInCrowdstrike.Count)"

Write-Output "`nHosts only in SentinelOne : $($onlyInSentinelone.Count)"

Write-Output "`nHosts in both lists : $($inBoth.Count)"

#Export onlyInCrowdstrike data
Export-Data -baseName "only_in_crowdstrike" -data $onlyInCrowdstrike

# Export onlyInSentinelone data
Export-Data -baseName "only_in_sentinelone" -data $onlyInSentinelone

# Export inBoth data
Export-Data -baseName "in_both" -data $inBoth

# Retrieve the IDs for hosts only in CrowdStrike
$onlyInCrowdstrikeIds = $onlyInCrowdstrike | ForEach-Object { $crowdstrikeHostDictionary[$_] }
#Write-Output $onlyInCrowdstrikeIds

# Apply the grouping tag to hosts only in CrowdStrike

# Retrieve the IDs for hosts only in CrowdStrike and filter out those that already have the tag or are of product type "Server"
$onlyInCrowdstrikeIds = $onlyInCrowdstrike | ForEach-Object {
    $hostDetails = $crowdstrikeHostDictionary[$_]
    if ($hostDetails["tags"] -notcontains $tagToCheck -and $hostDetails["product_type_desc"] -ne "Server") {
        $hostDetails["device_id"]
    }
}

# Remove null values from the list
$onlyInCrowdstrikeIds = $onlyInCrowdstrikeIds | Where-Object { $_ -ne $null }

# Call the function Uninstall-SentinelOneAgent
# Basic usage
Uninstall-SentinelOneAgentBatch -Hostnames $inBoth -HostDictionary $sentineloneHostDictionary

# If you want to capture the results
#$results = Uninstall-SentinelOneAgentBatch -Hostnames $inBoth -HostDictionary $sentineloneHostDictionary -PassThru

# Access results
#$totalAffected = $results.AffectedCount
#$affectedHostList = $results.AffectedHosts

# Apply the grouping tag to hosts only in CrowdStrike that do not have the tag and are not servers
Add-FalconTag -HostIds $onlyInCrowdstrikeIds


