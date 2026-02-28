#!/usr/bin/env bash

# =========================
# Config
# =========================
PUBLISHER_URL="${PUBLISHER_URL:-http://localhost:8082}"
PLATFORM_URL="${PLATFORM_URL:-http://localhost:8081}"

export PUBLISHER_URL
export PLATFORM_URL

# =========================
# Session
# =========================
CURRENT_EMAIL=""
CURRENT_USER_ID=""
CURRENT_ROLE="NONE"  # NONE | USER | REDACTOR

# =========================
# Utils
# =========================
pause() {
    read -r -p "Appuyez sur Entrée..." < /dev/tty
}

banner() {
    clear
    echo "====================================="
    echo "     SouqStation Interactive CLI     "
    echo "====================================="
    if [ "$CURRENT_ROLE" = "NONE" ]; then
        echo "Non connecté"
    else
        echo "Connecté en tant que: $CURRENT_EMAIL [$CURRENT_ROLE] (userId=$CURRENT_USER_ID)"
    fi
    echo "-------------------------------------"
}

prompt() {
    local label=$1
    local default=$2
    local v
    if [ -n "$default" ]; then
        read -r -p "$label [$default]: " v < /dev/tty
        if [ -z "$v" ]; then
            echo "$default"
        else
            echo "$v"
        fi
    else
        read -r -p "$label: " v < /dev/tty
        echo "$v"
    fi
}

# =========================
# Actions
# =========================

action_register_user() {
    local userId=$(prompt "userId" "user-1")
    local name=$(prompt "nom" "John Doe")
    local email=$(prompt "email" "user@test.com")
    local displayName=$(prompt "pseudo" "JohnD")
    local birth=$(prompt "Date de naissance (AAAA-MM-JJ)" "1990-01-01")
    local solde=$(prompt "solde" "0.0")

    echo "Inscription de l'utilisateur..."
    curl -sSf -X POST "$PLATFORM_URL/platform/register-user" \
        --data-urlencode "userId=$userId" \
        --data-urlencode "name=$name" \
        --data-urlencode "email=$email" \
        --data-urlencode "displayName=$displayName" \
        --data-urlencode "birth=$birth" \
        --data-urlencode "solde=$solde" | jq . || echo "Requête échouée"
    
    echo "Opération terminée."
    pause
}

action_register_redactor() {
    local userId=$(prompt "userId" "redactor-1")
    local name=$(prompt "nom" "Jane Doe")
    local email=$(prompt "email" "redactor@test.com")
    local displayName=$(prompt "pseudo" "JaneD")
    local birth=$(prompt "Date de naissance (AAAA-MM-JJ)" "1985-01-01")
    local solde=$(prompt "solde" "0.0")
    local individual=$(prompt "Particulier (true/false)" "true")

    echo "Inscription de l'éditeur..."
    curl -sSf -X POST "$PLATFORM_URL/platform/register-redactor" \
        --data-urlencode "userId=$userId" \
        --data-urlencode "name=$name" \
        --data-urlencode "email=$email" \
        --data-urlencode "displayName=$displayName" \
        --data-urlencode "birth=$birth" \
        --data-urlencode "solde=$solde" \
        --data-urlencode "individual=$individual" | jq . || echo "Requête échouée"
    
    echo "Opération terminée."
    pause
}

login() {
    local email=$(prompt "email" "redactor@test.com")
    
    echo "Vérification de l'utilisateur..."
    local check_res=$(curl -s "$PLATFORM_URL/platform/users/check-email?email=$email")
    local exists=$(echo "$check_res" | jq -r 'if type=="object" then .exists else "false" end')
    
    if [ "$exists" != "true" ]; then
        echo "Utilisateur introuvable"
        pause
        return
    fi
    
    CURRENT_EMAIL="$email"
    CURRENT_USER_ID=$(echo "$check_res" | jq -r '.userId')
    
    echo "Vérification du statut d'éditeur..."
    local red_res=$(curl -s "$PLATFORM_URL/platform/redactors/exists?userId=$CURRENT_USER_ID")
    local r_exists=$(echo "$red_res" | jq -r 'if type=="object" then .exists else "false" end')
    
    if [ "$r_exists" = "true" ]; then
        CURRENT_ROLE="REDACTOR"
        echo "Bienvenue éditeur"
        # UX count
        local count=$(curl -s "$PUBLISHER_URL/publisher/games/count?idEditeur=$CURRENT_USER_ID" || echo "0")
        echo "Vous avez publié $count jeux"
    else
        CURRENT_ROLE="USER"
        echo "Bienvenue utilisateur"
    fi
    pause
}

