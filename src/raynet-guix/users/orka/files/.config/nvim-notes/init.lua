-- Isolated LazyVim profile for Markdown notes.
vim.env.NOTES_VAULT_DIR = vim.env.NOTES_VAULT_DIR or vim.env.ZK_NOTEBOOK_DIR or vim.fn.expand("~/notes/nvim-vault")
require("config.lazy")
