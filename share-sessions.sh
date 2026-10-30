#!/bin/bash
# 실제 구현은 스킬에 있다: ~/.claude/skills/share-sessions-across-accounts
exec /usr/bin/python3 "$HOME/.claude/skills/share-sessions-across-accounts/scripts/share_sessions.py" sync "$(cd "$(dirname "$0")" && pwd)"
