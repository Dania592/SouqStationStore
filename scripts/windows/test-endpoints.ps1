# test-endpoints-full.ps1 (ENRICHED / DATA SEEDER)
# Ajoute plein de données : + users, + redactors, + jeux, achats, reviews, incidents, sessions, follows, patches, notifications.
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

function SafePost([string]$label, [string]$url, [hashtable]$body) {
    Write-Host "`n$label"
    try { (PostForm $url $body) | ConvertTo-Json -Depth 10 } catch { Write-Host "POST failed: $url"; $_.Exception.Message }
}

function SafePostMulti([string]$label, [string]$url, [hashtable]$body, [hashtable]$multi) {
    Write-Host "`n$label"
    try { (PostFormMulti $url $body $multi) | ConvertTo-Json -Depth 10 } catch { Write-Host "POST failed: $url"; $_.Exception.Message }
}

function SleepMs([int]$ms) { Start-Sleep -Milliseconds $ms }

Write-Host "========================================="
Write-Host "   SouqStationStore - Full Integration   "
Write-Host "         ENRICHED DATA SEEDER           "
Write-Host "========================================="
Write-Host "PLATFORM_URL=$($env:PLATFORM_URL)"
Write-Host "PUBLISHER_URL=$($env:PUBLISHER_URL)"
Write-Host "NOTIF_URL=$($env:NOTIF_URL) (optional)"
Write-Host "-----------------------------------------"

# =========================
# 0) Seed configuration
# =========================
# Ajuste ici si tu veux plus/moins de données
$NB_USERS     = 12
$NB_REDACTORS = 3
$NB_GAMES     = 10
$NB_REVIEWS   = 25
$NB_INCIDENTS = 12
$NB_SESSIONS  = 20
$NB_PURCHASES = 20
$NB_FOLLOWS   = 18
$NB_PATCHES   = 12
$SEND_NOTIFS  = $true

# Jeux existants de ton script (on garde G300)
$BASE_GAME_ID = 300

# Génère des genres / platforms variés
$Genres    = @("RPG","ACTION","STRATEGY")
$Platforms = @("PC","SWITCH","WEB")
$Severities= @("BASSE","NORMALE","HAUTE","CRITIQUE")

# =========================
# 1) Create baseline users/redactor (ton script original)
# =========================
Write-Host "`n[1] Création de l'utilisateur U100..."
(PostForm "$($env:PLATFORM_URL)/platform/register-user" @{
    userId="U100"; name="Dupont"; email="dupont@test.com"; displayName="JeanD"; birth="1990-05-12"; solde="100.5"
}) | ConvertTo-Json -Depth 10

Write-Host "`n[2] Création de l'utilisateur U200..."
(PostForm "$($env:PLATFORM_URL)/platform/register-user" @{
    userId="U200"; name="Martin"; email="martin.acheteur@test.com"; displayName="MartinA"; birth="1992-06-15"; solde="50.0"
}) | ConvertTo-Json -Depth 10

Write-Host "`n[3] Création de l'éditeur R200..."
(PostForm "$($env:PLATFORM_URL)/platform/register-redactor" @{
    userId="R200"; name="Martin"; email="martin@test.com"; displayName="MarcM"; birth="1985-08-20"; solde="250.75"; individual="true"
}) | ConvertTo-Json -Depth 10

# =========================
# 2) Create MORE users & redactors
# =========================
Write-Host "`n[1b] Création de $NB_USERS utilisateurs supplémentaires..."
$UserIds = New-Object System.Collections.Generic.List[string]
$UserIds.Add("U100")
$UserIds.Add("U200")

for ($i=1; $i -le $NB_USERS; $i++) {
    $id = "U{0}" -f (300 + $i)  # U301..U312
    $UserIds.Add($id) | Out-Null

    $solde = if ($i % 3 -eq 0) { "0.0" } elseif ($i % 3 -eq 1) { "25.0" } else { "120.0" }
    SafePost ("[U] register $id") "$($env:PLATFORM_URL)/platform/register-user" @{
        userId=$id
        name="User$i"
        email=("user{0}@test.com" -f $i)
        displayName=("Player{0}" -f $i)
        birth=("199{0}-0{1}-1{2}" -f ($i % 10), (($i % 9)+1), ($i % 9))
        solde=$solde
    } | Out-Null
}

