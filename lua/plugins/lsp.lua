-- LSP setup for Dockerized Rails + TypeScript projects.
--
-- The app runs in Docker, but its source is bind-mounted (./api -> /app/api, ./web -> /app/web).
-- Navigation servers (ruby_lsp, vtsls, tailwindcss) run on the HOST so the file paths they return
-- are the same paths Neovim has open. Running them inside the container returns /app/... paths that
-- don't exist on the host, which breaks go-to-definition/references.
--
-- Only RuboCop runs in the container, because it needs the project's exact gems and config, and
-- its diagnostics are reported against the URIs Neovim sent, so no path translation is needed.

-- ruby-lsp doesn't implement textDocument/implementation, and its typeHierarchy/subtypes is a stub
-- that always returns nothing. This grep fills the gap:
--   on a constant -> subclasses and include/extend/prepend sites
--   on a method   -> every `def name` / `def self.name`, i.e. the classes that implement it
local function ruby_implementations()
  local word = vim.fn.expand("<cword>")
  if word == "" then
    return
  end
  local search
  if word:match("^%u") then
    search = ([[class\s+[\w:]+\s*<\s*([\w:]*::)?%s\b|(include|extend|prepend)\s+([\w:]*::)?%s\b]]):format(word, word)
  else
    search = ([[def\s+(self\.)?%s\b]]):format(word)
  end
  Snacks.picker.grep({
    title = "Implementations of " .. word,
    search = search,
    regex = true,
    live = false,
    ft = "ruby",
    cwd = LazyVim.root(),
  })
end

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        ["*"] = {
          keys = {
            {
              "gI",
              function()
                if vim.bo.filetype == "ruby" then
                  ruby_implementations()
                else
                  Snacks.picker.lsp_implementations()
                end
              end,
              desc = "Goto Implementation",
            },
          },
        },

        -- Rails: host ruby-lsp from the standalone bundle in ruby-lsp/Gemfile, so the project's gems
        -- (which only exist inside the container) don't need to be installed locally. It indexes the
        -- project's own code, so definition/references work across app/, lib/, spec/...; jumping
        -- into gem sources (ActiveRecord, etc.) doesn't, because those files aren't on the host.
        ruby_lsp = {
          mason = false,
          cmd = { "bundle", "exec", "ruby-lsp" },
          cmd_env = { BUNDLE_GEMFILE = vim.fn.stdpath("config") .. "/ruby-lsp/Gemfile" },
          init_options = { formatter = "none", linters = {} }, -- RuboCop LSP below handles both
        },

        -- RuboCop in the api container (needs `docker compose up`). `docker compose` finds
        -- compose.yaml from Neovim's cwd upward, so open Neovim inside the project.
        rubocop = {
          mason = false,
          cmd = { "docker", "compose", "exec", "-T", "api", "bundle", "exec", "rubocop", "--lsp" },
        },

        -- TypeScript / Tailwind: host servers from Mason, using LazyVim's defaults (settings in
        -- ide_custom.lua). They resolve library types from <project>/web/node_modules on the host;
        -- in Docker that path is a named volume, so run `npm install` in web/ on the host once.
        vtsls = {},
        tailwindcss = {},
      },
    },
  },
}