logout() {
    CURRENT_EMAIL=""
    CURRENT_USER_ID=""
    CURRENT_ROLE="NONE"
    echo "Déconnecté"
    pause
}

follow_user() {
    local followedId=$(prompt "ID de l'utilisateur à suivre" "U200")
    
    if [ "$followedId" = "$CURRENT_USER_ID" ]; then
        echo "Vous ne pouvez pas vous suivre vous-même."
        pause
        return
    fi
    
    curl -sSf -X POST "$PLATFORM_URL/platform/users/follow" \
        --data-urlencode "userId=$CURRENT_USER_ID" \
        --data-urlencode "followedId=$followedId" | jq . || echo "Requête échouée"
    
    echo "Vous suivez maintenant $followedId"
    pause
}

show_following() {
    echo "Abonnements:"
    curl -sSf "$PLATFORM_URL/platform/users/following?userId=$CURRENT_USER_ID" | jq . || echo "Requête échouée"
    pause
}

publish_game() {
    if [ "$CURRENT_ROLE" != "REDACTOR" ]; then
        echo "La publication est réservée aux ÉDITEURS."
        pause
        return
    fi

    local gameId=$(prompt "gameId" "G300")
    local title=$(prompt "Titre du jeu" "Halo")
    local description=$(prompt "Description" "Action FPS")
    local platform=$(prompt "Plateforme" "PC")
    local genre=$(prompt "Genre" "ACTION")
    local version=$(prompt "Version" "1.0.0")
    local releaseDate=$(prompt "Date de sortie (AAAA-MM-JJ)" "2026-01-01")
    local price=$(prompt "Prix initial (optionnel)" "")

    local cmd="curl -sSf -X POST '$PUBLISHER_URL/publisher/publish-game' \
        --data-urlencode 'gameId=$gameId' \
        --data-urlencode 'title=$title' \
        --data-urlencode 'description=$description' \
        --data-urlencode 'platform=$platform' \
        --data-urlencode 'genre=$genre' \
        --data-urlencode 'idEditeur=$CURRENT_USER_ID' \
        --data-urlencode 'version=$version' \
        --data-urlencode 'releaseDate=$releaseDate'"
        
    if [ -n "$price" ]; then
        cmd="$cmd --data-urlencode 'prixInit=$price'"
    fi
    
    eval "$cmd | jq ." || echo "Échec de la publication du jeu"
    pause
}

my_games() {
    if [ "$CURRENT_ROLE" != "REDACTOR" ]; then
        echo "Accès réservé aux ÉDITEURS."
        pause
        return
    fi

    curl -sSf "$PUBLISHER_URL/publisher/games/by-publisher?idEditeur=$CURRENT_USER_ID" | jq . || echo "Impossible de récupérer les jeux"
    pause
}

follow_redactor() {
    local redactorId=$(prompt "ID de l'éditeur à suivre" "redactor-1")
    curl -sSf -X POST "$PLATFORM_URL/platform/users/follow-redactor" \
        --data-urlencode "userId=$CURRENT_USER_ID" \
        --data-urlencode "redactorId=$redactorId" | jq . || echo "Requête échouée"
    echo "Vous suivez maintenant l'éditeur $redactorId"
    pause
}

show_games_of_followed_editor() {
    local editorsUrl="$PLATFORM_URL/platform/users/following-redactors?userId=$CURRENT_USER_ID"
    local editors=$(curl -s "$editorsUrl")
    local count=$(echo "$editors" | jq '. | length')
    
    if [ "$count" = "0" ] || [ -z "$count" ]; then
        echo "Vous ne suivez encore aucun éditeur."
        pause
        return
    fi

    echo "Éditeurs que vous suivez:"
    echo "$editors" | jq -r '.[] | "\(.displayName) (\(.userId))"'
    
    local editorId=$(prompt "Entrez l'ID de l'éditeur pour voir ses jeux")
    if [ -z "$editorId" ]; then
        pause
        return
    fi
    
    echo "Jeux publiés par $editorId:"
    curl -sSf "$PUBLISHER_URL/publisher/games/by-publisher?idEditeur=$editorId" | jq . || echo "Requête échouée"
    pause
}

