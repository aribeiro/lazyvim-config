-- LSP setup for Dockerized Rails + TypeScript projects.
--
-- The app runs in Docker, but its source is bind-mounted (./api -> /app/api, ./web -> /app/web).
-- Navigation servers (ruby_lsp, vtsls, tailwindcss) run on the HOST so the file paths they return
-- are the same paths Neovim has open. Running them inside the container returns /app/... paths that
-- don't exist on the host, which breaks go-to-definition/references.
--
-- Only RuboCop runs in the container, because it needs the project's exact gems and config. Its
-- diagnostics are reported against the URIs Neovim sent, so responses need no path translation,
-- but RuboCop looks for .rubocop.yml next to those host paths, which don't exist in the container,
-- and silently falls back to its default config. in_compose_service() fixes that with symlinks.

-- Returns an LSP `cmd` that runs `cmd` in a compose service, after symlinking the host path of each
-- of the service's bind mounts to its mount point inside the container (e.g. /Users/me/prj/api ->
-- /app/api), so the host paths Neovim sends resolve there, along with any config files next to them.
local function in_compose_service(service, cmd)
  return function(dispatchers, config)
    local cwd = config.root_dir
    local links = {}
    local out = vim.system({ "docker", "compose", "config", "--format", "json" }, { cwd = cwd, text = true }):wait()
    if out.code == 0 then
      local ok, compose = pcall(vim.json.decode, out.stdout)
      local volumes = ok and compose.services and compose.services[service] and compose.services[service].volumes
      for _, v in ipairs(volumes or {}) do
        if v.type == "bind" then
          local src, dst = vim.fn.shellescape(v.source), vim.fn.shellescape(v.target)
          -- Skip paths that already resolve: linking over one could replace a bind-mounted host file.
          links[#links + 1] = ("[ -e %s ] || { mkdir -p %s && ln -s %s %s; }"):format(
            src,
            vim.fn.shellescape(vim.fs.dirname(v.source)),
            dst,
            src
          )
        end
      end
    end
    local exec = "docker compose exec -T "
    local script = ("%s-u 0 %s sh -c %s && exec %s%s %s"):format(
      exec,
      vim.fn.shellescape(service),
      vim.fn.shellescape(#links > 0 and table.concat(links, "; ") or "true"),
      exec,
      vim.fn.shellescape(service),
      table.concat(vim.tbl_map(vim.fn.shellescape, cmd), " ")
    )
    return vim.lsp.rpc.start({ "sh", "-c", script }, dispatchers, { cwd = cwd })
  end
end

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
        -- compose.yaml from the server's root dir (api/, where the Gemfile is) upward.
        rubocop = {
          mason = false,
          cmd = in_compose_service("api", { "bundle", "exec", "rubocop", "--lsp" }),
        },

        -- TypeScript / Tailwind: host servers from Mason, using LazyVim's defaults (settings in
        -- ide_custom.lua). They resolve library types from <project>/web/node_modules on the host;
        -- in Docker that path is a named volume, so run `npm install` in web/ on the host once.
        vtsls = {},
        tailwindcss = {},

        -- oxlint: only starts in projects with an oxlint config, using the project's own binary
        -- from node_modules/.bin (so the same npm install on the host is needed).
        oxlint = { mason = false },
      },
    },
  },
}
