# scripts/cli/souq-interactive.ps1
# SouqStationStore Interactive CLI (updated with new features: catalog, purchases, library, reviews, incidents, patches, DLCs, notifications)
$ErrorActionPreference = "Stop"

# =========================
# Config
# =========================
if (-not $env:PUBLISHER_URL) { $env:PUBLISHER_URL = "http://localhost:8082" }
if (-not $env:PLATFORM_URL)  { $env:PLATFORM_URL  = "http://localhost:8081" }
if (-not $env:NOTIF_URL)     { $env:NOTIF_URL     = "http://localhost:8083" } # si votre notification-service est ailleurs, changez ici

# Needed for UrlEncode
try { Add-Type -AssemblyName System.Web | Out-Null } catch {}

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

function UrlEncode([string]$s) {
  if ($null -eq $s) { return "" }
  try { return [System.Web.HttpUtility]::UrlEncode($s) } catch { return $s }
}

function BuildFormUrlEncoded {
  param(
    [hashtable]$Body,
    [hashtable]$Multi = @{}  # Multi["modifications"] = @("CORRECTION","OPTIMISATION")
  )
  $pairs = New-Object System.Collections.Generic.List[string]
  if ($Body) {
    foreach ($k in $Body.Keys) {
      $pairs.Add(("{0}={1}" -f (UrlEncode $k), (UrlEncode ([string]$Body[$k]))))
    }
  }
  if ($Multi) {
    foreach ($k in $Multi.Keys) {
      $arr = $Multi[$k]
      if ($arr -is [System.Array]) {
        foreach ($v in $arr) {
          $pairs.Add(("{0}={1}" -f (UrlEncode $k), (UrlEncode ([string]$v))))
        }
      } else {
        $pairs.Add(("{0}={1}" -f (UrlEncode $k), (UrlEncode ([string]$arr))))
      }
    }
  }
  return ($pairs -join "&")
}

function HttpPostForm([string]$url, [hashtable]$body) {
  return Invoke-RestMethod -Method POST -Uri $url -Body $body -ContentType "application/x-www-form-urlencoded"
}

function HttpPostFormMulti([string]$url, [hashtable]$body, [hashtable]$multi) {
  $encoded = BuildFormUrlEncoded -Body $body -Multi $multi
  return Invoke-RestMethod -Method POST -Uri $url -Body $encoded -ContentType "application/x-www-form-urlencoded"
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
  } catch { ShowHttpError $_ }

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
  } catch { ShowHttpError $_ }

  Pause
}

# =========================
# Connexion / Déconnexion
# =========================
function Connexion {
  $email = Prompt "email" "redactor@test.com"

  try {
    $checkUrl = "$($env:PLATFORM_URL)/platform/users/check-email?email=$(UrlEncode $email)"
    $r = Invoke-RestMethod -Method GET -Uri $checkUrl

    if (-not $r.exists) {
      Write-Host "Utilisateur introuvable"
      Pause
      return
    }

    $script:CURRENT_EMAIL = $email
    $script:CURRENT_USER_ID = [string]$r.userId

    $redUrl = "$($env:PLATFORM_URL)/platform/redactors/exists?userId=$(UrlEncode $($script:CURRENT_USER_ID))"
    $rr = Invoke-RestMethod -Method GET -Uri $redUrl

    if ($rr.exists -eq $true) {
      $script:CURRENT_ROLE = "REDACTOR"
      Write-Host "Bienvenue éditeur"
      # UX count (optional)
      try {
        $countUrl = "$($env:PUBLISHER_URL)/publisher/games/count?idEditeur=$(UrlEncode $($script:CURRENT_USER_ID))"
        $count = Invoke-RestMethod -Method GET -Uri $countUrl
        Write-Host ("You published {0} games" -f $count)
      } catch {}
    } else {
      $script:CURRENT_ROLE = "USER"
      Write-Host "Bienvenue utilisateur"
    }
  } catch { ShowHttpError $_ }

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
  if ($script:CURRENT_ROLE -eq "NONE") { Write-Host "Veuillez d'abord vous connecter."; Pause; return }

  $followedId = Prompt "ID de l'utilisateur à suivre" "U200"
  if ($followedId -eq $script:CURRENT_USER_ID) { Write-Host "Vous ne pouvez pas vous suivre vous-même."; Pause; return }

  try {
    $url = "$($env:PLATFORM_URL)/platform/users/follow"
    $r = HttpPostForm $url @{ userId = $script:CURRENT_USER_ID; followedId = $followedId }
    $r | ConvertTo-Json -Depth 10
    Write-Host ("Vous suivez maintenant {0}" -f $followedId)
  } catch { ShowHttpError $_ }

  Pause
}

