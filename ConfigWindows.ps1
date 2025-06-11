param(
    [string]$ConfigPath = ".\config.json"
)

# 1. Charger la config JSON
if (-Not (Test-Path $ConfigPath)) {
    Write-Error "Le fichier de configuration $ConfigPath n'existe pas."
    exit 1
}
$config = Get-Content $ConfigPath | ConvertFrom-Json

# 2. Renommer l'ordinateur
Write-Host "Changement du nom de l'ordinateur en $($config.computerName)..."
Rename-Computer -NewName $config.computerName -Force -Restart:$false

# 3. Création des utilisateurs
foreach ($user in $config.users) {
    $username = $user.username
    $password = $user.password | ConvertTo-SecureString -AsPlainText -Force
    $isAdmin = if ($user.isAdmin) { $true } else { $false }

    if (-not (Get-LocalUser -Name $username -ErrorAction SilentlyContinue)) {
        Write-Host "Création de l'utilisateur $username (Admin: $isAdmin)..."
        New-LocalUser -Name $username -Password $password -FullName $username -Description "Utilisateur créé par script"

        # Ajout au groupe approprié
        if ($isAdmin) {
            Add-LocalGroupMember -Group "Administrators" -Member $username
        } else {
            Add-LocalGroupMember -Group "Users" -Member $username
        }
    } else {
        Write-Host "L'utilisateur $username existe déjà, saut de la création."
    }
}

# 4. Installation des applications via winget
foreach ($app in $config.apps) {
    Write-Host "Installation de $app via winget..."
    winget install --id=$app --accept-package-agreements --accept-source-agreements --silent
}

# 5. Installation des softs locaux (dossier relatif ./softwares)
$localSoftDir = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Path) -ChildPath "softwares"
if (Test-Path $localSoftDir) {
    $files = Get-ChildItem -Path $localSoftDir -File -Include *.exe,*.msi,*.bat,*.ps1
    foreach ($file in $files) {
        Write-Host "Installation locale : $($file.Name)..."
        $filePath = $file.FullName

        switch ($file.Extension.ToLower()) {
            ".exe" {
                Start-Process -FilePath $filePath -ArgumentList "/S" -Wait
            }
            ".msi" {
                Start-Process msiexec.exe -ArgumentList "/i `"$filePath`" /quiet /norestart" -Wait
            }
            ".bat" {
                Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$filePath`"" -Wait
            }
            ".ps1" {
                powershell -ExecutionPolicy Bypass -File $filePath
            }
            default {
                Write-Warning "Type de fichier non supporté : $($file.Extension)"
            }
        }
    }
} else {
    Write-Host "Aucun dossier local 'softwares' trouvé, skipping installation locale."
}

# 6. Exécution du script Win11Debloat

Write-Host "Téléchargement et exécution du script Win11Debloat..."
if ($config.loadWin11Debloat) {
    $tempScriptPath = "$env:TEMP\Win11Debloat.ps1"
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Raphire/Win11Debloat/main/Win11Debloat.ps1" -OutFile $tempScriptPath

    PowerShell -ExecutionPolicy Bypass -File $tempScriptPath
}

Write-Host "Configuration terminée. Pense à redémarrer la machine."
