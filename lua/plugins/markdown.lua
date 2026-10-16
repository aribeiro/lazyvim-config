-- LazyVim's markdown extra lints every Markdown file with markdownlint-cli2, and also runs it as a
-- --fix formatter on save whenever it reported something. Without a project config that means every
-- default rule (80-column lines, etc.), so only run it in projects that configure markdownlint.

local config_files = {
  ".markdownlint-cli2.jsonc",
  ".markdownlint-cli2.yaml",
  ".markdownlint-cli2.cjs",
  ".markdownlint-cli2.mjs",
  ".markdownlint.jsonc",
  ".markdownlint.json",
  ".markdownlint.yaml",
  ".markdownlint.yml",
  ".markdownlint.cjs",
  ".markdownlint.mjs",
}

local function has_config(path)
  return vim.fs.find(config_files, { path = path, upward = true })[1] ~= nil
end

return {
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters = {
        ["markdownlint-cli2"] = {
          condition = function(ctx)
            return has_config(ctx.dirname)
          end,
        },
      },
    },
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      local formatter = opts.formatters["markdownlint-cli2"]
      local condition = formatter.condition
      formatter.condition = function(self, ctx)
        return has_config(ctx.dirname) and condition(self, ctx)
      end
    end,
  },
}
