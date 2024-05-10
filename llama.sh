#!/bin/sh

# defaults
VERBOSE=0
API_URL='127.0.0.1:8080'
API_KEY='none'
PREFIX=' [INST] '
SUFFIX=' [/INST]'
RESPONSE_LOG="$HOME"'/.cache/last_response.txt'
SYSTEM_PROMPT=''
parameters="$(jq -nR '{
	prompt: "",
	repeat_penalty: 1,
	no_penalize_nl: true,
	repeat_last_n: 0,
	stream: true,
	temperature: 0.8,
	min_p: 0.05,
	top_p: 0.95,
	top_k: 40,
	n_predict: -1,
	cache_prompt: true,
}')"
###

# functions
printr() {
	printf "%s" "$*"
}

parse_event() {
	event_json="$(printr "$*" | cut -c6-)"
	if [ "$(printr "$event_json" | jq '.stop')" != "true" ]; then
		printr "$event_json" |
			jq '.content' |
			sed 's/^"\|"$//g;s/%/%%/g;s/\\"/"/g'
	elif [ "$(printr "$event_json" | jq '.stopped_word')" = "true" ]; then
		printr "$event_json" |
			jq '.stopping_word // ""' |
			sed 's/^"\|"$//g;s/%/%%/g;s/\\"/"/g'
	elif [ "$(printr "$event_json" | jq '.stopped_eos')" = "true" ]; then
		printf "</s>" >> "$RESPONSE_LOG"
	fi
}

parse_event_stream() {
	while IFS= read -r LINE; do
		printr "$LINE" | grep -q "data:*" &&
			printf "%b" "$(parse_event "$LINE")"
	done
}

test_connection() {
	STATUS="$(curl --url "$API_URL"'/health' --silent | jq -r '.status')"
	if [ "$STATUS" = "loading model" ]; then
		echo "$API_URL"' is still loading model, try again later.'
		exit 1
	elif [ "$STATUS" = "error" ]; then
		echo "$API_URL"' is unable to load the model.'
		exit 1
	elif [ "$STATUS" != "ok" ]; then
		echo 'failed to connect to '"$API_URL"
		exit 1
	fi
	STATUS="$(curl --url "$API_URL"'/completion' \
			--silent \
			--header 'Authorization: Bearer '"$API_KEY" \
			--data '{"n_predict":0}')"
	if [ "$STATUS" = "Unauthorized" ]; then
		echo 'API key is not authorized.'
		exit 1
	fi
}

get_parameter() {
	param=".${1}"
	printr "$parameters" | jq "$param"
}

print_usage() {
	cat << EOF
Usage:
	llama.sh [--options] "prompt"
	echo "prompt" | llama.sh [--options]
	echo "prompt" | llama.sh [--options] "system prompt"
Flags:
	--n-predict N, -n N        (number of tokens to generate, -1 for inf. default: $(printr "$(get_parameter 'n_predict')"))
	--temp TEMP,   -t TEMP     (temperature. default: $(printr "$(get_parameter 'temperature')"))
	--min-p P,     -m P        (min-p. default: $(printr "$(get_parameter 'min_p')"))
	--top-p P,     -p P        (top-p. default: $(printr "$(get_parameter 'top_p')"))
	--top-k K,     -k K        (top-k. default: $(printr "$(get_parameter 'top_k')"))
	--stop "word", -s "word"   (stop word. default: none)
	--log logfile, -l logfile  (set file for logging. default: ~/.cache/last_response.txt)
	--verbose,     -v          (echo json payload before sending)
	--raw,         -r          (do not wrap prompt with prefix/suffix strings)
	--api-key,     -a          (override key used for llama.cpp API, usually not needed unless explicitly set)
	--help,        -h          (display this message)
EOF
}

format_prompt() {
	printr "$SYSTEM_PROMPT""${PREFIX}""$(cat)""$SUFFIX"
}
###

# parse arguments
for arg in "$@"; do
	shift
	case "$arg" in
		'--n-predict') set -- "$@" '-n' ;;
		'--temp')      set -- "$@" '-t' ;;
		'--min-p')     set -- "$@" '-m' ;;
		'--top-p')     set -- "$@" '-p' ;;
		'--top-k')     set -- "$@" '-k' ;;
		'--stop')      set -- "$@" '-s' ;;
		'--log')       set -- "$@" '-l' ;;
		'--verbose')   set -- "$@" '-v' ;;
		'--help')      set -- "$@" '-h' ;;
		'--raw')       set -- "$@" '-r' ;;
		'--api-key')   set -- "$@" '-a' ;;
		*)             set -- "$@" "$arg" ;;
	esac
done

OPTIND=1
while getopts "n:t:m:p:k:s:l:vhra:" opt
do
	case "$opt" in
		'n') parameters="$(printr "$parameters" |
			jq --arg value "$OPTARG" \
			'.n_predict=($value|tonumber)' \
			)" ;;
		't') parameters="$(printr "$parameters" |
			jq --arg value "$OPTARG" \
			'.temperature=($value|tonumber)'
			)" ;;
		'm') parameters="$(printr "$parameters" |
			jq --arg value "$OPTARG" \
			'.min_p=($value|tonumber)' \
			)" ;;
		'p') parameters="$(printr "$parameters" |
			jq --arg value "$OPTARG" \
			'.top_p=($value|tonumber)' \
			)" ;;
		'k') parameters="$(printr "$parameters" |
			jq --arg value "$OPTARG" \
			'.top_k=($value|tonumber)' \
			)" ;;
		's') parameters="$(printr "$parameters" |
			jq --arg value "$OPTARG" \
			'.stop=[$value]' \
			)" ;;
		'l') RESPONSE_LOG="$OPTARG" ;;
		'v') VERBOSE=1 ;;
		'h') print_usage; exit 0 ;;
		'r') PREFIX='' SUFFIX='' ;;
		'a') API_KEY="$OPTARG" ;;
		'?') print_usage; exit 1 ;;
	esac
done
shift "$((OPTIND - 1))"
###

# get prompts
if [ ! -t 0 ]; then
	user_input="$(cat)"
	[ -n "$1" ] && SYSTEM_PROMPT="$*"
elif [ -n "$1" ]; then
	user_input="$*"
else
	echo "Error: no input." >&2
	print_usage >&2
	return 1
fi
###

formatted_prompt="$(printr "$user_input" | format_prompt)"

parameters="$( \
	printr "$parameters" |
	jq --arg value "$formatted_prompt" '.prompt=$value' \
	)"

if [ "$VERBOSE" = "1" ]; then
	printr "$parameters" | jq >&2
fi

# request completion
test_connection

printr "$formatted_prompt" > "$RESPONSE_LOG"
printr "$parameters" |
	curl --url "$API_URL"'/completion' \
	-X POST \
	--silent \
	--no-buffer \
	--header 'Authorization: Bearer '"$API_KEY" \
	--data-binary @- |
	parse_event_stream | tee -a "$RESPONSE_LOG"
printf "\n"
###
