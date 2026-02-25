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
function Pause { Read-Host "Press Enter..." | Out-Null }

function Banner {
  Clear-Host
  Write-Host "====================================="
  Write-Host "     SouqStation Interactive CLI"
  Write-Host "====================================="
  if ($script:CURRENT_ROLE -eq "NONE") {
    Write-Host "Not connected"
  } else {
    Write-Host ("Connected as: {0} [{1}] (userId={2})" -f $script:CURRENT_EMAIL, $script:CURRENT_ROLE, $script:CURRENT_USER_ID)
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
  Write-Host ("❌ HTTP Error: {0}" -f $err.Exception.Message)
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
    userId      = Prompt "userId" "user-1"
    name        = Prompt "name" "John Doe"
    email       = Prompt "email" "user@test.com"
    displayName = Prompt "displayName" "JohnD"
    birth       = Prompt "birth yyyy-MM-dd" "1990-01-01"
    solde       = Prompt "solde" "0.0"
  }

  try {
    $r = HttpPostForm "$($env:PLATFORM_URL)/platform/register-user" $form
    $r | ConvertTo-Json -Depth 10
    Write-Host "✅ User created"
  } catch {
    ShowHttpError $_
  }

  Pause
}

function ActionRegisterRedactor {
  $form = @{
    userId      = Prompt "userId" "redactor-1"
    name        = Prompt "name" "Jane Doe"
    email       = Prompt "email" "redactor@test.com"
    displayName = Prompt "displayName" "JaneD"
    birth       = Prompt "birth yyyy-MM-dd" "1985-01-01"
    solde       = Prompt "solde" "0.0"
    individual  = Prompt "individual true/false" "true"
  }

  try {
    $r = HttpPostForm "$($env:PLATFORM_URL)/platform/register-redactor" $form
    $r | ConvertTo-Json -Depth 10
    Write-Host "✅ Redactor created"
  } catch {
    ShowHttpError $_
  }

  Pause
}

# =========================
# Login / Logout
# =========================
function Login {
  $email = Prompt "email" "redactor@test.com"

  try {
    $checkUrl = "$($env:PLATFORM_URL)/platform/users/check-email?email=$email"
    $r = Invoke-RestMethod -Method GET -Uri $checkUrl

    if (-not $r.exists) {
      Write-Host "❌ User not found"
      Pause
      return
    }

    $script:CURRENT_EMAIL = $email
    $script:CURRENT_USER_ID = [string]$r.userId

    $redUrl = "$($env:PLATFORM_URL)/platform/redactors/exists?userId=$($script:CURRENT_USER_ID)"
    $rr = Invoke-RestMethod -Method GET -Uri $redUrl

    if ($rr.exists -eq $true) {
      $script:CURRENT_ROLE = "REDACTOR"
      Write-Host "✅ Welcome editor"
      # UX count (optional)
      try {
        $countUrl = "$($env:PUBLISHER_URL)/publisher/games/count?idEditeur=$($script:CURRENT_USER_ID)"
        $count = Invoke-RestMethod -Method GET -Uri $countUrl
        Write-Host ("You published {0} games" -f $count)
      } catch {}
    } else {
      $script:CURRENT_ROLE = "USER"
      Write-Host "✅ Welcome user"
    }
  } catch {
    ShowHttpError $_
  }

  Pause
}

function Logout {
  $script:CURRENT_EMAIL = $null
  $script:CURRENT_USER_ID = $null
  $script:CURRENT_ROLE = "NONE"
  Write-Host "✅ Logged out"
  Pause
}

# =========================
# Social: Follow / Following
# =========================
function FollowUser {
  if ($script:CURRENT_ROLE -eq "NONE") {
    Write-Host "❌ Please login first."
    Pause
    return
  }

  $followedId = Prompt "followedId (user to follow)" "U200"

  if ($followedId -eq $script:CURRENT_USER_ID) {
    Write-Host "❌ You cannot follow yourself."
    Pause
    return
  }

  try {
    $url = "$($env:PLATFORM_URL)/platform/users/follow"
    $r = HttpPostForm $url @{ userId = $script:CURRENT_USER_ID; followedId = $followedId }
    $r | ConvertTo-Json -Depth 10
    Write-Host ("✅ Now following {0}" -f $followedId)
  } catch {
    ShowHttpError $_
  }

  Pause
}

