# LazyVim Notes profile

This is an isolated LazyVim profile for evaluating Obsidian-style Markdown
notes with AI support.
It does not replace the regular `~/.config/nvim` profile or the Org notes in
`~/notes/resources`.

## First run

The Guix Home profile provides the `zk` CLI and exports
`NOTES_VAULT_DIR=$HOME/notes/nvim-vault` (also as `ZK_NOTEBOOK_DIR` for the
optional CLI). `obsidian.nvim` creates the vault
directories on first launch. `zk init` is optional and only needed if you also
want to use the standalone `zk` CLI against this Markdown vault:

```sh
zk init "$ZK_NOTEBOOK_DIR"
```

Create the vault directory and open a Markdown note to start the separate
Neovim profile:

```sh
mkdir -p "$NOTES_VAULT_DIR"
NVIM_APPNAME=nvim-notes nvim "$NOTES_VAULT_DIR/welcome.md"
```

On first launch, `lazy.nvim` downloads LazyVim and its plugins. This requires
network access for Neovim. Avante's plugin build also runs `make`. Run `:Lazy`
to see plugin status and `:Lazy sync` to synchronize plugins after changing
their specifications.

## Notes keymaps

- `<leader>on`: create a note
- `<leader>oo`: browse notes
- `<leader>of`: search notes
- `<leader>ot`: browse tags
- `<leader>ob`: show backlinks
- `<leader>ol`: list links in the current note
- `<leader>od`: open today's daily note
- `<leader>or`: rename a note and update links
- `<leader>oi` in visual mode: link selected text to a note
- `<leader>oN` in visual mode: create a note from selected text
- `<leader>e`: toggle the file explorer
- `<leader>gg`: open Lazygit for the current Git repository
- `<leader>aa`: open/toggle the Avante AI sidebar
- `<leader>ae`: ask Avante to edit the current selection
- `<leader>an`: start a new AI chat

The vault remains ordinary Markdown, so Helix can continue to edit the same
files. Obsidian-style `[[wikilinks]]`, backlinks, tags, daily notes, link-aware
renaming, and template folders are configured. The existing local Ollama model
`gemma2:9b` is Avante's default provider. The AI chat and file context
stay local. In the Avante prompt, use `@file` to add a note such as an identity
guide to the context. Generated edits are not auto-applied and tool permissions
are not auto-approved. Use `#counterargument` in the Avante prompt for a
structured challenge to the selected passage. The local 9B model is convenient
and private, but less capable than a hosted frontier model.

The vault is not automatically initialized as a Git repository; run
`git init "$ZK_NOTEBOOK_DIR"` there if you want Lazygit version control.
