# scripts/cli/souq-interactive.ps1
$ErrorActionPreference = "Stop"

# =========================
# Config
# =========================
if (-not $env:PUBLISHER_URL) { $env:PUBLISHER_URL = "http://localhost:8082" }
if (-not $env:PLATFORM_URL)  { $env:PLATFORM_URL  = "http://localhost:8081" }

# =========================
# Session
# =========================
$script:CURRENT_EMAIL = $null
$script:CURRENT_USER_ID = $null
$script:CURRENT_ROLE = "NONE"  # NONE | USER | REDACTOR

# =========================
# Utils
# =========================
function Pause { Read-Host "Appuyez sur Entrée..." | Out-Null }

function Banner {
  Clear-Host
  Write-Host "====================================="
  Write-Host "     SouqStation Interactive CLI"
  Write-Host "====================================="
  if ($script:CURRENT_ROLE -eq "NONE") {
    Write-Host "Non connecté"
  } else {
    Write-Host ("Connecté en tant que: {0} [{1}] (userId={2})" -f $script:CURRENT_EMAIL, $script:CURRENT_ROLE, $script:CURRENT_USER_ID)
  }
  Write-Host "-------------------------------------"
}

function Prompt([string]$label, [string]$default="") {
  if ($default -ne "") {
    $v = Read-Host ("{0} [{1}]" -f $label, $default)
    if ([string]::IsNullOrWhiteSpace($v)) { return $default }
    return $v
  }
  return (Read-Host $label)
}

function HttpPostForm([string]$url, [hashtable]$body) {
  return Invoke-RestMethod -Method POST -Uri $url -Body $body -ContentType "application/x-www-form-urlencoded"
}

function ShowHttpError($err) {
  Write-Host ("HTTP Error: {0}" -f $err.Exception.Message)
  if ($err.Exception.Response) {
    try {
      $reader = New-Object System.IO.StreamReader($err.Exception.Response.GetResponseStream())
      $body = $reader.ReadToEnd()
      if (-not [string]::IsNullOrWhiteSpace($body)) {
        Write-Host "Response body:"
        Write-Host $body
      }
    } catch {}
  }
}

# =========================
# Register
# =========================
function ActionRegisterUser {
  $form = @{
    userId      = Prompt "ID_Utilisateur" "user-1"
    name        = Prompt "nom" "John Doe"
    email       = Prompt "email" "user@test.com"
    displayName = Prompt "pseudo" "JohnD"
    birth       = Prompt "Date de naissance (AAAA-MM-JJ)" "1990-01-01"
    solde       = Prompt "solde" "0.0"
  }

  try {
    $r = HttpPostForm "$($env:PLATFORM_URL)/platform/register-user" $form
    $r | ConvertTo-Json -Depth 10
    Write-Host "Utilisateur créé"
  } catch {
    ShowHttpError $_
  }

  Pause
}

function ActionRegisterRedactor {
  $form = @{
    userId      = Prompt "userId" "redactor-1"
    name        = Prompt "nom" "Jane Doe"
    email       = Prompt "email" "redactor@test.com"
    displayName = Prompt "pseudo" "JaneD"
    birth       = Prompt "Date de naissance (AAAA-MM-JJ)" "1985-01-01"
    solde       = Prompt "solde" "0.0"
    individual  = Prompt "Particulier (true/false)" "true"
  }

  try {
    $r = HttpPostForm "$($env:PLATFORM_URL)/platform/register-redactor" $form
    $r | ConvertTo-Json -Depth 10
    Write-Host "Éditeur créé"
  } catch {
    ShowHttpError $_
  }

  Pause
}

