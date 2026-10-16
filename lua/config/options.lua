-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Copilot (copilot-language-server and the Copilot CLI) needs Node >= 22, but the global asdf
-- Node is 20. Put Node 22 first on PATH for Neovim and every process it starts.
local node22 = vim.fn.expand("~/.asdf/installs/nodejs/22.18.0/bin")
if vim.fn.isdirectory(node22) == 1 then
  vim.env.PATH = node22 .. ":" .. vim.env.PATH
end

-- Only format with Prettier when the project has a Prettier config (formatting.prettier extra).
vim.g.lazyvim_prettier_needs_config = true
