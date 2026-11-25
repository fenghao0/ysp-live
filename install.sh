#!/bin/sh
# ysp-live one-click installer and manager

CONTAINER_NAME="ysp-live"
ROOT_DIR="/root/ysp-live"
PROJECT_DIR="$ROOT_DIR/ysp-live-main"
DATA_DIR="$PROJECT_DIR/data"
PORT="8767"
REPO_ZIP="https://codeload.github.com/tmxk2020/ysp-live/zip/refs/heads/main"

say() { printf '%s\n' "$*"; }
line() { say '============================================================'; }

get_local_ip() {
    ip_addr=""
    if command -v uci >/dev/null 2>&1; then
        ip_addr=$(uci get network.lan.ipaddr 2>/dev/null)
    fi
    if [ -z "$ip_addr" ] && command -v hostname >/dev/null 2>&1; then
        ip_addr=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    [ -n "$ip_addr" ] || ip_addr="127.0.0.1"
    printf '%s' "$ip_addr"
}

show_links() {
    ip_addr=$(get_local_ip)
    line
    say "ysp-live service addresses"
    printf '  Playlist: http://%s:%s/all.m3u\n' "$ip_addr" "$PORT"
    printf '  Health:   http://%s:%s/health\n' "$ip_addr" "$PORT"
    printf '  Diagnose: http://%s:%s/diag\n' "$ip_addr" "$PORT"
    line
}

docker_compose_cmd() {
    if docker compose version >/dev/null 2>&1; then
        COMPOSE="docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        COMPOSE="docker-compose"
    else
        say "ERROR: Docker Compose was not found. Install Docker Compose first."
        return 1
    fi
    return 0
}

fetch_source() {
    TMP_DIR="$ROOT_DIR/.update-tmp"
    ZIP_FILE="$ROOT_DIR/ysp-live-latest.zip"
    rm -rf "$TMP_DIR"
    mkdir -p "$TMP_DIR" || return 1
    say "[1/4] Downloading the latest source from GitHub..."
    if command -v curl >/dev/null 2>&1; then
        curl -fL --connect-timeout 20 --retry 2 "$REPO_ZIP" -o "$ZIP_FILE" || return 1
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$ZIP_FILE" "$REPO_ZIP" || return 1
    else
        say "ERROR: curl or wget is required."
        return 1
    fi
    command -v unzip >/dev/null 2>&1 || { say "ERROR: unzip is required."; return 1; }
    unzip -q "$ZIP_FILE" -d "$TMP_DIR" || return 1
    SOURCE_DIR="$TMP_DIR/ysp-live-main"
    [ -f "$SOURCE_DIR/Dockerfile" ] || { say "ERROR: Dockerfile is missing from the downloaded source."; return 1; }
    [ -f "$SOURCE_DIR/docker-compose.yml" ] || { say "ERROR: docker-compose.yml is missing."; return 1; }
    [ -f "$SOURCE_DIR/install.sh" ] || say "WARNING: install.sh is not included in the source archive."
    return 0
}