function ShowFollowing {
  if ($script:CURRENT_ROLE -eq "NONE") { Write-Host "Veuillez d'abord vous connecter."; Pause; return }

  try {
    $url = "$($env:PLATFORM_URL)/platform/users/following?userId=$(UrlEncode $($script:CURRENT_USER_ID))"
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
  } catch { ShowHttpError $_ }

  Pause
}

function FollowRedactor {
  if ($script:CURRENT_ROLE -eq "NONE") { Write-Host "Connexion first"; Pause; return }

  $redactorId = Prompt "ID de l'éditeur à suivre" "redactor-1"

  try {
    $url = "$($env:PLATFORM_URL)/platform/users/follow-redactor"
    HttpPostForm $url @{ userId = $script:CURRENT_USER_ID; redactorId = $redactorId } | ConvertTo-Json -Depth 10
    Write-Host "Éditeur suivi $redactorId"
  } catch { ShowHttpError $_ }

  Pause
}

function ShowFollowedRedactors {
  if ($script:CURRENT_ROLE -eq "NONE") { Write-Host "Connexion first"; Pause; return }

  try {
    $url = "$($env:PLATFORM_URL)/platform/users/following-redactors?userId=$(UrlEncode $($script:CURRENT_USER_ID))"
    $r = Invoke-RestMethod -Method GET -Uri $url

    if ($null -eq $r -or $r.Count -eq 0) {
      Write-Host "Aucun éditeur suivi"
    } else {
      Write-Host "Éditeurs que vous suivez:"
      foreach ($u in $r) {
        Write-Host "----------------"
        Write-Host "Id: $($u.userId)"
        Write-Host "Nom: $($u.displayName)"
      }
    }
  } catch { ShowHttpError $_ }

  Pause
}

