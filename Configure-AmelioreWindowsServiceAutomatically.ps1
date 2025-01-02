
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
# Fonction pour obtenir les informations du service
function Get-ServiceInfo {
    $useEnvVars = Read-Host "Voulez-vous utiliser les variables d'environnement ? (O/N)"
    
    if ($useEnvVars -eq "O") {
        # Call the function
        Import-DotEnv -Path ".\.env"
        $serviceName = $env:SERVICE_NAME
        $serviceDisplayName = $env:SERVICE_DISPLAY_NAME
        $pythonPath = $env:PYTHON_PATH
        $scriptPath = $env:SCRIPT_PATH
        $startupType = $env:STARTUP_TYPE

        # Vérification des variables d'environnement
        if (-not $serviceName -or -not $serviceDisplayName -or -not $pythonPath -or -not $scriptPath -or -not $startupType) {
            Write-Host "Certaines variables d'environnement sont manquantes. Passage à la saisie manuelle."
            return Get-ManualServiceInfo
        }
    } else {
        return Get-ManualServiceInfo
    }

    return @{
        Name = $serviceName
        DisplayName = $serviceDisplayName
        PythonPath = $pythonPath
        ScriptPath = $scriptPath
        StartupType = $startupType
    }
}

function Get-ManualServiceInfo {
    $serviceName = Read-Host "Entrez le nom du service"
    $serviceDisplayName = Read-Host "Entrez le nom d'affichage du service"
    $pythonPath = Read-Host "Entrez le chemin complet vers l'exécutable Python"
    $scriptPath = Read-Host "Entrez le chemin complet vers le script Python"
    $startupType = Read-Host "Entrez le type de démarrage (Automatic, Manual, Disabled)"

    return @{
        Name = $serviceName
        DisplayName = $serviceDisplayName
        PythonPath = $pythonPath
        ScriptPath = $scriptPath
        StartupType = $startupType
    }
}

# Fonction pour créer et démarrer le service
function Create-And-Start-Service($serviceInfo) {
    $binaryPath = "$($serviceInfo.PythonPath) $($serviceInfo.ScriptPath)"
    
    if (Get-Service $serviceInfo.Name -ErrorAction SilentlyContinue) {
        Write-Host "Le service existe déjà. Arrêt et suppression..."
        Stop-Service -Name $serviceInfo.Name -Force
        sc.exe delete $serviceInfo.Name
    }

    New-Service -Name $serviceInfo.Name -BinaryPathName $binaryPath -DisplayName $serviceInfo.DisplayName -StartupType $serviceInfo.StartupType
    Start-Service -Name $serviceInfo.Name
    Write-Host "Service créé et démarré avec succès."
}

# Fonction pour arrêter et supprimer le service
function Stop-And-Remove-Service($serviceName) {
    if (Get-Service $serviceName -ErrorAction SilentlyContinue) {
        Stop-Service -Name $serviceName -Force
        sc.exe delete $serviceName
        Write-Host "Service arrêté et supprimé avec succès."
    } else {
        Write-Host "Le service n'existe pas."
    }
}

# Exécution principale
do {
    Write-Host "`nChoisissez une option:"
    Write-Host "1: Créer et démarrer un service"
    Write-Host "2: Arrêter et supprimer un service"
    Write-Host "3: Quitter"
    $choice = Read-Host "Entrez votre choix (1, 2 ou 3)"

    switch ($choice) {
        "1" { 
            $serviceInfo = Get-ServiceInfo
            Create-And-Start-Service $serviceInfo 
        }
        "2" { 
            $serviceName = Read-Host "Entrez le nom du service à supprimer"
            Stop-And-Remove-Service $serviceName 
        }
        "3" { Write-Host "Au revoir!" }
        default { Write-Host "Choix invalide. Veuillez entrer 1, 2 ou 3." }
    }
} while ($choice -ne "3")
