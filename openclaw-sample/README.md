# OpenClaw Life - Sample OpenClaw Instance Template

## Overview

This template runs OpenClaw in a docker container.

## Quality of Life

Create the following shell alias:
```
alias openclaw='docker compose exec openclaw'
```
Then, when you `cd` into one of these openclaw-*name* directories, you can issue `openclaw` commands almost like if you were running OpenClaw on "bare metal" directly on your host (or VM).

```
openclaw status
```