# =========================
# Connexion / Déconnexion
# =========================
function Connexion {
  $email = Prompt "email" "redactor@test.com"

  try {
    $checkUrl = "$($env:PLATFORM_URL)/platform/users/check-email?email=$email"
    $r = Invoke-RestMethod -Method GET -Uri $checkUrl

    if (-not $r.exists) {
      Write-Host "Utilisateur introuvable"
      Pause
      return
    }

    $script:CURRENT_EMAIL = $email
    $script:CURRENT_USER_ID = [string]$r.userId

    $redUrl = "$($env:PLATFORM_URL)/platform/redactors/exists?userId=$($script:CURRENT_USER_ID)"
    $rr = Invoke-RestMethod -Method GET -Uri $redUrl

    if ($rr.exists -eq $true) {
      $script:CURRENT_ROLE = "REDACTOR"
      Write-Host "Bienvenue éditeur"
      # UX count (optional)
      try {
        $countUrl = "$($env:PUBLISHER_URL)/publisher/games/count?idEditeur=$($script:CURRENT_USER_ID)"
        $count = Invoke-RestMethod -Method GET -Uri $countUrl
        Write-Host ("You published {0} games" -f $count)
      } catch {}
    } else {
      $script:CURRENT_ROLE = "USER"
      Write-Host "Bienvenue utilisateur"
    }
  } catch {
    ShowHttpError $_
  }

  Pause
}

function Déconnexion {
  $script:CURRENT_EMAIL = $null
  $script:CURRENT_USER_ID = $null
  $script:CURRENT_ROLE = "NONE"
  Write-Host "Déconnecté"
  Pause
}

# =========================
# Social: Follow / Following
# =========================
function FollowUser {
  if ($script:CURRENT_ROLE -eq "NONE") {
    Write-Host "Veuillez d'abord vous connecter."
    Pause
    return
  }

  $followedId = Prompt "ID de l'utilisateur à suivre" "U200"

  if ($followedId -eq $script:CURRENT_USER_ID) {
    Write-Host "Vous ne pouvez pas vous suivre vous-même."
    Pause
    return
  }

  try {
    $url = "$($env:PLATFORM_URL)/platform/users/follow"
    $r = HttpPostForm $url @{ userId = $script:CURRENT_USER_ID; followedId = $followedId }
    $r | ConvertTo-Json -Depth 10
    Write-Host ("Vous suivez maintenant {0}" -f $followedId)
  } catch {
    ShowHttpError $_
  }

  Pause
}

function ShowFollowing {
  if ($script:CURRENT_ROLE -eq "NONE") {
    Write-Host "Veuillez d'abord vous connecter."
    Pause
    return
  }

  try {
    $url = "$($env:PLATFORM_URL)/platform/users/following?userId=$($script:CURRENT_USER_ID)"
    $r = Invoke-RestMethod -Method GET -Uri $url

    if ($null -eq $r -or $r.Count -eq 0) {
      Write-Host "Aucun abonnement pour le moment."
    } else {
      Write-Host ""
      Write-Host "Abonnements:"
      foreach ($u in $r) {
        Write-Host "----------------------"
        Write-Host ("userId: {0}" -f $u.userId)
        if ($u.displayName) { Write-Host ("displayNom: {0}" -f $u.displayName) }
      }
    }
  } catch {
    ShowHttpError $_
  }

  Pause
}

# =========================
# Publisher (redactor only)
# =========================
function PublishGame {
  if ($script:CURRENT_ROLE -ne "REDACTOR") {
    Write-Host "La publication est réservée aux ÉDITEURS."
    Pause
    return
  }

  $form = @{
    gameId      = Prompt "ID_Jeu" "game-100"
    title       = Prompt "titre" "Halo"
    description = Prompt "description" ""
    platform    = (Prompt "plateforme" "PC").ToUpper()
    genre       = (Prompt "genre" "ACTION").ToUpper()
    idEditeur   = $script:CURRENT_USER_ID
    version     = Prompt "version" "1.0.0"
    releaseDate = Prompt "Date de sortie (AAAA-MM-JJ)" "2026-01-01"
  }

  $price = Prompt "prix initial (optionnel)" ""
  if ($price -ne "") { $form.price = $price }

  try {
    $url = "$($env:PUBLISHER_URL)/publisher/publish-game"
    $r = HttpPostForm $url $form
    $r | ConvertTo-Json -Depth 10
    Write-Host "Game published"
  } catch {
    ShowHttpError $_
  }

  Pause
}

