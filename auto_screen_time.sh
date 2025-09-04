#!/usr/bin/env bash

# auto_screen_time.sh
# Automatically track Windows screen time (requires WSL)
# Uses Windows event logs (Lock/Unlock) and stores locally

DATA_FILE="$HOME/.screen_time_log.csv"
SESSION_FILE="/tmp/screen_time_session"

# Ensure data file exists
if [ ! -f "$DATA_FILE" ]; then
    echo "date,start_time,end_time,duration_minutes" > "$DATA_FILE"
fi

log_event() {
    EVENT=$1
    TS=$(date +%s)

    if [ "$EVENT" = "unlock" ]; then
        echo "$TS" > "$SESSION_FILE"
    elif [ "$EVENT" = "lock" ]; then
        if [ -f "$SESSION_FILE" ]; then
            START_TS=$(cat "$SESSION_FILE")
            END_TS=$TS
            DURATION=$(( (END_TS - START_TS) / 60 ))
            rm -f "$SESSION_FILE"

            DATE=$(date +%Y-%m-%d)
            START_TIME=$(date -d "@$START_TS" +%H:%M:%S)
            END_TIME=$(date -d "@$END_TS" +%H:%M:%S)

            echo "$DATE,$START_TIME,$END_TIME,$DURATION" >> "$DATA_FILE"
        fi
    fi
}

monitor_events() {
    powershell.exe -Command "
        \$q = Get-WinEvent -LogName 'Security' -MaxEvents 0 -ErrorAction SilentlyContinue
        while (\$true) {
            \$events = Get-WinEvent -LogName 'Security' -MaxEvents 1
            if (\$events.Id -eq 4800) { echo lock; }
            elseif (\$events.Id -eq 4801) { echo unlock; }
            Start-Sleep -Seconds 5
        }
    " | while read -r line; do
        if [ "$line" = "lock" ]; then
            log_event "lock"
        elif [ "$line" = "unlock" ]; then
            log_event "unlock"
        fi
    done
}

show_log() {
    column -t -s, "$DATA_FILE"
}

case "$1" in
    run)
        monitor_events
        ;;
    log)
        show_log
        ;;
    *)
        echo "Usage: $0 {run|log}"
        ;;
esac
