return {
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    version = false,
    build = "make",
    opts = {
      provider = "ollama",
      mode = "legacy", -- Suggest changes for review instead of running agent tools.
      selector = { provider = "snacks" },
      input = { provider = "snacks" },
      providers = {
        ollama = {
          endpoint = "http://127.0.0.1:11434",
          model = "gemma2:9b",
        },
      },
      behaviour = {
        auto_suggestions = false,
        auto_apply_diff_after_generation = false,
        auto_approve_tool_permissions = false,
      },
      shortcuts = {
        {
          name = "counterargument",
          description = "Find the strongest counterargument",
          details = "Challenge the selected idea using the current note and attached context.",
          prompt = table.concat({
            "Act as a thoughtful critic. Using the selected passage, the current note,",
            "and any attached @file context, state the strongest counterargument,",
            "identify assumptions it challenges, and suggest one question that would",
            "help me refine the idea. Do not rewrite my note unless I ask.",
          }, " "),
        },
      },
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      { "ColinKennedy/mega.cmdparse", dependencies = { "ColinKennedy/mega.logging" } },
      "saghen/blink.compat",
      "folke/snacks.nvim",
      {
        "HakonHarnes/img-clip.nvim",
        event = "VeryLazy",
        opts = {
          default = {
            embed_image_as_base64 = false,
            prompt_for_file_name = false,
            drag_and_drop = { insert_mode = true },
          },
        },
      },
      {
        "MeanderingProgrammer/render-markdown.nvim",
        opts = { file_types = { "markdown", "Avante" } },
        ft = { "markdown", "Avante" },
      },
    },
    keys = {
      { "<leader>aa", "<cmd>AvanteToggle<cr>", desc = "Toggle AI sidebar" },
      {
        "<leader>ae",
        "<cmd>AvanteEdit<cr>",
        mode = { "n", "x" },
        desc = "Ask AI to edit selection",
      },
      { "<leader>an", "<cmd>AvanteChatNew<cr>", desc = "Start new AI chat" },
    },
  },
  {
    "saghen/blink.cmp",
    optional = true,
    dependencies = { "saghen/blink.compat" },
    opts = function(_, opts)
      opts.sources = opts.sources or {}
      opts.sources.default = opts.sources.default or {}
      opts.sources.providers = opts.sources.providers or {}

      local avante_sources = {
        "avante_commands",
        "avante_mentions",
        "avante_shortcuts",
        "avante_files",
      }
      for _, source in ipairs(avante_sources) do
        table.insert(opts.sources.default, source)
        opts.sources.providers[source] = {
          name = source,
          module = "blink.compat.source",
          score_offset = 90,
          opts = {},
        }
      end
    end,
  },
}
