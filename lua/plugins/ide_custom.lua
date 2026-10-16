return {
  -- 1. Optimize TypeScript Settings to mimic VS Code
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        vtsls = {
          settings = {
            typescript = {
              updateImportsOnFileMove = { enabled = "always" },
              suggest = { completeFunctionCalls = true },
              inlayHints = {
                parameterNames = { enabled = "all" },
                parameterTypes = { enabled = true },
              },
            },
          },
        },
      },
    },
  },

  -- 2. Enhance Rails & Ruby development
  {
    "tpope/vim-rails",
    lazy = false, -- Load immediately for Rails project structures (:Rextract, :A, etc.)
  },

  -- 3. Set up Avante (The AI agent panel)
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    opts = {
      provider = "copilot", -- Leverage your active Copilot subscription as the backend agent
      auto_suggestions_provider = "copilot",
    },
  },
}
