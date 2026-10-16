return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- TypeScript works out-of-the-box locally if Node is on the host
        vtsls = {},
      },
    },
  },
}
