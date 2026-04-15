# OpenClaw Life - Sample OpenClaw Instance Template

## Overview

This template runs OpenClaw in a docker container.

## Quality of Life

Create the following shell alias:
```
alias openclaw='docker compose exec openclaw openclaw'
```
Then, when you `cd` into one of these openclaw-*name* directories, you can issue `openclaw` commands almost like if you were running OpenClaw on "bare metal" directly on your host (or VM).

Note: the above command has a lot of *openclaw* in it... the container name *openclaw* and then the command *openclaw* in the *openclaw* container...
```
openclaw status
```

## Memory

TODO:
```
openclaw config set agents.defaults.memorySearch.provider openai
openclaw config set agents.defaults.memorySearch.model qwen3-embedding-8b
openclaw config set agents.defaults.memorySearch.remote.baseUrl "http://10.0.0.2:8080/v1/embed"
openclaw config set agents.defaults.memorySearch.remote.apiKey "YOUR_API_KEY_IF_NEEDED"
openclaw config set agents.defaults.memorySearch.enabled true
openclaw memory index --force --all
openclaw memory index --force
```