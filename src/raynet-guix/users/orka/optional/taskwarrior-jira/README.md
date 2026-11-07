# Optional: Jira -> Taskwarrior (Bugwarrior)

Disabled on this machine; kept for machines that use Jira. Workflow docs:
`taskwarrior-workflow.md` (written for the systemd setup; here mcron replaces timers).

To enable:
1. `cp bugwarrior ~/.local/bin/` (or into `files/.local/bin/`); it reads Jira
   credentials from `~/.env` and the Jira URL is hardcoded for the LGE Jira.
2. Copy `shortcut-scripts/*.sh` to `~/.config/taskwarrior-tui/shortcut-scripts/`
   (`files/.config/taskwarrior-tui/shortcut-scripts/`).
3. Install bugwarrior into `~/.local/share/bugwarrior-venv`:
   `python3 -m venv ~/.local/share/bugwarrior-venv &&
   ~/.local/share/bugwarrior-venv/bin/pip install 'bugwarrior[jira]'`
4. Uncomment the Jira block in `guix-managed/task/taskrc`.
5. Uncomment the bugwarrior job in `files/.config/cron/taskwarrior.guile`.
