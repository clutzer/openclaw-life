# workspace/
#
# This directory is mounted into the container at:
#   /home/node/.openclaw/workspace
#
# It is fully git-tracked and serves as the primary backup mechanism for
# everything you'd want to preserve about this OpenClaw instance.
#
# Key files/directories that will appear here over time:
#
#   USER.md       — persistent facts about you the assistant should know
#   IDENTITY.md   — the assistant's name, persona, and behaviour directives
#   SOUL.md       — deeper character and value guidance
#   AGENTS.md     — agent-level tool and behaviour configuration
#   TOOLS.md      — tool configuration injected into the agent prompt
#   memories/     — long-term memory files written by the assistant
#   skills/       — installed workspace skills (each in skills/<skill>/SKILL.md)
#
# To populate these files, either let OpenClaw create them on first run, or
# run openclaw onboard / copy from another instance.
#
# Commit regularly to checkpoint state:
#   git add -A && git commit -m "checkpoint: $(date -u +%Y-%m-%d)"
#   git push
