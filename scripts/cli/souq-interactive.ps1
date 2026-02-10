# scripts/cli/souq-interactive.ps1
$ErrorActionPreference = "Stop"

# =========================
# Config (override possible)
# =========================
if (-not $env:PUBLISHER_URL)     { $env:PUBLISHER_URL     = "http://localhost:8082" }
if (-not $env:PLATFORM_URL)      { $env:PLATFORM_URL      = "http://localhost:8081" }
if (-not $env:NOTIFICATION_URL)  { $env:NOTIFICATION_URL  = "http://localhost:8083" }

if (-not $env:TOPIC_PUBLISHER)   { $env:TOPIC_PUBLISHER   = "souq.publisher.events" }
if (-not $env:TOPIC_PLATFORM)    { $env:TOPIC_PLATFORM    = "souq.platform.events" }
if (-not $env:TOPIC_NOTIFICATION){ $env:TOPIC_NOTIFICATION= "souq.notification.events" }

if (-not $env:BOOTSTRAP_IN_DOCKER){ $env:BOOTSTRAP_IN_DOCKER = "kafka:9092" }
if (-not $env:KAFKA_CONTAINER_NAME){ $env:KAFKA_CONTAINER_NAME = "kafka" }

function Pause() { Read-Host "Press Enter to continue..." | Out-Null }

function Banner() {
  Clear-Host
  Write-Host "==========================================="
  Write-Host "   SouqStationStore - Interactive CLI"
  Write-Host "==========================================="
  Write-Host ("Publisher URL    : {0}" -f $env:PUBLISHER_URL)
  Write-Host ("Platform URL     : {0}" -f $env:PLATFORM_URL)
  Write-Host ("Notification URL : {0}" -f $env:NOTIFICATION_URL)
  Write-Host ("Kafka container  : {0}" -f $env:KAFKA_CONTAINER_NAME)
  Write-Host "-------------------------------------------"
}