function MyGames {
  if ($script:CURRENT_ROLE -ne "REDACTOR") {
    Write-Host "Mes jeux is only for REDACTOR."
    Pause
    return
  }

  try {
    $url = "$($env:PUBLISHER_URL)/publisher/games/by-publisher?idEditeur=$($script:CURRENT_USER_ID)"
    $games = Invoke-RestMethod -Method GET -Uri $url

    if ($null -eq $games -or $games.Count -eq 0) {
      Write-Host "Aucun jeu pour l'instant"
    } else {
      foreach ($g in $games) {
        Write-Host "----------------------"
        Write-Host ("{0} ({1})" -f $g.title, $g.gameId)
        Write-Host ("Plateforme: {0}" -f $g.platform)
        Write-Host ("Genre: {0}" -f $g.genre)
        Write-Host ("Version: {0}" -f $g.version)
      }
    }
  } catch {
    ShowHttpError $_
  }

  Pause
}
function FollowRedactor {

  if ($script:CURRENT_ROLE -eq "NONE") {
    Write-Host "Connexion first"
    Pause
    return
  }

  $redactorId = Prompt "ID de l'éditeur à suivre" "redactor-1"

  try {
    $url = "$($env:PLATFORM_URL)/platform/users/follow-redactor"
    HttpPostForm $url @{
      userId = $script:CURRENT_USER_ID
      redactorId = $redactorId
    } | ConvertTo-Json -Depth 10

    Write-Host "Éditeur suivi $redactorId"
  }
  catch {
    ShowHttpError $_
  }

  Pause
}
function ShowGamesOfFollowedEditor {

  if ($script:CURRENT_ROLE -eq "NONE") {
    Write-Host "Connexion first"
    Pause
    return
  }

  # 1) récupérer les éditeurs suivis
  try {
    $editorsUrl = "$($env:PLATFORM_URL)/platform/users/following-redactors?userId=$($script:CURRENT_USER_ID)"
    $editors = Invoke-RestMethod -Method GET -Uri $editorsUrl
  } catch {
    ShowHttpError $_
    Pause
    return
  }

  if ($null -eq $editors -or $editors.Count -eq 0) {
    Write-Host "Vous ne suivez encore aucun éditeur."
    Pause
    return
  }

  Write-Host ""
  Write-Host "Éditeurs que vous suivez:"
  $i = 1
  foreach ($e in $editors) {
    Write-Host ("{0}) {1} ({2})" -f $i, $e.displayName, $e.userId)
    $i++
  }

  # 2) choisir un éditeur (par index ou id)
  $choice = Prompt "Entrez le numéro ou l'ID de l'éditeur" "1"
  $editorId = $null

  if ($choice -match '^\d+$') {
    $idx = [int]$choice
    if ($idx -lt 1 -or $idx -gt $editors.Count) {
      Write-Host "Numéro invalide"
      Pause
      return
    }
    $editorId = $editors[$idx - 1].userId
  } else {
    $editorId = $choice
  }

  # 3) appeler publisher pour récupérer les jeux
  try {
    $gamesUrl = "$($env:PUBLISHER_URL)/publisher/games/by-publisher?idEditeur=$editorId"
    $games = Invoke-RestMethod -Method GET -Uri $gamesUrl
  } catch {
    ShowHttpError $_
    Pause
    return
  }

  Write-Host ""
  Write-Host ("Jeux publiés par {0}:" -f $editorId)

  if ($null -eq $games -or $games.Count -eq 0) {
    Write-Host "Aucun jeu trouvé."
    Pause
    return
  }

  foreach ($g in $games) {
    Write-Host "----------------------"
    Write-Host ("{0} ({1})" -f $g.title, $g.gameId)
    Write-Host ("Plateforme: {0}" -f $g.platform)
    Write-Host ("Genre: {0}" -f $g.genre)
    Write-Host ("Version: {0}" -f $g.version)
    if ($g.price -ne $null) { Write-Host ("Prix: {0}" -f $g.price) }
    if ($g.releaseDate -ne $null) { Write-Host ("Date de sortie: {0}" -f $g.releaseDate) }
  }

  Pause
}
function ShowFollowedRedactors {

  if ($script:CURRENT_ROLE -eq "NONE") {
    Write-Host "Connexion first"
    Pause
    return
  }

  try {
    $url = "$($env:PLATFORM_URL)/platform/users/following-redactors?userId=$($script:CURRENT_USER_ID)"
    $r = Invoke-RestMethod -Method GET -Uri $url

    if ($r.Count -eq 0) {
      Write-Host "Aucun éditeur suivi"
    }
    else {
      Write-Host "Éditeurs que vous suivez:"
      foreach ($u in $r) {
        Write-Host "----------------"
        Write-Host "Id: $($u.userId)"
        Write-Host "Nom: $($u.displayName)"
      }
    }
  }
  catch {
    ShowHttpError $_
  }

  Pause
}