Write-Host "`n[1c] Création de $NB_REDACTORS éditeurs supplémentaires..."
$RedactorIds = New-Object System.Collections.Generic.List[string]
$RedactorIds.Add("R200") | Out-Null

for ($i=1; $i -le $NB_REDACTORS; $i++) {
    $rid = "R{0}" -f (300 + $i) # R301..R303
    $RedactorIds.Add($rid) | Out-Null
    SafePost ("[R] register $rid") "$($env:PLATFORM_URL)/platform/register-redactor" @{
        userId=$rid
        name="Redactor$i"
        email=("redactor{0}@test.com" -f $i)
        displayName=("Studio{0}" -f $i)
        birth=("198{0}-0{1}-2{2}" -f ($i % 10), (($i % 9)+1), ($i % 9))
        solde="500.0"
        individual="true"
    } | Out-Null
}

# =========================
# 3) Publish MANY games
# =========================
Write-Host "`n[4] Publication du jeu G300 par R200 (ton jeu original)..."
(PostForm "$($env:PUBLISHER_URL)/publisher/publish-game" @{
    gameId="G300"; title="The Witcher 3"; description="Open world RPG"; platform="PC"; genre="RPG";
    idEditeur="R200"; version="1.0"; prixInit="39.99"; releaseDate="2025-10-10"
}) | ConvertTo-Json -Depth 10

Write-Host "`n[4b] Publication de $NB_GAMES jeux supplémentaires..."
$GameIds = New-Object System.Collections.Generic.List[string]
$GameIds.Add("G300") | Out-Null

for ($i=1; $i -le $NB_GAMES; $i++) {
    $gid = "G{0}" -f ($BASE_GAME_ID + $i)   # G301..G310
    $GameIds.Add($gid) | Out-Null
    $pub = $RedactorIds[ ($i-1) % $RedactorIds.Count ]
    $genre = $Genres[ ($i-1) % $Genres.Count ]
    $plat  = $Platforms[ ($i-1) % $Platforms.Count ]
    $price = "{0}.99" -f (19 + ($i % 4)*10)  # 19.99,29.99,39.99,49.99
    $release = "2025-{0:00}-{1:00}" -f ((($i % 12)+1)), ((($i % 25)+1))
    $promoTag = if ($i % 4 -eq 0) { " [PROMOTION]" } else { "" }

    SafePost ("[G] publish $gid by $pub") "$($env:PUBLISHER_URL)/publisher/publish-game" @{
        gameId=$gid
        title=("Game $i")
        description=("Seeded description $i$promoTag")
        platform=$plat
        genre=$genre
        idEditeur=$pub
        version=("1.{0}.0" -f $i)
        prixInit=$price
        releaseDate=$release
    } | Out-Null
    SleepMs 150
}

Write-Host "`n[4c] (OPTIONNEL) Count games by publisher (R200)..."
(TryGet "$($env:PUBLISHER_URL)/publisher/games/count?idEditeur=R200") | ConvertTo-Json -Depth 10
Start-Sleep -Seconds 1

# =========================
# 4) Social: follows user + follow redactors
# =========================
Write-Host "`n[5] Social: création de $NB_FOLLOWS follows aléatoires..."
$rand = New-Object System.Random
for ($i=1; $i -le $NB_FOLLOWS; $i++) {
    $a = $UserIds[ $rand.Next(0, $UserIds.Count) ]
    $b = $UserIds[ $rand.Next(0, $UserIds.Count) ]
    if ($a -eq $b) { continue }

    SafePost ("[F] $a suit $b") "$($env:PLATFORM_URL)/platform/users/follow" @{
        userId=$a; followedId=$b
    } | Out-Null

    if ($i % 3 -eq 0) {
        $r = $RedactorIds[ $rand.Next(0, $RedactorIds.Count) ]
        try {
            SafePost ("[F] $a suit l'éditeur $r") "$($env:PLATFORM_URL)/platform/users/follow-redactor" @{
                userId=$a; redactorId=$r
            } | Out-Null
        } catch { }
    }
    SleepMs 120
}

