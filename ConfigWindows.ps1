# Chemin vers le fichier JSON (adapter si besoin)
$configPath = "C:\WindowsConfig\config.json"

# Lecture du fichier JSON
$config = Get-Content $configPath | ConvertFrom-Json

# 1. Changer le nom de l'ordinateur
Write-Host "Changement du nom de l'ordinateur en $($config.computerName)..."
Rename-Computer -NewName $config.computerName -Force -Restart:$false

# 2. Création des utilisateurs
foreach ($user in $config.users) {
    $username = $user.username
    $password = $user.password | ConvertTo-SecureString -AsPlainText -Force
    
    if (-not (Get-LocalUser -Name $username -ErrorAction SilentlyContinue)) {
        Write-Host "Création de l'utilisateur $username..."
        New-LocalUser -Name $username -Password $password -FullName $username -Description "Utilisateur créé par script"
        Add-LocalGroupMember -Group "Users" -Member $username
    } else {
        Write-Host "L'utilisateur $username existe déjà, saut de la création."
    }
}

# 3. Installation des applications via winget
foreach ($app in $config.apps) {
    Write-Host "Installation de $app via winget..."
    winget install --id=$app --accept-package-agreements --accept-source-agreements --silent
}

# 4. Exécution du script Win11Debloat de Raphire

Write-Host "Téléchargement et exécution du script Win11Debloat..."

# Téléchargement du script dans un dossier temporaire
$tempScriptPath = "$env:TEMP\Win11Debloat.ps1"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Raphire/Win11Debloat/main/Win11Debloat.ps1" -OutFile $tempScriptPath

# Exécution du script (tu peux ajouter des paramètres si besoin)
PowerShell -ExecutionPolicy Bypass -File $tempScriptPath

Write-Host "Configuration terminée. Un redémarrage peut être nécessaire."
