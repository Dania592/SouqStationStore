# scripts/cli/souq-interactive.ps1
$ErrorActionPreference = "Stop"

# =========================
# Config (override possible)
# =========================
if (-not $env:PUBLISHER_URL)      { $env:PUBLISHER_URL      = "http://localhost:8082" }
if (-not $env:PLATFORM_URL)       { $env:PLATFORM_URL       = "http://localhost:8081" }
if (-not $env:NOTIFICATION_URL)   { $env:NOTIFICATION_URL   = "http://localhost:8083" }

if (-not $env:TOPIC_PUBLISHER)    { $env:TOPIC_PUBLISHER    = "souq.publisher.events" }
if (-not $env:TOPIC_PLATFORM_USER)     { $env:TOPIC_PLATFORM_USER     = "souq.platform.user.events" }
if (-not $env:TOPIC_PLATFORM_REDACTOR) { $env:TOPIC_PLATFORM_REDACTOR = "souq.platform.redactor.events" }
if (-not $env:TOPIC_NOTIFICATION) { $env:TOPIC_NOTIFICATION = "souq.notification.events" }

if (-not $env:BOOTSTRAP_IN_DOCKER)      { $env:BOOTSTRAP_IN_DOCKER = "kafka:9092" }
if (-not $env:KAFKA_CONTAINER_NAME)     { $env:KAFKA_CONTAINER_NAME = "kafka" }

# Platform lookup endpoints (override if different)
if (-not $env:PLATFORM_CHECK_EMAIL_PATH)   { $env:PLATFORM_CHECK_EMAIL_PATH   = "/platform/users/check-email" }
if (-not $env:PLATFORM_REDACTOR_EXISTS_PATH){ $env:PLATFORM_REDACTOR_EXISTS_PATH = "/platform/redactors/exists" }

# =========================
# Session state
# =========================
$script:CURRENT_EMAIL = $null
$script:CURRENT_USER_ID = $null
$script:CURRENT_IS_REDACTOR = $false

function Pause() { Read-Host "Press Enter to continue..." | Out-Null }

function Banner() {
  Clear-Host
  Write-Host "==========================================="
  Write-Host "   SouqStationStore - Interactive CLI"
  Write-Host "==========================================="
  Write-Host ("Publisher URL        : {0}" -f $env:PUBLISHER_URL)
  Write-Host ("Platform URL         : {0}" -f $env:PLATFORM_URL)
  Write-Host ("Notification URL     : {0}" -f $env:NOTIFICATION_URL)
  Write-Host ("Kafka container      : {0}" -f $env:KAFKA_CONTAINER_NAME)
  Write-Host "-------------------------------------------"

  if ($script:CURRENT_USER_ID) {
    $role = if ($script:CURRENT_IS_REDACTOR) { "REDACTOR/EDITEUR" } else { "USER" }
    Write-Host ("Connected            : {0} (userId={1}, role={2})" -f $script:CURRENT_EMAIL, $script:CURRENT_USER_ID, $role)
  } else {
    Write-Host "Connected            : (none)"
  }
  Write-Host "-------------------------------------------"
}

function Menu() {
  Write-Host "Choose an action:"
  Write-Host "  1)  Register user (platform-service)"
  Write-Host "  2)  Register redactor (platform-service)"
  Write-Host "  3)  Connexion existing account (by email)"
  Write-Host "  4)  Health check (notification-service)"
  Write-Host "  5)  Tail Kafka topic"
  Write-Host "  6)  Show current config"

  # ✅ Option visible uniquement si connecté ET editeur
  if ($script:CURRENT_USER_ID -and $script:CURRENT_IS_REDACTOR) {
    Write-Host "  7)  Publish game (publisher-service) [as current editor]"
  }

  Write-Host "  0)  Exit"
}

function Prompt($label, $default="") {
  if ($default -ne "") {
    $v = Read-Host "$label [$default]"
    if ([string]::IsNullOrWhiteSpace($v)) { return $default }
    return $v
  } else {
    return (Read-Host "$label")
  }
}

