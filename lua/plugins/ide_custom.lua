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
}
