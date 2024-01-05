#!/bin/sh

LOG="${HOME}/chat.txt"
printf "" > "$LOG"
while true; do
	printf "user:\n"
	read -r user_input
	printf "assistant:\n"
	printf "%s" "$user_input" | ./llama.sh -l "$LOG" "$(cat "$LOG")"
done