function UrlEncode([string]$s) { return [System.Uri]::EscapeDataString($s) }

function HttpPost($url, $queryHashtable) {
  $pairs = @()
  foreach ($k in $queryHashtable.Keys) {
    $v = $queryHashtable[$k]
    if ($v -is [hashtable] -or $v -is [System.Collections.IDictionary]) {
      throw "HttpPost: value for '$k' is a hashtable/object. Expected string/number. Actual=$($v.GetType().FullName)"
    }
    $pairs += ("{0}={1}" -f (UrlEncode $k), (UrlEncode ([string]$v)))
  }
  $qs = $pairs -join "&"
  $fullUrl = "$url`?$qs"
  return Invoke-RestMethod -Method POST -Uri $fullUrl
}

function HttpGet($baseUrl, $queryHashtable) {
  $pairs = @()
  foreach ($k in $queryHashtable.Keys) {
    $v = $queryHashtable[$k]
    if ($v -is [hashtable] -or $v -is [System.Collections.IDictionary]) {
      throw "HttpGet: value for '$k' is a hashtable/object. Expected string/number. Actual=$($v.GetType().FullName)"
    }
    $pairs += ("{0}={1}" -f (UrlEncode $k), (UrlEncode ([string]$v)))
  }
  $qs = $pairs -join "&"
  $url = "$baseUrl`?$qs"
  return Invoke-RestMethod -Method GET -Uri $url
}

function KafkaTail($topic) {
  $container = $env:KAFKA_CONTAINER_NAME
  $bootstrap = $env:BOOTSTRAP_IN_DOCKER
  docker exec -it $container bash -lc "kafka-console-consumer --bootstrap-server $bootstrap --topic $topic --from-beginning --timeout-ms 10000"
}

function ShowConfig() {
  Write-Host ""
  Write-Host "CONFIG:"
  Write-Host "  PUBLISHER_URL=$($env:PUBLISHER_URL)"
  Write-Host "  PLATFORM_URL=$($env:PLATFORM_URL)"
  Write-Host "  NOTIFICATION_URL=$($env:NOTIFICATION_URL)"
  Write-Host "  TOPIC_PUBLISHER=$($env:TOPIC_PUBLISHER)"
  Write-Host "  TOPIC_PLATFORM_USER=$($env:TOPIC_PLATFORM_USER)"
  Write-Host "  TOPIC_PLATFORM_REDACTOR=$($env:TOPIC_PLATFORM_REDACTOR)"
  Write-Host "  TOPIC_NOTIFICATION=$($env:TOPIC_NOTIFICATION)"
  Write-Host "  KAFKA_CONTAINER_NAME=$($env:KAFKA_CONTAINER_NAME)"
  Write-Host "  BOOTSTRAP_IN_DOCKER=$($env:BOOTSTRAP_IN_DOCKER)"
  Write-Host "  PLATFORM_CHECK_EMAIL_PATH=$($env:PLATFORM_CHECK_EMAIL_PATH)"
  Write-Host "  PLATFORM_REDACTOR_EXISTS_PATH=$($env:PLATFORM_REDACTOR_EXISTS_PATH)"
  Write-Host ""
  Write-Host "SESSION:"
  Write-Host "  CURRENT_EMAIL=$($script:CURRENT_EMAIL)"
  Write-Host "  CURRENT_USER_ID=$($script:CURRENT_USER_ID)"
  Write-Host "  CURRENT_IS_REDACTOR=$($script:CURRENT_IS_REDACTOR)"
  Write-Host ""
  Pause
}

function ActionHealth() {
  try {
    $url = "$($env:NOTIFICATION_URL)/notifications/health"
    Write-Host ""
    Write-Host "GET $url"
    $r = Invoke-RestMethod -Method GET -Uri $url
    Write-Host "✅ OK => $r"
  } catch {
    Write-Host "❌ FAIL => $($_.Exception.Message)"
  }
  Pause
}

