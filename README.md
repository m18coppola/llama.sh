# llama.sh
No-messing-around sh client for llama.cpp's server

![thanks bing!](https://raw.githubusercontent.com/m18coppola/llama.sh/main/assets/llama.sh_logo.jpeg)

_**NOTE:** Default config optimized for Mixtral-Instruct-8x7B_

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

llama.sh --help
```

## Demo (`python_chat.sh`)
![You should probably read the code before executing it...](https://raw.githubusercontent.com/m18coppola/llama.sh/main/assets/python_agent.gif)