# =========================
# Menu
# =========================
function Menu {

  if ($script:CURRENT_ROLE -eq "NONE") {
    Write-Host "1) Créer un utilisateur (User)"
    Write-Host "2) Créer un éditeur (Redactor)"
    Write-Host "3) Connexion"
    Write-Host "0) Quitter"
    return
  }

  # USER et REDACTOR → social toujours visible
  Write-Host "1) Suivre un utilisateur"
  Write-Host "2) Afficher les abonnements (Users)"
  Write-Host "3) Suivre un éditeur"
  Write-Host "4) Afficher les éditeurs suivis"
  Write-Host "5) Voir les jeux d'un éditeur suivi"

  if ($script:CURRENT_ROLE -eq "REDACTOR") {
    Write-Host "6) Publier un jeu"
    Write-Host "7) Mes jeux"
    Write-Host "8) Déconnexion"
  } else {
    Write-Host "6) Déconnexion"
  }
  Write-Host "0) Quitter"
}

# =========================
# Main loop
# =========================
while ($true) {

  Banner
  Menu
  $c = Read-Host "Choix"

  # =====================
  # NON CONNECTÉ
  # =====================
  if ($script:CURRENT_ROLE -eq "NONE") {

    if ($c -eq "1") { ActionRegisterUser }
    elseif ($c -eq "2") { ActionRegisterRedactor }
    elseif ($c -eq "3") { Connexion }
    elseif ($c -eq "0") { break }
    else { Write-Host "Choix invalide"; Pause }

    continue
  }

  # =====================
  # CONNECTÉ (USER ou REDACTOR)
  # =====================

  if ($c -eq "1") {
    FollowUser
    continue
  }

  if ($c -eq "2") {
    ShowFollowing
    continue
  }

  if ($c -eq "3") {
    FollowRedactor
    continue
  }

  if ($c -eq "4") {
    ShowFollowedRedactors
    continue
  }
  if ($c -eq "5") {
    ShowGamesOfFollowedEditor
    continue
  }
  # =====================
  # REDACTOR uniquement
  # =====================
  if ($script:CURRENT_ROLE -eq "REDACTOR") {

    if ($c -eq "5") {
      PublishGame
      continue
    }

    if ($c -eq "6") {
      MyGames
      continue
    }

    if ($c -eq "7") {
      Déconnexion
      continue
    }
  }
  else {
    # USER logout
    if ($c -eq "5") {
      Déconnexion
      continue
    }
  }

  if ($c -eq "0") { break }

  Write-Host "Choix invalide"
  Pause
}