function ActionRegisterUser() {
  $userId      = Prompt "userId"      "user-1"
  $name        = Prompt "name"        "John Doe"
  $email       = Prompt "email"       "user1@test.com"
  $displayName = Prompt "displayName" "JohnD"
  $birth       = [string](Prompt "birth (yyyy-MM-dd)" "1990-01-01")
  $solde       = Prompt "solde (float)" "0.0"

  $url = "$($env:PLATFORM_URL)/platform/register-user"
  Write-Host ""
  Write-Host "POST $url"
  try {
    $r = HttpPost $url @{
      userId      = $userId
      name        = $name
      email       = $email
      displayName = $displayName
      birth       = $birth
      solde       = $solde
    }
    $r | ConvertTo-Json -Depth 8
    Write-Host "✅ UserRegistered triggered (userId=$userId)"
    Write-Host ("   Expected Kafka topic: {0}" -f $env:TOPIC_PLATFORM_USER)
  } catch {
    Write-Host "❌ Request failed => $($_.Exception.Message)"
  }
  Pause
}

function ActionRegisterRedactor() {
  $userId      = Prompt "userId"      "redactor-1"
  $name        = Prompt "name"        "Jane Doe"
  $email       = Prompt "email"       "redactor1@test.com"
  $displayName = Prompt "displayName" "JaneD"
  $birth       = [string](Prompt "birth (yyyy-MM-dd)" "1985-06-15")
  $solde       = Prompt "solde (float)" "0.0"
  $individual  = Prompt "individual (true/false)" "true"

  $url = "$($env:PLATFORM_URL)/platform/register-redactor"
  Write-Host ""
  Write-Host "POST $url"
  try {
    $r = HttpPost $url @{
      userId      = $userId
      name        = $name
      email       = $email
      displayName = $displayName
      birth       = $birth
      solde       = $solde
      individual  = $individual
    }
    $r | ConvertTo-Json -Depth 8
    Write-Host "✅ RedactorRegistered triggered (userId=$userId)"
    Write-Host ("   Expected Kafka topic: {0}" -f $env:TOPIC_PLATFORM_REDACTOR)
  } catch {
    Write-Host "❌ Request failed => $($_.Exception.Message)"
  }
  Pause
}

function ActionLoginExisting() {
  $email = Prompt "email" "redactor1@test.com"

  # 1) lookup userId by email
  $checkUrl = "$($env:PLATFORM_URL)$($env:PLATFORM_CHECK_EMAIL_PATH)"
  Write-Host ""
  Write-Host "GET $checkUrl?email=$email"
  try {
    $r = HttpGet $checkUrl @{ email = $email }

    if ($null -eq $r.exists -or $r.exists -ne $true) {
      Write-Host "❌ Email not found: $email"
      $r | ConvertTo-Json -Depth 10
      Pause
      return
    }
    if ([string]::IsNullOrWhiteSpace([string]$r.userId)) {
      Write-Host "❌ Response does not contain userId. Response:"
      $r | ConvertTo-Json -Depth 10
      Pause
      return
    }

    $script:CURRENT_EMAIL = $email
    $script:CURRENT_USER_ID = [string]$r.userId

    # 2) check if redactor/editor
    $redUrl = "$($env:PLATFORM_URL)$($env:PLATFORM_REDACTOR_EXISTS_PATH)"
    Write-Host ""
    Write-Host "GET $redUrl?userId=$($script:CURRENT_USER_ID)"
    $rr = HttpGet $redUrl @{ userId = $script:CURRENT_USER_ID }
    $script:CURRENT_IS_REDACTOR = ($rr.exists -eq $true)

    $role = if ($script:CURRENT_IS_REDACTOR) { "REDACTOR/EDITEUR" } else { "USER" }
    Write-Host "✅ Connected as $role (userId=$($script:CURRENT_USER_ID))"

  } catch {
    Write-Host "❌ Login failed => $($_.Exception.Message)"
    Write-Host "➡️ Vérifie les routes platform:"
    Write-Host "   - $($env:PLATFORM_CHECK_EMAIL_PATH)"
    Write-Host "   - $($env:PLATFORM_REDACTOR_EXISTS_PATH)"
  }

  Pause
}