show_followed_redactors() {
    echo "Éditeurs que vous suivez:"
    curl -sSf "$PLATFORM_URL/platform/users/following-redactors?userId=$CURRENT_USER_ID" | jq . || echo "Requête échouée"
    pause
}

# =========================
# Store & Social added features
# =========================
purchase_game() {
    local gameId=$(prompt "gameId" "G300")
    echo "Achat du jeu en cours..."
    curl -sSf -X POST "$PLATFORM_URL/platform/purchases/game" \
        --data-urlencode "userId=$CURRENT_USER_ID" \
        --data-urlencode "gameId=$gameId" | jq . || echo "Requête échouée"
    pause
}

show_library() {
    echo "Bibliothèque (Jeux):"
    curl -sSf "$PLATFORM_URL/platform/purchases/library?userId=$CURRENT_USER_ID" | jq . || echo "Requête échouée"
    pause
}

purchase_dlc() {
    local dlcId=$(prompt "dlcId" "D300")
    echo "Achat du DLC en cours..."
    curl -sSf -X POST "$PLATFORM_URL/platform/purchases/dlc" \
        --data-urlencode "userId=$CURRENT_USER_ID" \
        --data-urlencode "dlcId=$dlcId" | jq . || echo "Requête échouée"
    pause
}

show_dlc_library() {
    echo "Bibliothèque (DLCs):"
    curl -sSf "$PLATFORM_URL/platform/purchases/dlc-library?userId=$CURRENT_USER_ID" | jq . || echo "Requête échouée"
    pause
}

submit_review() {
    local gameId=$(prompt "gameId" "G300")
    local note=$(prompt "Note (0-10)" "9")
    local description=$(prompt "Commentaire" "Super jeu !")

    curl -sSf -X POST "$PLATFORM_URL/platform/reviews/submit" \
        --data-urlencode "userId=$CURRENT_USER_ID" \
        --data-urlencode "gameId=$gameId" \
        --data-urlencode "note=$note" \
        --data-urlencode "description=$description" | jq . || echo "Requête échouée"
    pause
}

rate_review() {
    local reviewId=$(prompt "reviewId (ID de l'avis)")
    if [ -z "$reviewId" ]; then
        pause
        return
    fi
    local isHelpful=$(prompt "Est-ce utile ? (true/false)" "true")

    curl -sSf -X POST "$PLATFORM_URL/platform/reviews/$reviewId/rate" \
        --data-urlencode "userId=$CURRENT_USER_ID" \
        --data-urlencode "isHelpful=$isHelpful" | jq . || echo "Requête échouée"
    pause
}

report_incident() {
    local gameId=$(prompt "gameId" "G300")
    local severity=$(prompt "Sévérité (CRITIQUE/HAUTE/NORMALE/BASSE)" "HAUTE")
    local description=$(prompt "Description du bug" "Plantage au lancement")
    local environment=$(prompt "Environnement" "Windows 11")

    curl -sSf -X POST "$PLATFORM_URL/platform/incidents/report" \
        --data-urlencode "userId=$CURRENT_USER_ID" \
        --data-urlencode "gameId=$gameId" \
        --data-urlencode "severity=$severity" \
        --data-urlencode "description=$description" \
        --data-urlencode "environment=$environment" | jq . || echo "Requête échouée"
    pause
}

publish_patch() {
    if [ "$CURRENT_ROLE" != "REDACTOR" ]; then
        echo "La publication de patch est réservée aux ÉDITEURS."
        pause
        return
    fi
    local gameId=$(prompt "gameId" "G300")
    local targetVersion=$(prompt "Version cible" "1.0.1")
    local description=$(prompt "Notes de patch" "Correction de bugs")
    local releasedAt=$(prompt "Date de sortie (AAAA-MM-JJ)" "2026-02-25")
    local modification=$(prompt "Modifications (CORRECTION/AJOUT/OPTIMISATION)" "CORRECTION")

    curl -sSf -X POST "$PUBLISHER_URL/publisher/publish-patch" \
        --data-urlencode "gameId=$gameId" \
        --data-urlencode "targetVersion=$targetVersion" \
        --data-urlencode "description=$description" \
        --data-urlencode "releasedAt=$releasedAt" \
        --data-urlencode "modifications=$modification" | jq . || echo "Requête échouée"
    pause
}

