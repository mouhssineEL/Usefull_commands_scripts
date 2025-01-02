$csvData1 = Import-Csv -Path "C:\Users\melidrissi\Downloads\PROJECTS\falcon_api\list1.csv"
$list1 = $csvData1 | ForEach-Object { $_."Endpoint Name" }

$csvData2 = Import-Csv -Path "C:\Users\melidrissi\Downloads\PROJECTS\falcon_api\list2.csv"
$list2 = $csvData2 | ForEach-Object { $_."hostname" }

$sentineloneSet = $list2 | Sort-Object -Unique
$crowdstrikeSet = $list1 | Sort-Object -Unique

Write-Output "Liste 1 non intégré : $crowdstrikeSet"
Write-Output "Liste 2 dans CS : $sentineloneSet"

# Hôtes dans les deux listes
$commonHosts = $crowdstrikeSet | Where-Object { $sentineloneSet -contains $_ }

Write-Output "Nombre de postes dans les deux listes : $($commonHosts.Count)"
Write-Output "Postes dans les deux listes :"
$commonHosts | ForEach-Object { Write-Output $_ }