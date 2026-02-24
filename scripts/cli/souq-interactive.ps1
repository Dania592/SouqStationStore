```powershell id="e7pclj"
# souq-interactive.ps1
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
    Write-Host "Connected as: $($script:CURRENT_EMAIL) [$($script:CURRENT_ROLE)]"
  }

  Write-Host "-------------------------------------"
}

function Prompt($label, $default="") {
  if ($default) {
    $v = Read-Host "$label [$default]"
    if ([string]::IsNullOrWhiteSpace($v)) { return $default }
    return $v
  }
  return (Read-Host $label)
}

function HttpPost($url, $body) {
  Invoke-RestMethod -Method POST -Uri $url `
    -Body $body -ContentType "application/x-www-form-urlencoded"
}

function ShowHttpError($err) {
  Write-Host "❌ HTTP Error"
  if ($err.Exception.Response) {
    try {
      $reader = New-Object IO.StreamReader(
      $err.Exception.Response.GetResponseStream()
      )
      Write-Host $reader.ReadToEnd()
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
    HttpPost "$($env:PLATFORM_URL)/platform/register-user" $form |
            ConvertTo-Json -Depth 10
    Write-Host "User created"
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
    HttpPost "$($env:PLATFORM_URL)/platform/register-redactor" $form |
            ConvertTo-Json -Depth 10
    Write-Host "Redactor created"
  } catch {
    ShowHttpError $_
  }

  Pause
}

# =========================
# Login
# =========================
function Login {

  $email = Prompt "email" "redactor@test.com"

  try {
    $r = Invoke-RestMethod `
      "$($env:PLATFORM_URL)/platform/users/check-email?email=$email"

    if (-not $r.exists) {
      Write-Host "User not found"
      Pause
      return
    }

    $script:CURRENT_EMAIL = $email
    $script:CURRENT_USER_ID = $r.userId

    # detect role
    $rr = Invoke-RestMethod `
      "$($env:PLATFORM_URL)/platform/redactors/exists?userId=$($r.userId)"

    if ($rr.exists) {
      $script:CURRENT_ROLE = "REDACTOR"

      # UX
      try {
        $count = Invoke-RestMethod `
          "$($env:PUBLISHER_URL)/publisher/games/count?idEditeur=$($r.userId)"
        Write-Host "Welcome editor"
        Write-Host "You published $count games"
      } catch {}
    }
    else {
      $script:CURRENT_ROLE = "USER"
      Write-Host "Welcome user"
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
  Write-Host "Logged out"
  Pause
}

# =========================
# Publish game
# =========================
function PublishGame {

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
  if ($price) { $form.price = $price }

  try {
    HttpPost "$($env:PUBLISHER_URL)/publisher/publish-game" $form |
            ConvertTo-Json -Depth 10
    Write-Host "Game published"
  } catch {
    ShowHttpError $_
  }

  Pause
}

# =========================
# My games
# =========================
function MyGames {

  try {
    $games = Invoke-RestMethod `
      "$($env:PUBLISHER_URL)/publisher/games/by-publisher?idEditeur=$($script:CURRENT_USER_ID)"

    if ($games.Count -eq 0) {
      Write-Host "No games yet"
    }
    else {
      foreach ($g in $games) {
        Write-Host "----------------------"
        Write-Host "$($g.title) ($($g.gameId))"
        Write-Host "Platform: $($g.platform)"
        Write-Host "Genre: $($g.genre)"
        Write-Host "Version: $($g.version)"
      }
    }

  } catch {
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
  }

  elseif ($script:CURRENT_ROLE -eq "USER") {
    Write-Host "1) Logout"
    Write-Host "0) Exit"
  }

  elseif ($script:CURRENT_ROLE -eq "REDACTOR") {
    Write-Host "1) Publish game"
    Write-Host "2) My games"
    Write-Host "3) Logout"
    Write-Host "0) Exit"
  }
}

# =========================
# Main loop
# =========================
while ($true) {

  Banner
  Menu
  $c = Read-Host "Choice"

  switch ($script:CURRENT_ROLE) {

    "NONE" {
      switch ($c) {
        "1" { ActionRegisterUser }
        "2" { ActionRegisterRedactor }
        "3" { Login }
        "0" { break }
      }
    }

    "USER" {
      switch ($c) {
        "1" { Logout }
        "0" { break }
      }
    }

    "REDACTOR" {
      switch ($c) {
        "1" { PublishGame }
        "2" { MyGames }
        "3" { Logout }
        "0" { break }
      }
    }
  }
}
```