function ShowFollowing {
  if ($script:CURRENT_ROLE -eq "NONE") {
    Write-Host "❌ Please login first."
    Pause
    return
  }

  try {
    $url = "$($env:PLATFORM_URL)/platform/users/following?userId=$($script:CURRENT_USER_ID)"
    $r = Invoke-RestMethod -Method GET -Uri $url

    if ($null -eq $r -or $r.Count -eq 0) {
      Write-Host "No following yet."
    } else {
      Write-Host ""
      Write-Host "Following:"
      foreach ($u in $r) {
        Write-Host "----------------------"
        Write-Host ("userId: {0}" -f $u.userId)
        if ($u.displayName) { Write-Host ("displayName: {0}" -f $u.displayName) }
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
    Write-Host "❌ Publish is only for REDACTOR."
    Pause
    return
  }

  $form = @{
    gameId      = Prompt "gameId" "game-100"
    title       = Prompt "title" "Halo"
    description = Prompt "description" ""
    platform    = (Prompt "platform" "PC").ToUpper()
    genre       = (Prompt "genre" "ACTION").ToUpper()
    idEditeur   = $script:CURRENT_USER_ID
    version     = Prompt "version" "1.0.0"
    releaseDate = Prompt "releaseDate yyyy-MM-dd" "2026-01-01"
  }

  $price = Prompt "price optional" ""
  if ($price -ne "") { $form.price = $price }

  try {
    $url = "$($env:PUBLISHER_URL)/publisher/publish-game"
    $r = HttpPostForm $url $form
    $r | ConvertTo-Json -Depth 10
    Write-Host "✅ Game published"
  } catch {
    ShowHttpError $_
  }

  Pause
}

function MyGames {
  if ($script:CURRENT_ROLE -ne "REDACTOR") {
    Write-Host "❌ My games is only for REDACTOR."
    Pause
    return
  }

  try {
    $url = "$($env:PUBLISHER_URL)/publisher/games/by-publisher?idEditeur=$($script:CURRENT_USER_ID)"
    $games = Invoke-RestMethod -Method GET -Uri $url

    if ($null -eq $games -or $games.Count -eq 0) {
      Write-Host "No games yet"
    } else {
      foreach ($g in $games) {
        Write-Host "----------------------"
        Write-Host ("{0} ({1})" -f $g.title, $g.gameId)
        Write-Host ("Platform: {0}" -f $g.platform)
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
    Write-Host "Login first"
    Pause
    return
  }

  $redactorId = Prompt "Redactor ID to follow" "redactor-1"

  try {
    $url = "$($env:PLATFORM_URL)/platform/users/follow-redactor"
    HttpPostForm $url @{
      userId = $script:CURRENT_USER_ID
      redactorId = $redactorId
    } | ConvertTo-Json -Depth 10

    Write-Host "Followed editor $redactorId"
  }
  catch {
    ShowHttpError $_
  }

  Pause
}
function ShowGamesOfFollowedEditor {

  if ($script:CURRENT_ROLE -eq "NONE") {
    Write-Host "❌ Login first"
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
    Write-Host "You don't follow any editor yet."
    Pause
    return
  }

  Write-Host ""
  Write-Host "Editors you follow:"
  $i = 1
  foreach ($e in $editors) {
    Write-Host ("{0}) {1} ({2})" -f $i, $e.displayName, $e.userId)
    $i++
  }

  # 2) choisir un éditeur (par index ou id)
  $choice = Prompt "Choose editor number OR type editorId" "1"
  $editorId = $null

  if ($choice -match '^\d+$') {
    $idx = [int]$choice
    if ($idx -lt 1 -or $idx -gt $editors.Count) {
      Write-Host "❌ Invalid number"
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
  Write-Host ("Games published by {0}:" -f $editorId)

  if ($null -eq $games -or $games.Count -eq 0) {
    Write-Host "No games found."
    Pause
    return
  }

  foreach ($g in $games) {
    Write-Host "----------------------"
    Write-Host ("{0} ({1})" -f $g.title, $g.gameId)
    Write-Host ("Platform: {0}" -f $g.platform)
    Write-Host ("Genre: {0}" -f $g.genre)
    Write-Host ("Version: {0}" -f $g.version)
    if ($g.price -ne $null) { Write-Host ("Price: {0}" -f $g.price) }
    if ($g.releaseDate -ne $null) { Write-Host ("ReleaseDate: {0}" -f $g.releaseDate) }
  }

  Pause
}
function ShowFollowedRedactors {

  if ($script:CURRENT_ROLE -eq "NONE") {
    Write-Host "Login first"
    Pause
    return
  }

  try {
    $url = "$($env:PLATFORM_URL)/platform/users/following-redactors?userId=$($script:CURRENT_USER_ID)"
    $r = Invoke-RestMethod -Method GET -Uri $url

    if ($r.Count -eq 0) {
      Write-Host "No followed editors"
    }
    else {
      Write-Host "Editors you follow:"
      foreach ($u in $r) {
        Write-Host "----------------"
        Write-Host "Id: $($u.userId)"
        Write-Host "Name: $($u.displayName)"
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
    Write-Host "1) Register user"
    Write-Host "2) Register redactor"
    Write-Host "3) Login"
    Write-Host "0) Exit"
    return
  }

  # USER et REDACTOR → social toujours visible
  Write-Host "1) Follow user"
  Write-Host "2) Show following"
  Write-Host "3) Follow editor"
  Write-Host "4) Show followed editors"
  Write-Host "5) Show games of a followed editor"

  if ($script:CURRENT_ROLE -eq "REDACTOR") {
    Write-Host "6) Publish game"
    Write-Host "7) My games"
    Write-Host "8) Logout"
  } else {
    Write-Host "6) Logout"
  }
  Write-Host "0) Exit"
}

# =========================
# Main loop
# =========================
while ($true) {

  Banner
  Menu
  $c = Read-Host "Choice"

  # =====================
  # NON CONNECTÉ
  # =====================
  if ($script:CURRENT_ROLE -eq "NONE") {

    if ($c -eq "1") { ActionRegisterUser }
    elseif ($c -eq "2") { ActionRegisterRedactor }
    elseif ($c -eq "3") { Login }
    elseif ($c -eq "0") { break }
    else { Write-Host "Invalid choice"; Pause }

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
      Logout
      continue
    }
  }
  else {
    # USER logout
    if ($c -eq "5") {
      Logout
      continue
    }
  }

  if ($c -eq "0") { break }

  Write-Host "Invalid choice"
  Pause
}