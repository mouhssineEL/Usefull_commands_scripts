# Vérifier si PowerShell est exécuté en tant qu'administrateur
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Vous devez exécuter PowerShell en tant qu'administrateur pour obtenir les informations des groupes, membres, et utilisateurs."
    exit
}

# Fonction pour afficher le titre avec une mise en forme
function Write-Title {
    param (
        [string]$title
    )

    Write-Host ""
    Write-Host "=== $title ===" -ForegroundColor Yellow
    Write-Host ""
}

# Obtenir tous les groupes locaux sur la machine
$groups = Get-LocalGroup

foreach ($group in $groups) {
    # Obtenir les membres du groupe
    $members = Get-LocalGroupMember -Group $group.Name

    # Vérifier si le groupe a des membres
    if ($members.Count -gt 0) {
        Write-Title -title "Groupe: $($group.Name)"
        foreach ($member in $members) {
            Write-Host "    Membre: $($member.Name)" -ForegroundColor Green
        }
        Write-Host ""
    }
}

# Obtenir tous les utilisateurs locaux sur la machine
$users = Get-LocalUser

foreach ($user in $users) {
    # Obtenir la date de création de l'utilisateur
    $creationDate = $user.LastLogonDate

    # Obtenir la dernière connexion de l'utilisateur
    $lastLogon = Get-WinEvent -LogName "Security" -FilterXPath "*[System[EventID=4624] and EventData[Data[@Name='TargetUserName']='$($user.Name)']]" |
                 Sort-Object TimeCreated -Descending |
                 Select-Object -First 1

    # Vérifier si l'utilisateur a des informations de dernière connexion
    if ($lastLogon) {
        $lastLogonTime = $lastLogon.TimeCreated
    } else {
        $lastLogonTime = "Never"
    }

    # Afficher les détails de l'utilisateur
    Write-Title -title "Utilisateur: $($user.Name)"
    Write-Host "    Date de création   : $creationDate"
    Write-Host "    Dernière connexion : $lastLogonTime" -ForegroundColor Green
    Write-Host ""
}
