# test-endpoints-full.ps1
$ErrorActionPreference = "Stop"

# =========================
# Config
# =========================
if (-not $env:PLATFORM_URL)  { $env:PLATFORM_URL  = "http://localhost:8081" }
if (-not $env:PUBLISHER_URL) { $env:PUBLISHER_URL = "http://localhost:8082" }
if (-not $env:NOTIF_URL)     { $env:NOTIF_URL     = "http://localhost:8083" } # optionnel

try { Add-Type -AssemblyName System.Web | Out-Null } catch {}

function UrlEncode([string]$s) {
    if ($null -eq $s) { return "" }
    try { return [System.Web.HttpUtility]::UrlEncode($s) } catch { return $s }
}

function PostForm([string]$url, [hashtable]$body) {
    Invoke-RestMethod -Method POST -Uri $url -Body $body -ContentType "application/x-www-form-urlencoded"
}

function PostFormMulti([string]$url, [hashtable]$body, [hashtable]$multi) {
    $pairs = New-Object System.Collections.Generic.List[string]
    foreach ($k in $body.Keys) { $pairs.Add(("{0}={1}" -f (UrlEncode $k), (UrlEncode ([string]$body[$k])))) }
    foreach ($k in $multi.Keys) {
        $arr = $multi[$k]
        if ($arr -is [System.Array]) {
            foreach ($v in $arr) { $pairs.Add(("{0}={1}" -f (UrlEncode $k), (UrlEncode ([string]$v)))) }
        } else {
            $pairs.Add(("{0}={1}" -f (UrlEncode $k), (UrlEncode ([string]$arr))))
        }
    }
    $encoded = $pairs -join "&"
    Invoke-RestMethod -Method POST -Uri $url -Body $encoded -ContentType "application/x-www-form-urlencoded"
}

function TryGet([string]$url) {
    try { return Invoke-RestMethod -Method GET -Uri $url } catch { Write-Host "GET failed: $url"; return $null }
}

Write-Host "========================================="
Write-Host "   SouqStationStore - Full Integration   "
Write-Host "========================================="
Write-Host "PLATFORM_URL=$($env:PLATFORM_URL)"
Write-Host "PUBLISHER_URL=$($env:PUBLISHER_URL)"
Write-Host "NOTIF_URL=$($env:NOTIF_URL) (optional)"
Write-Host "-----------------------------------------"

# =========================
# 1) Create users & redactor
# =========================
Write-Host "`n[1] Création de l'utilisateur U100..."
(PostForm "$($env:PLATFORM_URL)/platform/register-user" @{
    userId="U100"; name="Dupont"; email="dupont@test.com"; displayName="JeanD"; birth="1990-05-12"; solde="100.5"
}) | ConvertTo-Json -Depth 10

Write-Host "`n[2] Création de l'utilisateur U200..."
(PostForm "$($env:PLATFORM_URL)/platform/register-user" @{
    userId="U200"; name="Martin"; email="martin.acheteur@test.com"; displayName="MartinA"; birth="1992-06-15"; solde="0.0"
}) | ConvertTo-Json -Depth 10

Write-Host "`n[3] Création de l'éditeur R200..."
(PostForm "$($env:PLATFORM_URL)/platform/register-redactor" @{
    userId="R200"; name="Martin"; email="martin@test.com"; displayName="MarcM"; birth="1985-08-20"; solde="250.75"; individual="true"
}) | ConvertTo-Json -Depth 10

# =========================
# 2) Publish game
# =========================
Write-Host "`n[4] Publication du jeu G300 par R200..."
(PostForm "$($env:PUBLISHER_URL)/publisher/publish-game" @{
    gameId="G300"; title="The Witcher 3"; description="Open world RPG"; platform="PC"; genre="RPG";
    idEditeur="R200"; version="1.0"; prixInit="39.99"; releaseDate="2025-10-10"
}) | ConvertTo-Json -Depth 10

Write-Host "`n[4b] (OPTIONNEL) Count games by publisher..."
(TryGet "$($env:PUBLISHER_URL)/publisher/games/count?idEditeur=R200") | ConvertTo-Json -Depth 10

Start-Sleep -Seconds 2

# =========================
# 3) Social
# =========================
Write-Host "`n[5] U100 suit U200..."
(PostForm "$($env:PLATFORM_URL)/platform/users/follow" @{ userId="U100"; followedId="U200" }) | ConvertTo-Json -Depth 10

Write-Host "`n[5b] (OPTIONNEL) U100 suit l'éditeur R200..."
try {
    (PostForm "$($env:PLATFORM_URL)/platform/users/follow-redactor" @{ userId="U100"; redactorId="R200" }) | ConvertTo-Json -Depth 10
} catch { Write-Host "skip follow-redactor (endpoint peut ne pas exister)"; }

Write-Host "`n[5c] (OPTIONNEL) Liste éditeurs suivis par U100..."
(TryGet "$($env:PLATFORM_URL)/platform/users/following-redactors?userId=U100") | ConvertTo-Json -Depth 10

Write-Host "`n[5d] (OPTIONNEL) Jeux par éditeur R200 (publisher-service)..."
(TryGet "$($env:PUBLISHER_URL)/publisher/games/by-publisher?idEditeur=R200") | ConvertTo-Json -Depth 10