Write-Host "`n[5b] (OPTIONNEL) Liste éditeurs suivis par U100..."
(TryGet "$($env:PLATFORM_URL)/platform/users/following-redactors?userId=U100") | ConvertTo-Json -Depth 10

# =========================
# 5) Purchases / Library: many purchases & sales-count checks
# =========================
Write-Host "`n[6] Achats: création de $NB_PURCHASES achats (user x game)..."
for ($i=1; $i -le $NB_PURCHASES; $i++) {
    $u = $UserIds[ $rand.Next(0, $UserIds.Count) ]
    $g = $GameIds[ $rand.Next(0, $GameIds.Count) ]
    SafePost ("[BUY] $u achète $g") "$($env:PLATFORM_URL)/platform/purchases/game" @{
        userId=$u; gameId=$g
    } | Out-Null
    SleepMs 120
}

Write-Host "`n[7] Bibliothèque de U100..."
(TryGet "$($env:PLATFORM_URL)/platform/purchases/library?userId=U100") | ConvertTo-Json -Depth 10
Write-Host "`n[7c] (OPTIONNEL) Sales count G300..."
(TryGet "$($env:PLATFORM_URL)/platform/purchases/sales-count?gameId=G300") | ConvertTo-Json -Depth 10

# =========================
# 6) Gameplay sessions: many sessions
# =========================
Write-Host "`n[8] Gameplay sessions: création de $NB_SESSIONS sessions (start/end)..."
for ($i=1; $i -le $NB_SESSIONS; $i++) {
    $u = $UserIds[ $rand.Next(0, $UserIds.Count) ]
    $g = $GameIds[ $rand.Next(0, $GameIds.Count) ]

    SafePost ("[S] start $u->$g") "$($env:PLATFORM_URL)/platform/sessions/start" @{ userId=$u; gameId=$g } | Out-Null
    Start-Sleep -Seconds 3  # règle dans ton script
    SafePost ("[S] end   $u->$g") "$($env:PLATFORM_URL)/platform/sessions/end" @{ userId=$u; gameId=$g } | Out-Null
}

Write-Host "`n[10] Temps de jeu U100 (tous jeux)..."
(TryGet "$($env:PLATFORM_URL)/platform/sessions/users/U100/playtime") | ConvertTo-Json -Depth 10

# =========================
# 7) Reviews: many reviews + helpful votes
# =========================
Write-Host "`n[12] Reviews: création de $NB_REVIEWS avis..."
$ReviewIds = New-Object System.Collections.Generic.List[string]

for ($i=1; $i -le $NB_REVIEWS; $i++) {
    $u = $UserIds[ $rand.Next(0, $UserIds.Count) ]
    $g = $GameIds[ $rand.Next(0, $GameIds.Count) ]
    $note = $rand.Next(3, 11) # 3..10
    $desc = "Seed review $i ($u -> $g) note=$note"

    try {
        $rev = PostForm "$($env:PLATFORM_URL)/platform/reviews/submit" @{ userId=$u; gameId=$g; note="$note"; description=$desc }
        $rev | ConvertTo-Json -Depth 10 | Out-Null
        try {
            if ($rev.reviewId) { $ReviewIds.Add([string]$rev.reviewId) | Out-Null }
        } catch {}
    } catch { Write-Host "review submit failed ($u,$g)"; }

    # votes helpful (1/2 du temps)
    if ($i % 2 -eq 0 -and $ReviewIds.Count -gt 0) {
        $voter = $UserIds[ $rand.Next(0, $UserIds.Count) ]
        $rid = $ReviewIds[ $rand.Next(0, $ReviewIds.Count) ]
        try {
            PostForm "$($env:PLATFORM_URL)/platform/reviews/$rid/rate" @{ userId=$voter; isHelpful="true" } | Out-Null
        } catch { }
    }
    SleepMs 120
}

Write-Host "`n[15] Feedback reviews (paginé) G300..."
(TryGet "$($env:PLATFORM_URL)/platform/feedback/reviews?gameId=G300&minNote=0&sort=desc&page=0&size=20") | ConvertTo-Json -Depth 10
Write-Host "`n[17] Stats reviews G300..."
(TryGet "$($env:PLATFORM_URL)/platform/feedback/reviews/G300/stats") | ConvertTo-Json -Depth 10

