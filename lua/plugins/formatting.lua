-- Format on save only with the project's own settings, never with a tool's defaults.
--
-- Ruby: format through the RuboCop LSP (see lsp.lua), which runs with the project's
-- gems and .rubocop.yml. LazyVim's default runs Mason's RuboCop on the host instead, which doesn't
-- have the project's gems (e.g. the rubocop-rails-omakase config it inherits).
--
-- Prettier filetypes: Prettier only runs when the project has a Prettier config
-- (vim.g.lazyvim_prettier_needs_config). Without one, don't fall back to the language server's
-- formatter either (vtsls, jsonls...), since that is its own built-in style, not the project's.
return {
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      opts.formatters_by_ft.ruby = {}
      opts.formatters_by_ft.eruby = { lsp_format = "never" } -- erb-formatter has no project config
      for _, formatters in pairs(opts.formatters_by_ft) do
        if type(formatters) == "table" and vim.tbl_contains(formatters, "prettier") then
          formatters.lsp_format = "never"
        end
      end
    end,
  },
}
