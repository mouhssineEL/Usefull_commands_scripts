param (
    [Parameter(Mandatory=$true)][string]$inputfile,
    [Parameter(Mandatory=$true)][string]$outputfile
)

$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false

$wb = $excel.Workbooks.Add()
$ws = $wb.Sheets.Item(1)

write-output "Opening $inputfile"

$i = 1
$installDateColumnIndex = -1
Import-Csv $inputfile | Foreach-Object { 
    $j = 1
    foreach ($prop in $_.PSObject.Properties) {
        if ($i -eq 1) {
            $ws.Cells.Item($i, $j) = $prop.Name
            if ($prop.Name -eq "InstallDate") {
                $installDateColumnIndex = $j
            }
        } else {
            if ($j -eq $installDateColumnIndex) {
                # Assuming InstallDate is in YYYYMMDD format
                $installDateValue = $_.InstallDate
                $formattedDate = [DateTime]::ParseExact($installDateValue, "yyyyMMdd", $null).ToString("dd/MM/yyyy")
                $ws.Cells.Item($i, $j) = $formattedDate
            } else {
                $ws.Cells.Item($i, $j) = $prop.Value
            }
        }
        $j++
    }
    $i++
}

$wb.SaveAs($outputfile, 51)
$wb.Close()
$excel.Quit()
write-output "Success"