# =========================
# 8) Incidents: many incidents (various severities)
# =========================
Write-Host "`n[14] Incidents: création de $NB_INCIDENTS incidents..."
for ($i=1; $i -le $NB_INCIDENTS; $i++) {
    $u = $UserIds[ $rand.Next(0, $UserIds.Count) ]
    $g = $GameIds[ $rand.Next(0, $GameIds.Count) ]
    $sev = $Severities[ ($i-1) % $Severities.Count ]
    $envt = if ($i % 2 -eq 0) { "Windows 11" } else { "Ubuntu 22.04" }
    $desc = "Seed incident $i ($sev) on $g by $u"

    SafePost ("[INC] $u -> $g ($sev)") "$($env:PLATFORM_URL)/platform/incidents/report" @{
        userId=$u; gameId=$g; severity=$sev; description=$desc; environment=$envt
    } | Out-Null
    SleepMs 150
}

Write-Host "`n[16] Feedback incidents (paginé) G300 (severity=HAUTE)..."
(TryGet "$($env:PLATFORM_URL)/platform/feedback/incidents?gameId=G300&severity=HAUTE&page=0&size=20") | ConvertTo-Json -Depth 10

# =========================
# 9) Patches: many patches (multi modifications)
# =========================
Write-Host "`n[18] Patches: création de $NB_PATCHES patches..."
$ModsPool = @("CORRECTION","OPTIMISATION","AJOUT","SECURITE","PERF","UX")
for ($i=1; $i -le $NB_PATCHES; $i++) {
    $g = $GameIds[ $rand.Next(0, $GameIds.Count) ]
    $mods = @(
        $ModsPool[ $rand.Next(0, $ModsPool.Count) ],
        $ModsPool[ $rand.Next(0, $ModsPool.Count) ]
    ) | Select-Object -Unique

    SafePostMulti ("[PATCH] $g -> 1.0.$i") "$($env:PUBLISHER_URL)/publisher/publish-patch" `
      @{ gameId=$g; targetVersion=("1.0.{0}" -f $i); patchNotes=("Seed patch $i for $g"); releasedAt=("2025-11-{0:00}" -f (($i%28)+1)) } `
      @{ modifications=$mods } | Out-Null

    SleepMs 120
}

# =========================
# 10) Final catalog checks (some random games)
# =========================
Write-Host "`n[19] Vérification finale du catalogue (quelques jeux)..."
(TryGet "$($env:PLATFORM_URL)/platform/catalog/games/G300") | ConvertTo-Json -Depth 10
for ($i=0; $i -lt 3; $i++) {
    $g = $GameIds[ $rand.Next(0, $GameIds.Count) ]
    Write-Host "`n[19b] Détails catalogue $g ..."
    (TryGet "$($env:PLATFORM_URL)/platform/catalog/games/$g") | ConvertTo-Json -Depth 10
}

Write-Host "`n[19c] Liste catalogue (sans filtre)..."
(TryGet "$($env:PLATFORM_URL)/platform/catalog/games") | ConvertTo-Json -Depth 10

# =========================
# 11) OPTIONAL: Notifications
# =========================
if ($SEND_NOTIFS) {
    Write-Host "`n[20] Notifications: envoi de quelques notifs..."
    foreach ($u in @("U100","U200") + $UserIds[0..([Math]::Min(3, $UserIds.Count-1))]) {
        try {
            (PostForm "$($env:NOTIF_URL)/notifications/send" @{
                userId=$u; type="TEST_NOTIF"; message=("Seed notif for $u at {0}" -f (Get-Date).ToString("s"))
            }) | ConvertTo-Json -Depth 10 | Out-Null
        } catch { Write-Host "notif send failed (service peut être absent)"; }
    }

    Write-Host "`n[21] (OPTIONNEL) Lecture des notifications de U100..."
    (TryGet "$($env:NOTIF_URL)/notifications/U100") | ConvertTo-Json -Depth 10
}

Write-Host "========================================="
Write-Host "   Fin des tests d'intégration (seed)    "
Write-Host "========================================="