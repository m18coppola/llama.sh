# llama.sh
No-messing-around sh client for llama.cpp's server

<img src="https://raw.githubusercontent.com/m18coppola/llama.sh/main/assets/llama.sh_logo.jpeg" width="50%" />

_**NOTE:** Default config optimized for Llama-3.1_

## Depends on
* sh
* curl
* jq

## Setup
Add these scripts to your `$PATH`. Configuration is done by editing the top of the `llama.sh` file.

Not sure how to set up llama.cpp? Check out Mozilla's [llamafile](https://github.com/Mozilla-Ocho/llamafile)!

## Usage
```
        llama.sh [--options] "prompt"
        echo "prompt" | llama.sh [--options]
        echo "prompt" | llama.sh [--options] "system prompt"
Flags:
        --n-predict N, -n N        (number of tokens to generate, -1 for inf. default: -1)
        --temp TEMP,   -t TEMP     (temperature. default: 0.6)
        --min-p P,     -m P        (min-p. default: 0.05)
        --top-p P,     -p P        (top-p. default: 0.95)
        --top-k K,     -k K        (top-k. default: 45)
        --stop "word", -s "word"   (stop word. default: none)
        --log logfile, -l logfile  (set file for logging. default: ~/.cache/last_response.txt)
        --verbose,     -v          (echo json payload before sending)
        --raw,         -r          (do not wrap prompt with prefix/suffix strings)
        --api-key,     -a          (override key used for llama.cpp API, usually not needed unless explicitly set)
        --help,        -h          (display this message)
Environment Variables:
        LSH_SYSTEM_PROMPT_PREFIX   (string prefixed to system prompt input)
        LSH_PREFIX                 (string prefixed to user prompt input)
        LSH_SUFFIX                 (string appended to user prompt input)
```

## Demo (`python_chat.sh`)
![You should probably read the code before executing it...](https://raw.githubusercontent.com/m18coppola/llama.sh/main/assets/python_agent.gif)