function Menu() {
  Write-Host "Choose an action:"
  Write-Host "  1) Health check (notification-service)"
  Write-Host "  2) Publish game (publisher-service)"
  Write-Host "  3) Register user (platform-service)"
  Write-Host "  4) Emit platform event: GamePurchased (Kafka)"
  Write-Host "  5) Emit platform event: ReviewSubmitted (Kafka)"
  Write-Host "  6) Emit platform event: IncidentReported (Kafka)"
  Write-Host "  7) Read notifications for a user (notification-service)"
  Write-Host "  8) Tail Kafka topic (publisher/platform/notification)"
  Write-Host "  9) Show current config"
  Write-Host "  0) Exit"
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

function UrlEncode([string]$s) {
  return [System.Uri]::EscapeDataString($s)
}

function HttpGet($baseUrl, $queryHashtable) {
  $pairs = @()
  foreach ($k in $queryHashtable.Keys) {
    $pairs += ("{0}={1}" -f (UrlEncode $k), (UrlEncode [string]$queryHashtable[$k]))
  }
  $qs = $pairs -join "&"
  $url = "$baseUrl`?$qs"
  return Invoke-RestMethod -Method GET -Uri $url
}

function KafkaProduce($topic, $key, $json) {
  $container = $env:KAFKA_CONTAINER_NAME
  $bootstrap = $env:BOOTSTRAP_IN_DOCKER

  # Envoie "key:json" sur stdin
  $msg = "$key`:$json"

  $cmd = @(
    "exec", "-i", $container, "bash", "-lc",
    "kafka-console-producer --bootstrap-server $bootstrap --topic $topic --property parse.key=true --property key.separator=:"
  )

  $p = Start-Process -FilePath "docker" -ArgumentList $cmd -NoNewWindow -PassThru -RedirectStandardInput "pipe"
  $p.StandardInput.WriteLine($msg)
  $p.StandardInput.Close()
  $p.WaitForExit()

  if ($p.ExitCode -ne 0) { throw "Kafka produce failed (exit code=$($p.ExitCode))" }
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
  Write-Host "  TOPIC_PLATFORM=$($env:TOPIC_PLATFORM)"
  Write-Host "  TOPIC_NOTIFICATION=$($env:TOPIC_NOTIFICATION)"
  Write-Host "  KAFKA_CONTAINER_NAME=$($env:KAFKA_CONTAINER_NAME)"
  Write-Host "  BOOTSTRAP_IN_DOCKER=$($env:BOOTSTRAP_IN_DOCKER)"
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

function ActionPublishGame() {
  $gameId = Prompt "gameId" "game-1"
  $title  = Prompt "title" "Halo"

  $base = "$($env:PUBLISHER_URL)/publisher/publish-game"
  Write-Host ""
  Write-Host "Calling publisher-service..."
  try {
    $r = HttpGet $base @{ gameId=$gameId; title=$title }
    $r | ConvertTo-Json -Depth 8
    Write-Host "✅ GamePublished sent (key=gameId=$gameId)"
  } catch {
    Write-Host "❌ Request failed => $($_.Exception.Message)"
  }
  Pause
}

function ActionRegisterUser() {
  $userId      = Prompt "userId" "user-1"
  $email       = Prompt "email" "user1@test.com"
  $displayName = Prompt "displayName" "User1"

  $base = "$($env:PLATFORM_URL)/platform/users/register"
  Write-Host ""
  Write-Host "Calling platform-service..."
  try {
    $r = HttpGet $base @{ userId=$userId; email=$email; displayName=$displayName }
    $r | ConvertTo-Json -Depth 8
    Write-Host "✅ UserRegistered triggered (userId=$userId)"
  } catch {
    Write-Host "❌ Request failed => $($_.Exception.Message)"
  }
  Pause
}

function ActionEmitPurchase() {
  $userId = Prompt "userId" "user-1"
  $gameId = Prompt "gameId" "game-1"
  $eventId = Prompt "eventId (blank = auto UUID)" ""
  if ([string]::IsNullOrWhiteSpace($eventId)) { $eventId = [guid]::NewGuid().ToString() }
  $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

  $json = @{
    eventId = $eventId
    eventType = "GamePurchased"
    occurredAt = $ts
    schemaVersion = 1
    payload = @{ userId=$userId; gameId=$gameId }
  } | ConvertTo-Json -Compress -Depth 8

  Write-Host ""
  Write-Host "Producing to Kafka: topic=$($env:TOPIC_PLATFORM) key=$userId"
  try {
    KafkaProduce $env:TOPIC_PLATFORM $userId $json
    Write-Host "✅ Produced GamePurchased (eventId=$eventId)"
  } catch {
    Write-Host "❌ Kafka produce failed => $($_.Exception.Message)"
  }
  Pause
}

function ActionEmitReview() {
  $userId = Prompt "userId" "user-1"
  $gameId = Prompt "gameId" "game-1"
  $rating = Prompt "rating (int)" "5"
  $comment = Prompt "comment" "Great game!"
  $eventId = Prompt "eventId (blank = auto UUID)" ""
  if ([string]::IsNullOrWhiteSpace($eventId)) { $eventId = [guid]::NewGuid().ToString() }
  $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

  $json = @{
    eventId = $eventId
    eventType = "ReviewSubmitted"
    occurredAt = $ts
    schemaVersion = 1
    payload = @{ userId=$userId; gameId=$gameId; rating=[int]$rating; comment=$comment }
  } | ConvertTo-Json -Compress -Depth 8

  Write-Host ""
  Write-Host "Producing to Kafka: topic=$($env:TOPIC_PLATFORM) key=$gameId"
  try {
    KafkaProduce $env:TOPIC_PLATFORM $gameId $json
    Write-Host "✅ Produced ReviewSubmitted (eventId=$eventId)"
  } catch {
    Write-Host "❌ Kafka produce failed => $($_.Exception.Message)"
  }
  Pause
}

function ActionEmitIncident() {
  $userId = Prompt "userId" "user-1"
  $gameId = Prompt "gameId" "game-1"
  $desc = Prompt "description" "Bug on startup"
  $eventId = Prompt "eventId (blank = auto UUID)" ""
  if ([string]::IsNullOrWhiteSpace($eventId)) { $eventId = [guid]::NewGuid().ToString() }
  $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

  $json = @{
    eventId = $eventId
    eventType = "IncidentReported"
    occurredAt = $ts
    schemaVersion = 1
    payload = @{ userId=$userId; gameId=$gameId; description=$desc }
  } | ConvertTo-Json -Compress -Depth 8

  Write-Host ""
  Write-Host "Producing to Kafka: topic=$($env:TOPIC_PLATFORM) key=$gameId"
  try {
    KafkaProduce $env:TOPIC_PLATFORM $gameId $json
    Write-Host "✅ Produced IncidentReported (eventId=$eventId)"
  } catch {
    Write-Host "❌ Kafka produce failed => $($_.Exception.Message)"
  }
  Pause
}

function ActionReadNotifications() {
  $userId = Prompt "userId" "user-1"
  $url = "$($env:NOTIFICATION_URL)/notifications/$userId"
  Write-Host ""
  Write-Host "GET $url"
  try {
    $r = Invoke-RestMethod -Method GET -Uri $url
    $r | ConvertTo-Json -Depth 10
  } catch {
    Write-Host "❌ Request failed => $($_.Exception.Message)"
  }
  Pause
}

function ActionTailTopic() {
  Write-Host ""
  Write-Host "Which topic?"
  Write-Host "  1) publisher    ($($env:TOPIC_PUBLISHER))"
  Write-Host "  2) platform     ($($env:TOPIC_PLATFORM))"
  Write-Host "  3) notification ($($env:TOPIC_NOTIFICATION))"
  $c = Read-Host "Choice [1-3]"
  switch ($c) {
    "1" { KafkaTail $env:TOPIC_PUBLISHER }
    "2" { KafkaTail $env:TOPIC_PLATFORM }
    "3" { KafkaTail $env:TOPIC_NOTIFICATION }
    default { Write-Host "Invalid choice"; Pause }
  }
}

# =========================
# Main loop
# =========================
while ($true) {
  Banner
  Menu
  $choice = Read-Host "Enter choice"
  switch ($choice) {
    "1" { ActionHealth }
    "2" { ActionPublishGame }
    "3" { ActionRegisterUser }
    "4" { ActionEmitPurchase }
    "5" { ActionEmitReview }
    "6" { ActionEmitIncident }
    "7" { ActionReadNotifications }
    "8" { ActionTailTopic }
    "9" { ShowConfig }
    "0" { Write-Host "Bye 👋"; break }
    default { Write-Host "Invalid choice"; Pause }
  }
}