function ActionPublishGame() {
  if (-not $script:CURRENT_USER_ID) {
    Write-Host "❌ You must login first."
    Pause
    return
  }
  if (-not $script:CURRENT_IS_REDACTOR) {
    Write-Host "❌ Current account is not a redactor/editor. Publication not allowed."
    Pause
    return
  }

  # Publisher Controller params (new schema)
  $gameId      = Prompt "gameId" "game-200"
  $title       = Prompt "title"  "Halo"
  $description = Prompt "description (optional)" "Best FPS"
  if ([string]::IsNullOrWhiteSpace($description)) { $description = $null }

  $platform    = Prompt "platform (ExecPlatform enum)" "PC"
  $genre       = Prompt "genre (GameGenre enum)" "ACTION"
  $version     = Prompt "version" "1.0.0"
  $priceStr    = Prompt "price (optional, double)" ""
  $releaseDate = Prompt "releaseDate (yyyy-MM-dd)" "2026-03-01"

  $qs = @{
    gameId      = $gameId
    title       = $title
    platform    = $platform
    genre       = $genre
    idEditeur   = $script:CURRENT_USER_ID
    version     = $version
    releaseDate = $releaseDate
  }
  if ($null -ne $description) { $qs.description = $description }
  if (-not [string]::IsNullOrWhiteSpace($priceStr)) { $qs.price = $priceStr }

  $url = "$($env:PUBLISHER_URL)/publisher/publish-game"
  Write-Host ""
  Write-Host "GET $url (as idEditeur=$($script:CURRENT_USER_ID))"
  try {
    $r = HttpGet $url $qs
    $r | ConvertTo-Json -Depth 10
    Write-Host "✅ GamePublished sent & saved (gameId=$gameId)"
  } catch {
    Write-Host "❌ Request failed => $($_.Exception.Message)"
    Write-Host "➡️ Astuce: platform/genre doivent matcher EXACTEMENT les enums (casse incluse)."
  }

  Pause
}

function ActionTailTopic() {
  Write-Host ""
  Write-Host "Which topic?"
  Write-Host "  1) publisher         ($($env:TOPIC_PUBLISHER))"
  Write-Host "  2) platform-user     ($($env:TOPIC_PLATFORM_USER))"
  Write-Host "  3) platform-redactor ($($env:TOPIC_PLATFORM_REDACTOR))"
  Write-Host "  4) notification      ($($env:TOPIC_NOTIFICATION))"
  $c = Read-Host "Choice [1-4]"
  switch ($c) {
    "1" { KafkaTail $env:TOPIC_PUBLISHER }
    "2" { KafkaTail $env:TOPIC_PLATFORM_USER }
    "3" { KafkaTail $env:TOPIC_PLATFORM_REDACTOR }
    "4" { KafkaTail $env:TOPIC_NOTIFICATION }
    default { Write-Host "Invalid choice"; Pause }
  }
}

# ==========================================================
# COMMENTED OUT FOR LATER (keep in file, hidden in menu)
# ==========================================================
<#
function KafkaProduce($topic, $key, $json) { ... }
function ActionEmitPurchase() { ... }
function ActionEmitReview() { ... }
function ActionEmitIncident() { ... }
function ActionReadNotifications() { ... }
#>

# =========================
# Main loop
# =========================
while ($true) {
  Banner
  Menu
  $choice = Read-Host "Enter choice"
  switch ($choice) {
    "1"  { ActionRegisterUser }
    "2"  { ActionRegisterRedactor }
    "3"  { ActionLoginExisting }
    "4"  { ActionHealth }
    "5"  { ActionTailTopic }
    "6"  { ShowConfig }
    "7"  {
      if ($script:CURRENT_USER_ID -and $script:CURRENT_IS_REDACTOR) {
        ActionPublishGame
      } else {
        Write-Host "Invalid choice"; Pause
      }
    }
    "0"  { Write-Host "Bye 👋"; break }
    default { Write-Host "Invalid choice"; Pause }
  }
}