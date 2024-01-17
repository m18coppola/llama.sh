#!/bin/sh

LOG="${HOME}/chat.txt"
PY_LOG="${HOME}/py_log.py"
printf "%s" 'You are Quentin. Quentin is a useful assistant who writes Python code to answer questions in a
```python
# insert code here
```
block.' > "$LOG"
printf "" > "$PY_LOG"
while true; do
	printf "user:\n"
	read -r user_input
	printf "assistant:\n"
	printf "%s" "$user_input" | llama.sh --stop '```python' -l "$LOG" "$(cat "$LOG")"
	LOG_TAIL="$(tail -n1 "$LOG")"
	if [ "${LOG_TAIL#*'```python'}" != "$LOG_TAIL" ]; then
		printf "" | llama.sh --stop '```' -l "$LOG" --raw "$(cat "$LOG")" | tee "$PY_LOG"
		sed -i '$d' "$PY_LOG"
		printf "\033[31mRUN PYTHON SCRIPT? [y/N] \033[0m"
		printf "\n\n" >> "$LOG"
		read -r yn
		case $yn in
			[Yy]* )
				printf "\`\`\`output\n" | tee -a "$LOG"
				python3 "$PY_LOG" | tee -a "$LOG"
				printf "\`\`\`\n" | tee -a "$LOG" ;;
			* ) ;;
		esac
		printf "\033[33mFollow-up response? [y/N] \033[0m"
		read -r yn
		case $yn in
			[Yy]* )
				printf "" | llama.sh -l "$LOG" --raw "$(cat "$LOG")" ;;
			* ) ;;
		esac
	fi
done
