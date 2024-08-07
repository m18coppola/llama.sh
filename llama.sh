#!/bin/sh

# defaults
VERBOSE=0
API_URL='127.0.0.1:8080'
API_KEY='none'
RESPONSE_LOG="$HOME"'/.cache/last_response.txt'
SYSTEM_PROMPT_PREFIX="<|start_header_id|>system<|end_header_id|>\n\n"
SYSTEM_PROMPT='You are Llama-3.1, a helpful AI assistant.'
PREFIX='<|eot_id|><|start_header_id|>user<|end_header_id|>\n\n'
SUFFIX='<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n'
parameters="$(jq -nR '{
	prompt: "",
	temperature: 0.6,
	top_k: 45,
	top_p: 0.95,
	min_p: 0.05,
	repeat_penalty: 1.0,
	repeat_last_n: 0,
	penalize_nl: false,
	n_predict: -1,
	stream: true,
	cache_prompt: true,
}')"
###

# functions
parse_event() {
	event_json="$(printf "%s" "$*" | cut -c6-)"
	if [ "$(printf "%s" "$event_json" | jq '.stop')" != "true" ]; then
		printf "%s" "$event_json" |
			jq '.content' |
			sed 's/^"\|"$//g;s/\\"/"/g'
	elif [ "$(printf "%s" "$event_json" | jq '.stopped_word')" = "true" ]; then
		printf "%s" "$event_json" |
			jq '.stopping_word // ""' |
			sed 's/^"\|"$//g;s/\\"/"/g'
	fi
}

parse_event_stream() {
	while IFS= read -r LINE; do
		printf "%s" "$LINE" | grep -q "data:*" &&
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
			--data '{"prompt":"", "n_predict":0}' | jq -r '.error.message')"
	if [ "$STATUS" = "Invalid API Key" ]; then
		echo 'API key is not authorized.'
		exit 1
	fi
}

get_parameter() {
	param=".${1}"
	printf "%s" "$parameters" | jq "$param"
}

print_usage() {
	cat << EOF
Usage:
	$(basename "$0") [--options] "prompt"
	echo "prompt" | $(basename "$0") [--options]
	echo "prompt" | $(basename "$0") [--options] "system prompt"
Flags:
	--n-predict N, -n N        (number of tokens to generate, -1 for inf. default: $(printf "%s" "$(get_parameter 'n_predict')"))
	--temp TEMP,   -t TEMP     (temperature. default: $(printf "%s" "$(get_parameter 'temperature')"))
	--min-p P,     -m P        (min-p. default: $(printf "%s" "$(get_parameter 'min_p')"))
	--top-p P,     -p P        (top-p. default: $(printf "%s" "$(get_parameter 'top_p')"))
	--top-k K,     -k K        (top-k. default: $(printf "%s" "$(get_parameter 'top_k')"))
	--stop "word", -s "word"   (stop word. default: none)
	--log logfile, -l logfile  (set file for logging. default: ~/.cache/last_response.txt)
	--verbose,     -v          (echo json payload before sending)
	--raw,         -r          (do not wrap prompt with prefix/suffix strings)
	--api-key,     -a          (override key used for llama.cpp API, usually not needed unless explicitly set)
	--api-url,     -u          (override url used for llama.cpp API)
	--help,        -h          (display this message)
Environment Variables:
	LSH_SYSTEM_PROMPT_PREFIX   (string prefixed to system prompt input)
	LSH_PREFIX                 (string prefixed to user prompt input)
	LSH_SUFFIX                 (string appended to user prompt input)
EOF
}

format_prompt() {
	printf "%b" "$SYSTEM_PROMPT_PREFIX""$SYSTEM_PROMPT""${PREFIX}""$(cat)""$SUFFIX""x"
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
		'--api-url')   set -- "$@" '-u' ;;
		*)             set -- "$@" "$arg" ;;
	esac
done

OPTIND=1
while getopts "n:t:m:p:k:s:l:vhra:u:" opt
do
	case "$opt" in
		'n') parameters="$(printf "%s" "$parameters" |
			jq --arg value "$OPTARG" \
			'.n_predict=($value|tonumber)' \
			)" ;;
		't') parameters="$(printf "%s" "$parameters" |
			jq --arg value "$OPTARG" \
			'.temperature=($value|tonumber)'
			)" ;;
		'm') parameters="$(printf "%s" "$parameters" |
			jq --arg value "$OPTARG" \
			'.min_p=($value|tonumber)' \
			)" ;;
		'p') parameters="$(printf "%s" "$parameters" |
			jq --arg value "$OPTARG" \
			'.top_p=($value|tonumber)' \
			)" ;;
		'k') parameters="$(printf "%s" "$parameters" |
			jq --arg value "$OPTARG" \
			'.top_k=($value|tonumber)' \
			)" ;;
		's') parameters="$(printf "%s" "$parameters" |
			jq --arg value "$OPTARG" \
			'.stop=[$value]' \
			)" ;;
		'l') RESPONSE_LOG="$OPTARG" ;;
		'v') VERBOSE=1 ;;
		'h') print_usage; exit 0 ;;
		'r') PREFIX='' SUFFIX='' ;;
		'a') API_KEY="$OPTARG" ;;
		'u') API_URL="$OPTARG" ;;
		'?') print_usage; exit 1 ;;
	esac
done
shift "$((OPTIND - 1))"
###

# get env vars
if [ "${LSH_SYSTEM_PROMPT_PREFIX+set}" = set ]; then
	SYSTEM_PROMPT_PREFIX="$LSH_SYSTEM_PROMPT_PREFIX"
fi
if [ "${LSH_PREFIX+set}" = set ]; then
	PREFIX="$LSH_PREFIX"
fi
if [ "${LSH_SUFFIX+set}" = set ]; then
	PREFIX="$LSH_SUFFIX"
fi

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

formatted_prompt="$(printf "%s" "$user_input" | format_prompt)"

parameters="$( \
	printf "%s" "$parameters" |
	jq --arg value "${formatted_prompt%?}" '.prompt=$value' \
	)"

if [ "$VERBOSE" = "1" ]; then
	printf "%s" "$parameters" | jq >&2
fi

# request completion
test_connection

printf "%s" "${formatted_prompt%?}" > "$RESPONSE_LOG"
printf "%s" "$parameters" |
	curl --url "$API_URL"'/completion' \
	-X POST \
	--silent \
	--no-buffer \
	--header 'Authorization: Bearer '"$API_KEY" \
	--data-binary @- |
	parse_event_stream | tee -a "$RESPONSE_LOG"
printf "\n"
###
