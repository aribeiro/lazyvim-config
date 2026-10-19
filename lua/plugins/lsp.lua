-- LSP setup that works in any project, Dockerized or not.
--
-- In a Dockerized project (e.g. Rails + TypeScript), the app runs in Docker but its source is
-- bind-mounted (./api -> /app/api, ./web -> /app/web). Navigation servers (ruby_lsp, vtsls,
-- tailwindcss) run on the HOST so the file paths they return are the same paths Neovim has open.
-- Running them inside the container returns /app/... paths that don't exist on the host, which
-- breaks go-to-definition/references.
--
-- Only RuboCop runs in the container, because it needs the project's exact gems and config. Its
-- diagnostics are reported against the URIs Neovim sent, so responses need no path translation,
-- but RuboCop looks for .rubocop.yml next to those host paths, which don't exist in the container,
-- and silently falls back to its default config. in_compose_service() fixes that with symlinks.
--
-- Without Docker, both Ruby servers run on the host with the project's own bundle.

-- Returns the name and config of the Docker Compose service that bind-mounts `root` (e.g. "api" for
-- <project>/api), or nil when `root` isn't part of a Compose project. When several services mount
-- it, the one with the most specific mount wins (ties go to the first name alphabetically).
local function compose_service(root)
  if vim.fn.executable("docker") == 0 then
    return nil
  end
  local out = vim.system({ "docker", "compose", "config", "--format", "json" }, { cwd = root, text = true }):wait()
  if out.code ~= 0 then
    return nil
  end
  local ok, compose = pcall(vim.json.decode, out.stdout)
  if not ok or not compose.services then
    return nil
  end
  local names = vim.tbl_keys(compose.services)
  table.sort(names)
  local best, best_len
  for _, name in ipairs(names) do
    for _, v in ipairs(compose.services[name].volumes or {}) do
      if v.type == "bind" and vim.fs.relpath(v.source, root) and #v.source > (best_len or -1) then
        best, best_len = name, #v.source
      end
    end
  end
  return best, best and compose.services[best]
end

-- Starts `cmd` in a compose service, after symlinking the host path of each of the service's bind
-- mounts to its mount point inside the container (e.g. /Users/me/prj/api -> /app/api), so the host
-- paths Neovim sends resolve there, along with any config files next to them.
local function in_compose_service(name, service, cmd, dispatchers, cwd)
  local links = {}
  for _, v in ipairs(service.volumes or {}) do
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
  local exec = "docker compose exec -T "
  local script = ("%s-u 0 %s sh -c %s && exec %s%s %s"):format(
    exec,
    vim.fn.shellescape(name),
    vim.fn.shellescape(#links > 0 and table.concat(links, "; ") or "true"),
    exec,
    vim.fn.shellescape(name),
    table.concat(vim.tbl_map(vim.fn.shellescape, cmd), " ")
  )
  return vim.lsp.rpc.start({ "sh", "-c", script }, dispatchers, { cwd = cwd })
end

-- Whether the project's Gemfile.lock at `root` includes `gem`.
local function bundle_includes(root, gem)
  local f = io.open(root .. "/Gemfile.lock")
  if not f then
    return false
  end
  local lock = f:read("*a")
  f:close()
  return lock:find("\n    " .. vim.pesc(gem) .. " %(") ~= nil
end

-- Whether the project's gems are installed on the host.
local function bundle_installed(root)
  return vim.fn.executable("bundle") == 1 and vim.system({ "bundle", "check" }, { cwd = root }):wait().code == 0
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

        -- ruby-lsp on the host. When the project's gems are installed on the host, it uses the
        -- project's bundle, so go-to-definition also jumps into gem sources (ActiveRecord, etc.).
        -- Otherwise (e.g. the gems only exist in Docker) it runs from the standalone bundle in
        -- ruby-lsp/Gemfile, which still indexes the project's own code (app/, lib/, spec/...).
        ruby_lsp = {
          mason = false,
          cmd = function(dispatchers, config)
            local cwd = config.cmd_cwd or config.root_dir
            if cwd and bundle_installed(cwd) then
              return vim.lsp.rpc.start({ "ruby-lsp" }, dispatchers, { cwd = cwd })
            end
            return vim.lsp.rpc.start({ "bundle", "exec", "ruby-lsp" }, dispatchers, {
              cwd = cwd,
              env = { BUNDLE_GEMFILE = vim.fn.stdpath("config") .. "/ruby-lsp/Gemfile" },
            })
          end,
          init_options = { formatter = "none", linters = {} }, -- RuboCop LSP below handles both
        },

        -- RuboCop with the project's own version and config, so it only starts in projects whose
        -- bundle includes it. In a Compose project it runs in the service that mounts the code
        -- (needs `docker compose up`); otherwise on the host with `bundle exec`.
        rubocop = {
          mason = false,
          root_dir = function(bufnr, on_dir)
            local root = vim.fs.root(bufnr, "Gemfile")
            if root and bundle_includes(root, "rubocop") then
              on_dir(root)
            end
          end,
          cmd = function(dispatchers, config)
            local cmd = { "bundle", "exec", "rubocop", "--lsp" }
            local name, service = compose_service(config.root_dir)
            if name then
              return in_compose_service(name, service, cmd, dispatchers, config.root_dir)
            end
            return vim.lsp.rpc.start(cmd, dispatchers, { cwd = config.root_dir })
          end,
        },

        -- TypeScript / Tailwind: host servers from Mason, using LazyVim's defaults (settings in
        -- ide_custom.lua). They resolve library types from the project's node_modules on the host;
        -- in Docker that path is often a named volume, so run `npm install` on the host once.
        vtsls = {},
        tailwindcss = {},

        -- oxlint: only starts in projects with an oxlint config, using the project's own binary
        -- from node_modules/.bin (so the same npm install on the host is needed).
        oxlint = { mason = false },
      },
    },
  },
}
