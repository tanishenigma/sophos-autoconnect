#!/bin/bash

HOST="http://172.16.73.12:8090"
ACCOUNTS="$HOME/.config/sophos/accounts"
COOKIE="$HOME/.config/sophos/cookies"

KEEPALIVE=170
RETRY_DELAY=30

# A SIGUSR1 (sent by `sophos retry`) forces the client to drop the current
# account immediately and search again, instead of waiting for the next
# keepalive to fail.
FORCE_RETRY=false
trap 'FORCE_RETRY=true' SIGUSR1

mkdir -p "$HOME/.config/sophos"
chmod 700 "$HOME/.config/sophos"

if [[ ! -f "$ACCOUNTS" ]]; then
    echo "Accounts file not found: $ACCOUNTS"
    exit 1
fi

mapfile -t ACCOUNT_LIST < <(
    sed '/^[[:space:]]*#/d;/^[[:space:]]*$/d' "$ACCOUNTS"
)

COUNT=${#ACCOUNT_LIST[@]}

if (( COUNT == 0 )); then
    echo "No accounts configured."
    exit 1
fi


login() {
    local USER="$1"
    local PASS="$2"

    rm -f "$COOKIE"

    RESPONSE=$(curl -sS \
        --connect-timeout 5 \
        --max-time 15 \
        -c "$COOKIE" \
        -b "$COOKIE" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        --data-urlencode "mode=191" \
        --data-urlencode "username=$USER" \
        --data-urlencode "password=$PASS" \
        --data-urlencode "a=$(date +%s%3N)" \
        --data-urlencode "producttype=0" \
        "$HOST/login.xml")

    if echo "$RESPONSE" | grep -q \
        '<status><!\[CDATA\[LIVE\]\]></status>'; then
        return 0
    fi

    return 1
}


keepalive() {
    local USER="$1"

    RESPONSE=$(curl -sS \
        --connect-timeout 5 \
        --max-time 15 \
        -b "$COOKIE" \
        -G \
        --data-urlencode "mode=192" \
        --data-urlencode "username=$(printf '%s' "$USER" | tr '[:upper:]' '[:lower:]')" \
        --data-urlencode "a=$(date +%s%3N)" \
        --data-urlencode "producttype=0" \
        "$HOST/live")

    echo "$RESPONSE" | grep -qi "ack"
}


while true; do

    FOUND_ACCOUNT=false

    echo "Searching for a working Sophos account..."

    # Start from a random account so we don't always
    # hammer the first account in the file.
    START=$(( RANDOM % COUNT ))

    for ((OFFSET=0; OFFSET<COUNT; OFFSET++)); do

        INDEX=$(( (START + OFFSET) % COUNT ))

        ACCOUNT="${ACCOUNT_LIST[$INDEX]}"

        USER="${ACCOUNT%%:*}"
        PASS="${ACCOUNT#*:}"

        echo "Trying account: $USER"

        if login "$USER" "$PASS"; then

            echo "✓ Working account found: $USER"
            echo "✓ Sophos session active"

            FOUND_ACCOUNT=true

            # Keep this account alive until the session dies.
            while true; do

                # Sleep in the background and wait on it, so a SIGUSR1
                # interrupts the wait immediately for a forced retry.
                sleep "$KEEPALIVE" &
                SLEEP_PID=$!
                wait "$SLEEP_PID" 2>/dev/null

                if [[ "$FORCE_RETRY" == true ]]; then
                    FORCE_RETRY=false
                    kill "$SLEEP_PID" 2>/dev/null
                    echo "[$(date '+%H:%M:%S')] ⟳ $USER — forced retry requested"
                    echo "Searching for another working account..."
                    break
                fi

                if keepalive "$USER"; then
                    echo "[$(date '+%H:%M:%S')] ✓ $USER — session alive"
                else
                    echo "[$(date '+%H:%M:%S')] ✗ $USER — session lost"
                    echo "Searching for another working account..."
                    break
                fi

            done

            break
        else
            echo "✗ $USER failed"
        fi

    done

    if [[ "$FOUND_ACCOUNT" == false ]]; then
        echo
        echo "No working accounts found."
        echo "Retrying in ${RETRY_DELAY}s..."
        sleep "$RETRY_DELAY"
    fi

done