do_install() {
    command -v docker >/dev/null 2>&1 || { say "ERROR: Docker was not found. Install Docker first."; return 1; }
    docker_compose_cmd || return 1
    mkdir -p "$ROOT_DIR" || return 1
    fetch_source || { say "ERROR: Source download or extraction failed. Existing installation was not changed."; return 1; }

    # Keep user data outside the temporary download and restore it after updating.
    OLD_PROJECT="$ROOT_DIR/project-old-$(date +%Y%m%d%H%M%S)"
    if [ -d "$DATA_DIR" ]; then
        mkdir -p "$ROOT_DIR/data-backup"
        cp -a "$DATA_DIR/." "$ROOT_DIR/data-backup/" 2>/dev/null
    fi
    if [ -d "$PROJECT_DIR" ]; then
        mv "$PROJECT_DIR" "$OLD_PROJECT" || return 1
    fi
    mv "$SOURCE_DIR" "$PROJECT_DIR" || {
        [ -d "$OLD_PROJECT" ] && mv "$OLD_PROJECT" "$PROJECT_DIR"
        return 1
    }
    if [ -d "$ROOT_DIR/data-backup" ] && [ ! -d "$PROJECT_DIR/data" ]; then
        mkdir -p "$PROJECT_DIR/data"
        cp -a "$ROOT_DIR/data-backup/." "$PROJECT_DIR/data/" 2>/dev/null
    fi
    mkdir -p "$PROJECT_DIR/data"
    cd "$PROJECT_DIR" || return 1

    say "[2/4] Building the latest image while the current service remains available..."
    $COMPOSE build
    result=$?
    if [ "$result" -ne 0 ]; then
        say "ERROR: Image build failed. The running container was not stopped."
        rm -rf "$PROJECT_DIR"
        [ -d "$OLD_PROJECT" ] && mv "$OLD_PROJECT" "$PROJECT_DIR"
        return 1
    fi
    say "[3/4] Restarting the service with the new version..."
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
    $COMPOSE up -d --remove-orphans
    result=$?
    if [ "$result" -ne 0 ]; then
        say "ERROR: New container failed to start. Restoring the previous project version..."
        FAILED_PROJECT="$ROOT_DIR/project-failed-$(date +%Y%m%d%H%M%S)"
        mv "$PROJECT_DIR" "$FAILED_PROJECT" 2>/dev/null
        [ -d "$OLD_PROJECT" ] && mv "$OLD_PROJECT" "$PROJECT_DIR"
        if [ -d "$PROJECT_DIR" ]; then
            cd "$PROJECT_DIR" && $COMPOSE up -d --build
        fi
        return 1
    fi
    say "[4/4] Waiting briefly for the service to start..."
    sleep 3
    if command -v curl >/dev/null 2>&1; then
        curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null 2>&1
        health=$?
    else
        wget -qO- "http://127.0.0.1:$PORT/health" >/dev/null 2>&1
        health=$?
    fi
    if [ "$health" -eq 0 ]; then
        say "Deployment completed. Health endpoint responded successfully."
    else
        say "Container was started, but health endpoint did not respond yet. Check logs."
    fi
    show_links
}

show_logs() {
    docker logs --tail 200 -f "$CONTAINER_NAME"
}

health_check() {
    if command -v curl >/dev/null 2>&1; then
        curl -sS "http://127.0.0.1:$PORT/health"
    else
        wget -qO- "http://127.0.0.1:$PORT/health"
    fi
    say ""
}

do_uninstall() {
    say "This removes the ysp-live container and project files."
    say "User data will be kept unless you choose the complete removal option."
    printf 'Continue? [y/N]: '
    read answer
    case "$answer" in y|Y|yes|YES) ;; *) say "Cancelled."; return 0 ;; esac
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
    if [ -d "$DATA_DIR" ]; then
        mkdir -p "$ROOT_DIR/data-backup"
        cp -a "$DATA_DIR/." "$ROOT_DIR/data-backup/" 2>/dev/null
    fi
    if [ -d "$PROJECT_DIR" ]; then
        cd / 2>/dev/null
        rm -rf "$PROJECT_DIR"
    fi
    say "Container and project files removed. Saved data is kept in $ROOT_DIR/data-backup."
}

do_purge() {
    say "WARNING: This permanently deletes the container, image, project files, and saved data."
    printf 'Type DELETE to confirm: '
    read answer
    [ "$answer" = "DELETE" ] || { say "Cancelled."; return 0; }
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
    docker image rm "ysp-live:20261125-TMXK" >/dev/null 2>&1 || true
    cd / 2>/dev/null
    rm -rf "$ROOT_DIR"
    say "Complete removal finished."
}

menu() {
    while :; do
        line
        say "ysp-live installer and management"
        line
        say "1) Install or update to the latest GitHub version"
        say "2) Show service addresses"
        say "3) View live container logs"
        say "4) Check service health"
        say "5) Uninstall (keep saved data)"
        say "6) Complete removal (delete saved data too)"
        say "0) Exit"
        line
        printf 'Select an option [0-6]: '
        read choice
        case "$choice" in
            1) do_install ;;
            2) show_links ;;
            3) show_logs ;;
            4) health_check ;;
            5) do_uninstall ;;
            6) do_purge ;;
            0) say "Exit."; return 0 ;;
            *) say "Invalid selection. Please enter 0-6." ;;
        esac
    done
}

if [ "$(id -u 2>/dev/null)" != "0" ]; then
    say "ERROR: Run this script as root."
    exit 1
fi
menu
