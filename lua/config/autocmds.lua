-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Don't format YAML on save: yamlls rewrites the whole file (re-indents to 2 spaces, collapses
-- spacing). Format on demand with <leader>cf.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("yaml_no_autoformat", { clear = true }),
  pattern = { "yaml", "yaml.*" },
  callback = function()
    vim.b.autoformat = false
  end,
})