function ShowGamesOfFollowedEditor {
  if ($script:CURRENT_ROLE -eq "NONE") { Write-Host "Connexion first"; Pause; return }

  # 1) récupérer les éditeurs suivis
  try {
    $editorsUrl = "$($env:PLATFORM_URL)/platform/users/following-redactors?userId=$(UrlEncode $($script:CURRENT_USER_ID))"
    $editors = Invoke-RestMethod -Method GET -Uri $editorsUrl
  } catch { ShowHttpError $_; Pause; return }

  if ($null -eq $editors -or $editors.Count -eq 0) { Write-Host "Vous ne suivez encore aucun éditeur."; Pause; return }

  Write-Host ""
  Write-Host "Éditeurs que vous suivez:"
  $i = 1
  foreach ($e in $editors) { Write-Host ("{0}) {1} ({2})" -f $i, $e.displayName, $e.userId); $i++ }

  # 2) choisir un éditeur
  $choice = Prompt "Entrez le numéro ou l'ID de l'éditeur" "1"
  $editorId = $null

  if ($choice -match '^\d+$') {
    $idx = [int]$choice
    if ($idx -lt 1 -or $idx -gt $editors.Count) { Write-Host "Numéro invalide"; Pause; return }
    $editorId = $editors[$idx - 1].userId
  } else { $editorId = $choice }

  # 3) appeler publisher pour récupérer les jeux
  try {
    $gamesUrl = "$($env:PUBLISHER_URL)/publisher/games/by-publisher?idEditeur=$(UrlEncode $editorId)"
    $games = Invoke-RestMethod -Method GET -Uri $gamesUrl
  } catch { ShowHttpError $_; Pause; return }

  Write-Host ""
  Write-Host ("Jeux publiés par {0}:" -f $editorId)

  if ($null -eq $games -or $games.Count -eq 0) { Write-Host "Aucun jeu trouvé."; Pause; return }

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

# =========================
# Publisher (redactor only) - existing
# =========================
function PublishGame {
  if ($script:CURRENT_ROLE -ne "REDACTOR") { Write-Host "La publication est réservée aux ÉDITEURS."; Pause; return }

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

  # compat: certains endpoints attendent "price", d'autres "prixInit"
  $price = Prompt "prix initial (optionnel)" ""
  if ($price -ne "") {
    $form.price = $price
    $form.prixInit = $price
  }

  try {
    $url = "$($env:PUBLISHER_URL)/publisher/publish-game"
    $r = HttpPostForm $url $form
    $r | ConvertTo-Json -Depth 10
    Write-Host "Game published"
  } catch { ShowHttpError $_ }

  Pause
}

function MyGames {
  if ($script:CURRENT_ROLE -ne "REDACTOR") { Write-Host "Mes jeux is only for REDACTOR."; Pause; return }

  try {
    $url = "$($env:PUBLISHER_URL)/publisher/games/by-publisher?idEditeur=$(UrlEncode $($script:CURRENT_USER_ID))"
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
  } catch { ShowHttpError $_ }

  Pause
}

# =========================
# NEW: Catalog (platform)
# =========================
function CatalogListGames {
  if ($script:CURRENT_ROLE -eq "NONE") { Write-Host "Veuillez d'abord vous connecter."; Pause; return }

  $genre = (Prompt "Filtre genre (optionnel)" "").ToUpper()
  $platform = (Prompt "Filtre plateforme (optionnel)" "").ToUpper()
  $maxPrice = Prompt "Filtre prix max (optionnel)" ""

  $qs = @()
  if ($genre -ne "") { $qs += "genre=$(UrlEncode $genre)" }
  if ($platform -ne "") { $qs += "platform=$(UrlEncode $platform)" }
  if ($maxPrice -ne "") { $qs += "maxPrice=$(UrlEncode $maxPrice)" }
  $query = ""
  if ($qs.Count -gt 0) { $query = "?" + ($qs -join "&") }

  try {
    $url = "$($env:PLATFORM_URL)/platform/catalog/games$query"

    $resp = Invoke-RestMethod -Method GET -Uri $url

    $items = $resp.games
    if ($null -eq $items -or $items.Count -eq 0) {
      Write-Host "Aucun jeu dans le catalogue."
    } else {
      Write-Host ("Catalogue: {0} jeu(x)" -f $resp.totalGames)
      foreach ($g in $items) {
        Write-Host "----------------------"
        Write-Host ("{0} ({1})" -f $g.title, $g.gameId)
        if ($g.platform) { Write-Host ("Plateforme: {0}" -f $g.platform) }
        if ($g.genre) { Write-Host ("Genre: {0}" -f $g.genre) }
        if ($g.price -ne $null) { Write-Host ("Prix: {0}" -f $g.price) }
        if ($g.releaseDate) { Write-Host ("Sortie: {0}" -f $g.releaseDate) }
      }
    }
  } catch { ShowHttpError $_ }

  Pause
}

function CatalogGameDetails {
  if ($script:CURRENT_ROLE -eq "NONE") { Write-Host "Veuillez d'abord vous connecter."; Pause; return }

  $gameId = Prompt "GameId" "G300"

  try {
    $url = "$($env:PLATFORM_URL)/platform/catalog/games/$(UrlEncode $gameId)"
    $g = Invoke-RestMethod -Method GET -Uri $url
    $g | ConvertTo-Json -Depth 10
  } catch { ShowHttpError $_ }

  Pause
}

# =========================
# NEW: Purchases & Library (platform)
# =========================
function BuyGame {
  if ($script:CURRENT_ROLE -eq "NONE") { Write-Host "Veuillez d'abord vous connecter."; Pause; return }
  $gameId = Prompt "GameId à acheter" "G300"

  try {
    $url = "$($env:PLATFORM_URL)/platform/purchases/game"
    $r = HttpPostForm $url @{ userId = $script:CURRENT_USER_ID; gameId = $gameId }
    $r | ConvertTo-Json -Depth 10
    Write-Host "Achat effectué (si solde/conditions OK)"
  } catch { ShowHttpError $_ }

  Pause
}

function MyLibrary {
  if ($script:CURRENT_ROLE -eq "NONE") { Write-Host "Veuillez d'abord vous connecter."; Pause; return }

  try {
    $url = "$($env:PLATFORM_URL)/platform/purchases/library?userId=$(UrlEncode $($script:CURRENT_USER_ID))"
    $lib = Invoke-RestMethod -Method GET -Uri $url
    $lib | ConvertTo-Json -Depth 10
  } catch { ShowHttpError $_ }

  Pause
}

function BuyDlc {
  if ($script:CURRENT_ROLE -eq "NONE") { Write-Host "Veuillez d'abord vous connecter."; Pause; return }
  $gameId = Prompt "GameId" "G300"
  $dlcId  = Prompt "DlcId" "DLC-1"

  try {
    $url = "$($env:PLATFORM_URL)/platform/purchases/dlc"
    $r = HttpPostForm $url @{ userId = $script:CURRENT_USER_ID; gameId = $gameId; dlcId = $dlcId }
    $r | ConvertTo-Json -Depth 10
    Write-Host "Achat DLC effectué (si OK)"
  } catch { ShowHttpError $_ }

  Pause
}

function MyDlcs {
  if ($script:CURRENT_ROLE -eq "NONE") { Write-Host "Veuillez d'abord vous connecter."; Pause; return }

  try {
    $url = "$($env:PLATFORM_URL)/platform/purchases/dlc-library?userId=$(UrlEncode $($script:CURRENT_USER_ID))"
    $dlcs = Invoke-RestMethod -Method GET -Uri $url
    $dlcs | ConvertTo-Json -Depth 10
  } catch { ShowHttpError $_ }

  Pause
}

function CheckOwnership {
  if ($script:CURRENT_ROLE -eq "NONE") { Write-Host "Veuillez d'abord vous connecter."; Pause; return }
  $gameId = Prompt "GameId" "G300"

  try {
    $url = "$($env:PLATFORM_URL)/platform/purchases/owns?userId=$(UrlEncode $($script:CURRENT_USER_ID))&gameId=$(UrlEncode $gameId)"
    $owns = Invoke-RestMethod -Method GET -Uri $url
    $owns | ConvertTo-Json -Depth 10
  } catch { ShowHttpError $_ }

  Pause
}

function GameSalesCount {
  if ($script:CURRENT_ROLE -eq "NONE") { Write-Host "Veuillez d'abord vous connecter."; Pause; return }
  $gameId = Prompt "GameId" "G300"

  try {
    $url = "$($env:PLATFORM_URL)/platform/purchases/sales-count?gameId=$(UrlEncode $gameId)"
    $c = Invoke-RestMethod -Method GET -Uri $url
    $c | ConvertTo-Json -Depth 10
  } catch { ShowHttpError $_ }

  Pause
}

# =========================
# NEW: Reviews (platform)
# =========================
function SubmitReview {
  if ($script:CURRENT_ROLE -eq "NONE") { Write-Host "Veuillez d'abord vous connecter."; Pause; return }

  $gameId = Prompt "GameId" "G300"
  $note = Prompt "Note (0-10)" "9"
  $desc = Prompt "Description" "Incroyable !"

  try {
    $url = "$($env:PLATFORM_URL)/platform/reviews/submit"
    $r = HttpPostForm $url @{ userId = $script:CURRENT_USER_ID; gameId = $gameId; note = $note; description = $desc }
    $r | ConvertTo-Json -Depth 10
    Write-Host "Avis envoyé"
  } catch { ShowHttpError $_ }

  Pause
}

function RateReviewHelpful {
  if ($script:CURRENT_ROLE -eq "NONE") { Write-Host "Veuillez d'abord vous connecter."; Pause; return }

  $reviewId = Prompt "ReviewId" ""
  if ([string]::IsNullOrWhiteSpace($reviewId)) { Write-Host "ReviewId requis"; Pause; return }

  $isHelpful = (Prompt "Utile ? (true/false)" "true").ToLower()

  try {
    $url = "$($env:PLATFORM_URL)/platform/reviews/$(UrlEncode $reviewId)/rate"
    $r = HttpPostForm $url @{ userId = $script:CURRENT_USER_ID; isHelpful = $isHelpful }
    $r | ConvertTo-Json -Depth 10
    Write-Host "Vote enregistré"
  } catch { ShowHttpError $_ }

  Pause
}

function ListReviewsByGame {
  if ($script:CURRENT_ROLE -eq "NONE") { Write-Host "Veuillez d'abord vous connecter."; Pause; return }

  $gameId = Prompt "GameId" "G300"
  try {
    $url = "$($env:PLATFORM_URL)/platform/reviews/game/$(UrlEncode $gameId)"
    $r = Invoke-RestMethod -Method GET -Uri $url
    $r | ConvertTo-Json -Depth 10
  } catch { ShowHttpError $_ }

  Pause
}

function ListReviewsByUser {
  if ($script:CURRENT_ROLE -eq "NONE") { Write-Host "Veuillez d'abord vous connecter."; Pause; return }

  $userId = Prompt "UserId (laisser vide = moi)" ""
  if ([string]::IsNullOrWhiteSpace($userId)) { $userId = $script:CURRENT_USER_ID }

  try {
    $url = "$($env:PLATFORM_URL)/platform/reviews/user/$(UrlEncode $userId)"
    $r = Invoke-RestMethod -Method GET -Uri $url
    $r | ConvertTo-Json -Depth 10
  } catch { ShowHttpError $_ }

  Pause
}

# =========================
# NEW: Incidents (platform)
# =========================
function ReportIncident {
  if ($script:CURRENT_ROLE -eq "NONE") { Write-Host "Veuillez d'abord vous connecter."; Pause; return }

  $gameId = Prompt "GameId" "G300"
  $severity = (Prompt "Sévérité (HAUTE/NORMALE/BASSE/CRITIQUE)" "HAUTE").ToUpper()
  $desc = Prompt "Description" "Crashs intempestifs"
  $envt = Prompt "Environment" "Windows 11"

  try {
    $url = "$($env:PLATFORM_URL)/platform/incidents/report"
    $r = HttpPostForm $url @{
      userId = $script:CURRENT_USER_ID
      gameId = $gameId
      severity = $severity
      description = $desc
      environment = $envt
    }
    $r | ConvertTo-Json -Depth 10
    Write-Host "Incident signalé"
  } catch { ShowHttpError $_ }

  Pause
}

function ListIncidentsByGame {
  if ($script:CURRENT_ROLE -eq "NONE") { Write-Host "Veuillez d'abord vous connecter."; Pause; return }

  $gameId = Prompt "GameId" "G300"
  $severity = (Prompt "Filtre sévérité (optionnel)" "").ToUpper()

  $q = ""
  if ($severity -ne "") { $q = "?severity=$(UrlEncode $severity)" }

  try {
    $url = "$($env:PLATFORM_URL)/platform/incidents/game/$(UrlEncode $gameId)$q"
    $r = Invoke-RestMethod -Method GET -Uri $url
    $r | ConvertTo-Json -Depth 10
  } catch { ShowHttpError $_ }

  Pause
}

function CountIncidentsByGame {
  if ($script:CURRENT_ROLE -eq "NONE") { Write-Host "Veuillez d'abord vous connecter."; Pause; return }

  $gameId = Prompt "GameId" "G300"
  try {
    $url = "$($env:PLATFORM_URL)/platform/incidents/game/$(UrlEncode $gameId)/count"
    $r = Invoke-RestMethod -Method GET -Uri $url
    $r | ConvertTo-Json -Depth 10
  } catch { ShowHttpError $_ }

  Pause
}

# =========================
# NEW: Publisher - Patch & DLC (redactor)
# =========================
function PublishPatch {
  if ($script:CURRENT_ROLE -ne "REDACTOR") { Write-Host "Réservé aux ÉDITEURS."; Pause; return }

  $gameId = Prompt "GameId" "G300"
  $targetVersion = Prompt "Target version" "1.0.1"
  $patchNotes = Prompt "Patch notes" "Correction du crash sous Windows 11"
  $releasedAt = Prompt "ReleasedAt (AAAA-MM-JJ)" "2025-11-20"

  # multi valeurs (ex: CORRECTION, OPTIMISATION, AJOUT, etc.)
  $modsRaw = Prompt "Modifications (séparées par virgule)" "CORRECTION,OPTIMISATION"
  $mods = $modsRaw.Split(",") | ForEach-Object { $_.Trim().ToUpper() } | Where-Object { $_ -ne "" }

  try {
    $url = "$($env:PUBLISHER_URL)/publisher/publish-patch"
    $r = HttpPostFormMulti $url `
      @{ gameId = $gameId; targetVersion = $targetVersion; patchNotes = $patchNotes; releasedAt = $releasedAt } `
      @{ modifications = $mods }
    $r | ConvertTo-Json -Depth 10
    Write-Host "Patch publié"
  } catch { ShowHttpError $_ }

  Pause
}

function ListPatchesForGame {
  if ($script:CURRENT_ROLE -ne "REDACTOR") { Write-Host "Réservé aux ÉDITEURS."; Pause; return }
  $gameId = Prompt "GameId" "G300"

  try {
    $url = "$($env:PUBLISHER_URL)/publisher/games/$(UrlEncode $gameId)/patches"
    $r = Invoke-RestMethod -Method GET -Uri $url
    $r | ConvertTo-Json -Depth 10
  } catch { ShowHttpError $_ }

  Pause
}

function PublishDlc {
  if ($script:CURRENT_ROLE -ne "REDACTOR") { Write-Host "Réservé aux ÉDITEURS."; Pause; return }

  # NB: selon votre implémentation, les champs peuvent varier.
  # On propose un set "classique" ; adaptez si nécessaire.
  $gameId = Prompt "GameId" "G300"
  $dlcId = Prompt "DlcId" "DLC-1"
  $title = Prompt "Titre DLC" "Expansion Pack"
  $desc = Prompt "Description" "Nouveau contenu"
  $price = Prompt "Prix" "9.99"
  $releasedAt = Prompt "ReleasedAt (AAAA-MM-JJ)" "2025-12-01"

  try {
    $url = "$($env:PUBLISHER_URL)/publisher/publish-dlc"
    $r = HttpPostForm $url @{
      gameId      = $gameId
      dlcId       = $dlcId
      name        = $title
      description = $desc
      price       = $price
      publisherId = $script:CURRENT_USER_ID
    }
    $r | ConvertTo-Json -Depth 10
    Write-Host "DLC publié"
  } catch { ShowHttpError $_ }

  Pause
}

function ListDlcsForGamePublisher {
  if ($script:CURRENT_ROLE -ne "REDACTOR") { Write-Host "Réservé aux ÉDITEURS."; Pause; return }
  $gameId = Prompt "GameId" "G300"

  try {
    $url = "$($env:PUBLISHER_URL)/publisher/games/$(UrlEncode $gameId)/dlcs"
    $resp = Invoke-RestMethod -Method GET -Uri $url

    $items = $resp.dlcs
    if ($null -eq $items -or $items.Count -eq 0) {
      Write-Host "Aucun DLC pour ce jeu."
    } else {
      Write-Host ("DLCs pour {0}: {1}" -f $resp.gameId, $resp.dlcCount)
      foreach ($d in $items) {
        Write-Host "----------------------"
        Write-Host ("{0} ({1})" -f $d.name, $d.dlcId)
        if ($d.price -ne $null) { Write-Host ("Prix: {0}" -f $d.price) }
        if ($d.releaseDate) { Write-Host ("Sortie: {0}" -f $d.releaseDate) }
      }
    }
  } catch { ShowHttpError $_ }

  Pause
}

# =========================
# NEW: Notifications
# =========================
function MyNotifications {
  if ($script:CURRENT_ROLE -eq "NONE") { Write-Host "Veuillez d'abord vous connecter."; Pause; return }

  try {
    $url = "$($env:NOTIF_URL)/notifications/$(UrlEncode $($script:CURRENT_USER_ID))"
    $r = Invoke-RestMethod -Method GET -Uri $url
    $r | ConvertTo-Json -Depth 10
  } catch { ShowHttpError $_ }

  Pause
}

# =========================
# NEW: Gameplay Sessions (/platform/sessions)
# =========================
function StartGameSession {
  if ($script:CURRENT_ROLE -eq "NONE") { Write-Host "Veuillez d'abord vous connecter."; Pause; return }

  $gameId = Prompt "GameId" "G300"

  try {
    $url = "$($env:PLATFORM_URL)/platform/sessions/start"
    $r = HttpPostForm $url @{ userId = $script:CURRENT_USER_ID; gameId = $gameId }
    $r | ConvertTo-Json -Depth 10
    Write-Host "Session démarrée"
  } catch { ShowHttpError $_ }

  Pause
}

function EndGameSession {
  if ($script:CURRENT_ROLE -eq "NONE") { Write-Host "Veuillez d'abord vous connecter."; Pause; return }

  $gameId = Prompt "GameId" "G300"

  try {
    $url = "$($env:PLATFORM_URL)/platform/sessions/end"
    $r = HttpPostForm $url @{ userId = $script:CURRENT_USER_ID; gameId = $gameId }
    $r | ConvertTo-Json -Depth 10
    Write-Host "Session terminée"
  } catch { ShowHttpError $_ }

  Pause
}

function MyPlaytime {
  if ($script:CURRENT_ROLE -eq "NONE") { Write-Host "Veuillez d'abord vous connecter."; Pause; return }

  $gameId = Prompt "GameId (optionnel, vide = tout)" ""
  $q = ""
  if (-not [string]::IsNullOrWhiteSpace($gameId)) {
    $q = "?gameId=$(UrlEncode $gameId)"
  }

  try {
    $url = "$($env:PLATFORM_URL)/platform/sessions/users/$(UrlEncode $($script:CURRENT_USER_ID))/playtime$q"
    $r = Invoke-RestMethod -Method GET -Uri $url
    $r | ConvertTo-Json -Depth 10
  } catch { ShowHttpError $_ }

  Pause
}

# =========================
# NEW: Feedback Aggregation (/platform/feedback)
# =========================
function FeedbackGetReviews {
  if ($script:CURRENT_ROLE -eq "NONE") { Write-Host "Veuillez d'abord vous connecter."; Pause; return }

  $gameId = Prompt "GameId" "G300"
  $minNote = Prompt "Note minimale (minNote)" "0"
  $sort = Prompt "Tri (asc|desc) (submittedAt)" "desc"
  $page = Prompt "Page" "0"
  $size = Prompt "Taille (size)" "20"

  try {
    $url = "$($env:PLATFORM_URL)/platform/feedback/reviews?gameId=$(UrlEncode $gameId)&minNote=$(UrlEncode $minNote)&sort=$(UrlEncode $sort)&page=$(UrlEncode $page)&size=$(UrlEncode $size)"
    $r = Invoke-RestMethod -Method GET -Uri $url

    # Page<ReviewEntity> => content + metadata
    Write-Host ""
    Write-Host ("TotalElements: {0} | TotalPages: {1} | Page: {2}" -f $r.totalElements, $r.totalPages, $r.number)

    if ($null -eq $r.content -or $r.content.Count -eq 0) {
      Write-Host "Aucun avis."
    } else {
      foreach ($rev in $r.content) {
        Write-Host "----------------------"
        if ($rev.reviewId) { Write-Host ("reviewId: {0}" -f $rev.reviewId) }
        if ($rev.userId) { Write-Host ("userId: {0}" -f $rev.userId) }
        if ($rev.gameId) { Write-Host ("gameId: {0}" -f $rev.gameId) }
        if ($rev.note -ne $null) { Write-Host ("note: {0}" -f $rev.note) }
        if ($rev.description) { Write-Host ("desc: {0}" -f $rev.description) }
        if ($rev.submittedAt) { Write-Host ("submittedAt: {0}" -f $rev.submittedAt) }
      }
    }
  } catch { ShowHttpError $_ }

  Pause
}

function FeedbackGetIncidents {
  if ($script:CURRENT_ROLE -eq "NONE") { Write-Host "Veuillez d'abord vous connecter."; Pause; return }

  $gameId = Prompt "GameId" "G300"
  $severity = (Prompt "Severity (optionnel: HAUTE|MOYENNE|BASSE)" "")
  $page = Prompt "Page" "0"
  $size = Prompt "Taille (size)" "20"

  $qs = @("gameId=$(UrlEncode $gameId)", "page=$(UrlEncode $page)", "size=$(UrlEncode $size)")
  if (-not [string]::IsNullOrWhiteSpace($severity)) {
    $qs += "severity=$(UrlEncode $severity)"
  }
  $query = ($qs -join "&")

  try {
    $url = "$($env:PLATFORM_URL)/platform/feedback/incidents?$query"
    $r = Invoke-RestMethod -Method GET -Uri $url

    Write-Host ""
    Write-Host ("TotalElements: {0} | TotalPages: {1} | Page: {2}" -f $r.totalElements, $r.totalPages, $r.number)

    if ($null -eq $r.content -or $r.content.Count -eq 0) {
      Write-Host "Aucun incident."
    } else {
      foreach ($inc in $r.content) {
        Write-Host "----------------------"
        if ($inc.incidentId) { Write-Host ("incidentId: {0}" -f $inc.incidentId) }
        if ($inc.userId) { Write-Host ("userId: {0}" -f $inc.userId) }
        if ($inc.gameId) { Write-Host ("gameId: {0}" -f $inc.gameId) }
        if ($inc.severity) { Write-Host ("severity: {0}" -f $inc.severity) }
        if ($inc.description) { Write-Host ("desc: {0}" -f $inc.description) }
        if ($inc.environment) { Write-Host ("env: {0}" -f $inc.environment) }
        if ($inc.reportedAt) { Write-Host ("reportedAt: {0}" -f $inc.reportedAt) }
      }
    }
  } catch { ShowHttpError $_ }

  Pause
}

function FeedbackReviewStats {
  if ($script:CURRENT_ROLE -eq "NONE") { Write-Host "Veuillez d'abord vous connecter."; Pause; return }

  $gameId = Prompt "GameId" "G300"

  try {
    $url = "$($env:PLATFORM_URL)/platform/feedback/reviews/$(UrlEncode $gameId)/stats"
    $r = Invoke-RestMethod -Method GET -Uri $url
    $r | ConvertTo-Json -Depth 10
  } catch { ShowHttpError $_ }

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

  # Commun (USER + REDACTOR)
  Write-Host "1) Suivre un utilisateur"
  Write-Host "2) Afficher les abonnements (Users)"
  Write-Host "3) Suivre un éditeur"
  Write-Host "4) Afficher les éditeurs suivis"
  Write-Host "5) Voir les jeux d'un éditeur suivi"

  Write-Host "------ Store / Catalogue ------"
  Write-Host "6) Lister/Rechercher jeux du catalogue"
  Write-Host "7) Détails d'un jeu (catalogue)"

  Write-Host "------ Achats / Bibliothèque ------"
  Write-Host "8) Acheter un jeu"
  Write-Host "9) Voir ma bibliothèque"
  Write-Host "10) Acheter un DLC"
  Write-Host "11) Voir mes DLC"
  Write-Host "12) Vérifier possession d'un jeu"
  Write-Host "13) Voir nb ventes d'un jeu"

  Write-Host "------ Reviews ------"
  Write-Host "14) Déposer un avis"
  Write-Host "15) Voter utile/inutile sur un avis"
  Write-Host "16) Lister avis d'un jeu"
  Write-Host "17) Lister avis d'un utilisateur"

  Write-Host "------ Incidents ------"
  Write-Host "18) Signaler un incident"
  Write-Host "19) Lister incidents d'un jeu"
  Write-Host "20) Compter incidents d'un jeu"

  Write-Host "------ Notifications ------"
  Write-Host "21) Voir mes notifications"

  if ($script:CURRENT_ROLE -eq "REDACTOR") {
    Write-Host "------ Publisher (Éditeur) ------"
    Write-Host "22) Publier un jeu"
    Write-Host "23) Mes jeux"
    Write-Host "24) Publier un patch"
    Write-Host "25) Lister patchs d'un jeu"
    Write-Host "26) Publier un DLC"
    Write-Host "27) Lister DLC d'un jeu"
    Write-Host "28) Déconnexion"
  } else {
    Write-Host "22) Déconnexion"
  }
  Write-Host "------ Gameplay ------"
  Write-Host "30) Démarrer une session de jeu"
  Write-Host "31) Terminer une session de jeu"
  Write-Host "32) Consulter mon temps de jeu"

  Write-Host "------ Feedback (agrégé) ------"
  Write-Host "33) Voir reviews d'un jeu (paginé)"
  Write-Host "34) Voir incidents d'un jeu (paginé)"
  Write-Host "35) Stats reviews d'un jeu"

  Write-Host "0) Quitter"
}

# =========================
# Main loop
# =========================
while ($true) {
  Banner
  Menu
  $c = Read-Host "Choix"

  # NON CONNECTÉ
  if ($script:CURRENT_ROLE -eq "NONE") {
    if ($c -eq "1") { ActionRegisterUser }
    elseif ($c -eq "2") { ActionRegisterRedactor }
    elseif ($c -eq "3") { Connexion }
    elseif ($c -eq "0") { break }
    else { Write-Host "Choix invalide"; Pause }
    continue
  }

  # CONNECTÉ (USER ou REDACTOR)
  switch ($c) {
    "1"  { FollowUser; continue }
    "2"  { ShowFollowing; continue }
    "3"  { FollowRedactor; continue }
    "4"  { ShowFollowedRedactors; continue }
    "5"  { ShowGamesOfFollowedEditor; continue }

    "6"  { CatalogListGames; continue }
    "7"  { CatalogGameDetails; continue }

    "8"  { BuyGame; continue }
    "9"  { MyLibrary; continue }
    "10" { BuyDlc; continue }
    "11" { MyDlcs; continue }
    "12" { CheckOwnership; continue }
    "13" { GameSalesCount; continue }

    "14" { SubmitReview; continue }
    "15" { RateReviewHelpful; continue }
    "16" { ListReviewsByGame; continue }
    "17" { ListReviewsByUser; continue }

    "18" { ReportIncident; continue }
    "19" { ListIncidentsByGame; continue }
    "20" { CountIncidentsByGame; continue }

    "21" { MyNotifications; continue }

    "30" { StartGameSession; continue }
    "31" { EndGameSession; continue }
    "32" { MyPlaytime; continue }

    "33" { FeedbackGetReviews; continue }
    "34" { FeedbackGetIncidents; continue }
    "35" { FeedbackReviewStats; continue }
  }

  # REDACTOR uniquement
  if ($script:CURRENT_ROLE -eq "REDACTOR") {
    switch ($c) {
      "22" { PublishGame; continue }
      "23" { MyGames; continue }
      "24" { PublishPatch; continue }
      "25" { ListPatchesForGame; continue }
      "26" { PublishDlc; continue }
      "27" { ListDlcsForGamePublisher; continue }
      "28" { Déconnexion; continue }
    }
  } else {
    # USER logout
    if ($c -eq "22") { Déconnexion; continue }
  }

  if ($c -eq "0") { break }

  Write-Host "Choix invalide"
  Pause
}