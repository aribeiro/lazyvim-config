-- Format on save only with the project's own settings, never with a tool's defaults.
--
-- Ruby: format through the RuboCop LSP (in the container, see lsp.lua), which has the project's
-- gems and .rubocop.yml. LazyVim's default runs Mason's RuboCop on the host instead, which doesn't
-- have the project's gems (e.g. the rubocop-rails-omakase config it inherits).
return {
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      opts.formatters_by_ft.ruby = {}
      opts.formatters_by_ft.eruby = { lsp_format = "never" } -- erb-formatter has no project config
    end,
  },
}