publish_dlc() {
    if [ "$CURRENT_ROLE" != "REDACTOR" ]; then
        echo "La publication est réservée aux ÉDITEURS."
        pause
        return
    fi

    local dlcId=$(prompt "dlcId" "D300")
    local gameId=$(prompt "gameId (jeu de base)" "G300")
    local name=$(prompt "Nom du DLC" "Blood and Wine")
    local description=$(prompt "Description" "Extension solo")
    local releaseDate=$(prompt "Date de sortie (AAAA-MM-JJ)" "2026-06-01")
    local price=$(prompt "Prix" "19.99")

    curl -sSf -X POST "$PUBLISHER_URL/publisher/publish-dlc" \
        --data-urlencode "dlcId=$dlcId" \
        --data-urlencode "gameId=$gameId" \
        --data-urlencode "name=$name" \
        --data-urlencode "description=$description" \
        --data-urlencode "publisherId=$CURRENT_USER_ID" \
        --data-urlencode "releaseDate=$releaseDate" \
        --data-urlencode "price=$price" | jq . || echo "Requête échouée"
    pause
}

# =========================
# Menu loop
# =========================
while true; do
    banner
    
    if [ "$CURRENT_ROLE" = "NONE" ]; then
        echo "1) Créer un compte Utilisateur"
        echo "2) Créer un compte Éditeur"
        echo "3) Se connecter"
        echo "0) Quitter"
        read -r -p "Choix: " c < /dev/tty
        
        case "$c" in
            1) action_register_user ;;
            2) action_register_redactor ;;
            3) login ;;
            0) break ;;
            *) echo "Choix invalide"; pause ;;
        esac
        continue
    fi

    echo "--- Social & Boutique ---"
    echo " 1) Suivre un utilisateur"
    echo " 2) Mes abonnements (Users)"
    echo " 3) Suivre un éditeur"
    echo " 4) Mes abonnements (Éditeurs)"
    echo " 5) Voir le catalogue d'un éditeur suivi"
    echo " 6) Acheter un jeu"
    echo " 7) Ma bibliothèque (Jeux)"
    echo " 8) Acheter un DLC"
    echo " 9) Ma bibliothèque (DLCs)"
    echo "10) Évaluer un jeu"
    echo "11) Noter un avis (utile/inutile)"
    echo "12) Signaler un bug / incident"

    if [ "$CURRENT_ROLE" = "REDACTOR" ]; then
        echo "--- Éditeur ---"
        echo "13) Publier un jeu"
        echo "14) Publier un patch"
        echo "15) Publier un DLC"
        echo "16) Mes jeux publiés"
        echo "17) Se déconnecter"
    else
        echo "13) Se déconnecter"
    fi
    echo " 0) Quitter"
    
    read -r -p "Choix: " c < /dev/tty
    
    case "$c" in
        1) follow_user ;;
        2) show_following ;;
        3) follow_redactor ;;
        4) show_followed_redactors ;;
        5) show_games_of_followed_editor ;;
        6) purchase_game ;;
        7) show_library ;;
        8) purchase_dlc ;;
        9) show_dlc_library ;;
        10) submit_review ;;
        11) rate_review ;;
        12) report_incident ;;
        13)
            if [ "$CURRENT_ROLE" = "REDACTOR" ]; then
                publish_game
            else
                logout
            fi
            ;;
        14)
            if [ "$CURRENT_ROLE" = "REDACTOR" ]; then
                publish_patch
            else
                echo "Choix invalide"; pause
            fi
            ;;
        15)
            if [ "$CURRENT_ROLE" = "REDACTOR" ]; then
                publish_dlc
            else
                logout
            fi
            ;;
        16)
            if [ "$CURRENT_ROLE" = "REDACTOR" ]; then
                my_games
            else
                echo "Choix invalide"; pause
            fi
            ;;
        17)
            if [ "$CURRENT_ROLE" = "REDACTOR" ]; then
                logout
            else
                echo "Choix invalide"; pause
            fi
            ;;
        0) break ;;
        *) echo "Choix invalide"; pause ;;
    esac
done
