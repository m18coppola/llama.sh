#!/bin/sh

LOG="${HOME}/chat.txt"
FIRST_MESSAGE=1

printf "" > "$LOG"
while true; do
	printf "user:\n"
	read -r user_input
	printf "assistant:\n"
	if [ "$FIRST_MESSAGE" = "0" ]; then
		export LSH_SYSTEM_PROMPT_PREFIX=''
	fi
	printf "%s" "$user_input" | llama.sh -l "$LOG" "$(cat "$LOG")"
	FIRST_MESSAGE=0
done
