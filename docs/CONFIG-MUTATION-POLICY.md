# Config Mutation Policy

> Effective as of OpenClaw v2026.8.1 (OpenClaw 2.0 release cycle)

## What Changed & Why

### Removal of Direct Config Mutators
OpenClaw previously allowed agents to modify system settings by calling built-in config modification tool calls. These mutator tools were revoked to prevent agents from writing invalid keys directly into `openclaw.json`.

### Prevention of Cascade Gateway Crashes
Because OpenClaw enforces strict Zod schema validation upon startup and hot-reloading, an invalid key or structural mistake written to `openclaw.json` by an agent would trigger a fatal schema validation error, crashing the entire Gateway process and severing all messaging channels.

### Control-Plane Hardening
Config management was shifted strictly to host-level controls. Read-only schema inspections (such as `config.schema.lookup` or `config.get`) remain available to tools, but mutations require direct editing or local CLI diagnostics (`openclaw doctor --fix`).
