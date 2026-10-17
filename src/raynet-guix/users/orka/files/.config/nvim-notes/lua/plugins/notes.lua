return {
  {
    "obsidian-nvim/obsidian.nvim",
    version = "*", -- Follow releases; avoid unpinned main-branch changes.
    ft = "markdown",
    opts = function()
      local vault = vim.env.NOTES_VAULT_DIR
        or vim.env.ZK_NOTEBOOK_DIR
        or vim.fn.expand("~/notes/nvim-vault")
      return {
        legacy_commands = false,
        workspaces = {
          { name = "personal", path = vault },
        },
        daily_notes = {
          folder = "daily",
          date_format = "%Y-%m-%d",
        },
        templates = {
          folder = "templates",
          date_format = "%Y-%m-%d",
          time_format = "%H:%M",
        },
        picker = { name = "snacks.picker" },
      }
    end,
    keys = {
      { "<leader>on", "<cmd>Obsidian new<cr>", desc = "New note" },
      { "<leader>oo", "<cmd>Obsidian quick_switch<cr>", desc = "Browse notes" },
      { "<leader>of", "<cmd>Obsidian search<cr>", desc = "Search notes" },
      { "<leader>ot", "<cmd>Obsidian tags<cr>", desc = "Browse tags" },
      { "<leader>ob", "<cmd>Obsidian backlinks<cr>", desc = "Backlinks" },
      { "<leader>ol", "<cmd>Obsidian links<cr>", desc = "Links in this note" },
      { "<leader>od", "<cmd>Obsidian today<cr>", desc = "Today's note" },
      { "<leader>or", "<cmd>Obsidian rename<cr>", desc = "Rename note and update links" },
      { "<leader>oi", "<cmd>Obsidian link<cr>", mode = "x", desc = "Link selection to a note" },
      { "<leader>oN", "<cmd>Obsidian link_new<cr>", mode = "x", desc = "Create note from selection" },
    },
  },
}
