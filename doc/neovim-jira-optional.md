# Optional Jira interface for Neovim

The Jira plugin specification is kept in
`src/raynet-guix/users/orka/files/.config/nvim/lua/optional-plugins/jira.lua`.
It is outside Lazy's automatically imported `lua/plugins` directory, has no
key mappings, and is not installed on this machine.

To enable it on a machine that uses Jira, copy `jira.lua` into
`lua/plugins/jira.lua` in that machine's Neovim configuration, then run
`:Lazy sync`. The plugin exposes its `:Jira` commands; authentication can be
configured through the plugin's own Jira auth command.
