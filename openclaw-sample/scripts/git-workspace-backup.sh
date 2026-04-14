#!/bin/bash
#
# Backup script for OpenClaw workspace
#
# Commits all changes in ./workspace with a timestamped message
#
# Usage:
#   ./git-workspace-backup.sh 
#
# Example Cron entry (runs every night at 3:30am):
# 30 3 * * * cd ~/openclaw-life/openclaw-luna/workspace && ../scripts/git-workspace-backup.sh
#
set -e

# Check if inside a git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not a git repository: $(pwd)"
  exit 1
fi

git add --all
if git diff --cached --quiet; then
  echo "No changes to commit."
  exit 0
fi

git commit -m "Workspace backup: $(date -u +'%Y-%m-%d %H:%M UTC')"
git push