# =========================
# 4) Purchases / Library
# =========================
Write-Host "`n[6] U100 achète le jeu G300..."
(PostForm "$($env:PLATFORM_URL)/platform/purchases/game" @{ userId="U100"; gameId="G300" }) | ConvertTo-Json -Depth 10

Write-Host "`n[7] Bibliothèque de U100..."
(TryGet "$($env:PLATFORM_URL)/platform/purchases/library?userId=U100") | ConvertTo-Json -Depth 10

Write-Host "`n[7b] (OPTIONNEL) Ownership U100->G300..."
(TryGet "$($env:PLATFORM_URL)/platform/purchases/owns?userId=U100&gameId=G300") | ConvertTo-Json -Depth 10

Write-Host "`n[7c] (OPTIONNEL) Sales count G300..."
(TryGet "$($env:PLATFORM_URL)/platform/purchases/sales-count?gameId=G300") | ConvertTo-Json -Depth 10

# =========================
# 5) Gameplay sessions (NEW)
# =========================
Write-Host "`n[8] U100 démarre une session G300..."
(PostForm "$($env:PLATFORM_URL)/platform/sessions/start" @{ userId="U100"; gameId="G300" }) | ConvertTo-Json -Depth 10

Write-Host "Attente 180s (3 minutes) pour respecter la règle..."
Start-Sleep -Seconds 180

Write-Host "`n[9] U100 termine la session G300..."
(PostForm "$($env:PLATFORM_URL)/platform/sessions/end" @{ userId="U100"; gameId="G300" }) | ConvertTo-Json -Depth 10

Write-Host "`n[10] Temps de jeu U100 (tous jeux)..."
(TryGet "$($env:PLATFORM_URL)/platform/sessions/users/U100/playtime") | ConvertTo-Json -Depth 10

Write-Host "`n[11] Temps de jeu U100 sur G300..."
(TryGet "$($env:PLATFORM_URL)/platform/sessions/users/U100/playtime?gameId=G300") | ConvertTo-Json -Depth 10

# =========================
# 6) Reviews
# =========================
Write-Host "`n[12] U100 soumet un avis sur G300..."
$reviewResp = PostForm "$($env:PLATFORM_URL)/platform/reviews/submit" @{
    userId="U100"; gameId="G300"; note="9"; description="Incroyable !"
}
$reviewResp | ConvertTo-Json -Depth 10

$reviewId = $null
try { $reviewId = [string]$reviewResp.reviewId } catch {}

Write-Host "`n[13] (OPTIONNEL) U200 vote utile sur l'avis..."
if (-not [string]::IsNullOrWhiteSpace($reviewId)) {
    (PostForm "$($env:PLATFORM_URL)/platform/reviews/$reviewId/rate" @{ userId="U200"; isHelpful="true" }) | ConvertTo-Json -Depth 10
} else {
    Write-Host "ReviewId introuvable, skip."
}

# =========================
# 7) Incidents
# =========================
Write-Host "`n[14] U100 signale un incident sur G300..."
(PostForm "$($env:PLATFORM_URL)/platform/incidents/report" @{
    userId="U100"; gameId="G300"; severity="HAUTE"; description="Crashs intempestifs"; environment="Windows 11"
}) | ConvertTo-Json -Depth 10

# =========================
# 8) Feedback aggregation (NEW)
# =========================
Write-Host "`n[15] Feedback reviews (paginé) G300..."
(TryGet "$($env:PLATFORM_URL)/platform/feedback/reviews?gameId=G300&minNote=0&sort=desc&page=0&size=20") | ConvertTo-Json -Depth 10

Write-Host "`n[16] Feedback incidents (paginé) G300 (severity=HAUTE)..."
(TryGet "$($env:PLATFORM_URL)/platform/feedback/incidents?gameId=G300&severity=HAUTE&page=0&size=20") | ConvertTo-Json -Depth 10

Write-Host "`n[17] Stats reviews G300..."
(TryGet "$($env:PLATFORM_URL)/platform/feedback/reviews/G300/stats") | ConvertTo-Json -Depth 10

# =========================
# 9) Publish patch
# =========================
Write-Host "`n[18] R200 publie un patch pour G300..."
(PostFormMulti "$($env:PUBLISHER_URL)/publisher/publish-patch" `
  @{ gameId="G300"; targetVersion="1.0.1"; patchNotes="Correction du crash sous Windows 11"; releasedAt="2025-11-20" } `
  @{ modifications=@("CORRECTION","OPTIMISATION") }
) | ConvertTo-Json -Depth 10

Start-Sleep -Seconds 2

# =========================
# 10) Final catalog check
# =========================
Write-Host "`n[19] Vérification finale du catalogue G300..."
(TryGet "$($env:PLATFORM_URL)/platform/catalog/games/G300") | ConvertTo-Json -Depth 10

# =========================
# OPTIONAL: Notifications / DLC
# =========================
Write-Host "`n[20] Envoi manuel d'une notification à U100..."
(PostForm "$($env:NOTIF_URL)/notifications/send" @{
    userId="U100"; type="TEST_NOTIF"; message="Ceci est un test direct via le script PS1"
}) | ConvertTo-Json -Depth 10

Write-Host "`n[21] (OPTIONNEL) Lecture des notifications de U100..."
(TryGet "$($env:NOTIF_URL)/notifications/U100") | ConvertTo-Json -Depth 10

Write-Host "========================================="
Write-Host "        Fin des tests d'intégration      "
Write-Host "========================================="