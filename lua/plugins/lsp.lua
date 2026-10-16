-- return {
--   {
--     "neovim/nvim-lspconfig",
--     opts = function(_, opts)
--       opts.servers = opts.servers or {}
--
--       opts.servers.vtsls = {
--         -- Força o LSP a procurar o tsconfig.json mais próximo do arquivo aberto
--         root_dir = function(fname)
--           local util = require("lspconfig.util")
--           return util.root_pattern("tsconfig.json", "jsconfig.json", "package.json")(fname)
--         end,
--         settings = {
--           typescript = {
--             -- Habilita suporte completo para caminhos customizados (aliases) como 'core/utils'
--             path = {
--               mode = "auto",
--             },
--             preferences = {
--               importModuleSpecifierPreference = "project-relative",
--             },
--             updateImportsOnFileMove = { enabled = "always" },
--             suggest = { completeFunctionCalls = true },
--           },
--         },
--       }
--
--       -- Mantém a sua configuração do Ruby Rails via Docker abaixo
--       opts.servers.ruby_lsp = {
--         cmd = { "docker-compose", "exec", "-T", "api", "bundle", "exec", "ruby-lsp" },
--         root_dir = function(fname)
--           local util = require("lspconfig.util")
--           return util.root_pattern("Gemfile")(fname)
--         end,
--       }
--     end,
--   },
-- }
-- return {
--   {
--     "neovim/nvim-lspconfig",
--     opts = {
--       servers = {
--         -- -- 1. Rails LSP (api container)
--         -- ruby_lsp = {
--         --   cmd = { "docker", "compose", "exec", "-T", "api", "bundle", "exec", "ruby-lsp" },
--         -- },
--         -- Rails LSP (Main execution)
--         ruby_lsp = {
--           cmd = { "docker", "compose", "exec", "-T", "api", "bundle", "exec", "ruby-lsp" },
--           -- FORCE RUBY_LSP TO DISABLE ITS OWN LINTER AND FORMATTER
--           init_options = {
--             enabledFeatures = {
--               "documentSymbols",
--               "documentLink",
--               "hover",
--               "foldingRange",
--               "selectionRanges",
--               "semanticHighlighting",
--               "formatting", -- Set to false if you want RuboCop to handle formatting completely
--               "definition",
--               "references",
--               "completion",
--             },
--           },
--           settings = {
--             -- Extra safety to ensure it doesn't spin up an internal diagnostics engine
--             formatter = "none",
--             linter = "none",
--           },
--         },
--         -- RuboCop Linter Engine via Docker (The source of truth)
--         rubocop = {
--           cmd = {
--             "docker",
--             "compose",
--             "exec",
--             "-T",
--             "api",
--             "bundle",
--             "exec",
--             "rubocop",
--             "--lsp",
--             "--config",
--             ".rubocop.yml",
--           },
--         },
--         -- 2. TypeScript / React LSP (web or ops container)
--         vtsls = {
--           cmd = function(client_start_info)
--             local root_dir = client_start_info.root_dir or ""
--             local container = string.find(root_dir, "/ops") and "ops" or "web"
--             return { "docker", "compose", "exec", "-T", container, "npx", "vtsls", "--stdio" }
--           end,
--           settings = {
--             typescript = {
--               tsserver = {
--                 -- Ensures TS looks for your tsconfig.json to resolve 'core/*' and '@safx/*' paths
--                 useSyntaxServer = "atps",
--               },
--             },
--           },
--         },
--
--         -- 3. Tailwind CSS LSP (web or ops container)
--         tailwindcss = {
--           cmd = function(client_start_info)
--             local root_dir = client_start_info.root_dir or ""
--             local container = string.find(root_dir, "/ops") and "ops" or "web"
--             return { "docker", "compose", "exec", "-T", container, "npx", "@tailwindcss/language-server", "--stdio" }
--           end,
--         },
--       },
--     },
--   },
-- }
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- 1. Rails LSP
        -- Runs on the host (not in Docker) so the server sees the same file paths as Neovim and can
        -- index the whole project. Uses the standalone bundle in ruby-lsp/Gemfile, so the project's
        -- gems (which only exist inside the container) don't need to be installed locally.
        ruby_lsp = {
          mason = false,
          cmd = { "bundle", "exec", "ruby-lsp" },
          cmd_env = { BUNDLE_GEMFILE = vim.fn.stdpath("config") .. "/ruby-lsp/Gemfile" },
          init_options = { formatter = "none", linters = {} }, -- RuboCop LSP below handles both
        },

        -- 2. TypeScript / React LSP (web/ops)
        -- vtsls = {
        --   cmd = { "docker", "compose", "exec", "-T", "web", "npx", "vtsls", "--stdio" },
        --   on_new_config = function(new_config, new_root_dir)
        --     local container = string.find(new_root_dir or "", "/ops") and "ops" or "web"
        --     new_config.cmd = { "docker", "compose", "exec", "-T", container, "npx", "vtsls", "--stdio" }
        --
        --     -- Tradutor de caminhos para o TypeScript
        --     new_config.on_init = function(client)
        --       local local_root = client.config.root_dir
        --       -- Altere "/app" se o WORKDIR dos seus containers React for diferente
        --       local remote_root = "/frontend"
        --
        --       client.handlers["textDocument/definition"] = function(err, result, ctx, config)
        --         if result then
        --           if type(result) == "table" and result.uri then
        --             result.uri = result.uri:gsub(remote_root, local_root)
        --           elseif type(result) == "table" then
        --             for _, loc in ipairs(result) do
        --               if loc.uri then
        --                 loc.uri = loc.uri:gsub(remote_root, local_root)
        --               end
        --               if loc.targetUri then
        --                 loc.targetUri = loc.targetUri:gsub(remote_root, local_root)
        --               end
        --             end
        --           end
        --         end
        --         vim.lsp.handlers["textDocument/definition"](err, result, ctx, config)
        --       end
        --     end
        --   end,
        --   settings = {
        --     typescript = { tsserver = { useSyntaxServer = "atps" } },
        --   },
        -- },

        -- TypeScript / React LSP Ajustado para a sua estrutura
        vtsls = {
          -- Força o LazyVim a reconhecer a subpasta com o tsconfig como a raiz do LSP atual
          root_dir = function(filename)
            local util = require("lspconfig.util")
            return util.root_pattern("tsconfig.json", "package.json")(filename)
          end,

          cmd = { "docker", "compose", "exec", "-T", "web", "npx", "vtsls", "--stdio" },

          on_new_config = function(new_config, new_root_dir)
            -- Identifica dinamicamente qual container usar com base na pasta
            local container = string.find(new_root_dir or "", "/ops") and "ops" or "web"
            new_config.cmd = { "docker", "compose", "exec", "-T", container, "npx", "vtsls", "--stdio" }

            new_config.on_init = function(client)
              -- local_root será algo como: /Users/voce/projeto/frontend/web
              local local_root = client.config.root_dir
              -- remote_root DEVE ser o WORKDIR exato do container (onde o tsconfig.json fica na raiz do container)
              local remote_root = "/frontend"

              -- 1. TRADUÇÃO DE IDA (Neovim -> Docker)
              local old_request = client.request
              client.request = function(method, params, callback, request_bufnr)
                if params and params.textDocument and params.textDocument.uri then
                  params.textDocument.uri = params.textDocument.uri:gsub(local_root, remote_root)
                end
                if params and params.textDocuments then
                  for _, doc in ipairs(params.textDocuments) do
                    if doc.uri then
                      doc.uri = doc.uri:gsub(local_root, remote_root)
                    end
                  end
                end
                return old_request(method, params, callback, request_bufnr)
              end

              -- 2. TRADUÇÃO DE VOLTA (Docker -> Neovim - CORRIGE O 'gd')
              client.handlers["textDocument/definition"] = function(err, result, ctx, config)
                if result then
                  if type(result) == "table" and result.uri then
                    result.uri = result.uri:gsub(remote_root, local_root)
                  elseif type(result) == "table" then
                    for _, loc in ipairs(result) do
                      if loc.uri then
                        loc.uri = loc.uri:gsub(remote_root, local_root)
                      end
                      if loc.targetUri then
                        loc.targetUri = loc.targetUri:gsub(remote_root, local_root)
                      end
                    end
                  end
                end
                vim.lsp.handlers["textDocument/definition"](err, result, ctx, config)
              end
            end
          end,
          settings = {
            typescript = { tsserver = { useSyntaxServer = "atps" } },
          },
        },

        -- -- Rails LSP (API Container)
        -- ruby_lsp = {
        --   cmd = { "docker", "compose", "exec", "-T", "api", "bundle", "exec", "ruby-lsp" },
        --   -- 1. Desativa a nível de capabilities nativas do Neovim para evitar o envio de requisições inúteis
        --   on_attach = function(client, bufnr)
        --     if client.server_capabilities then
        --       client.server_capabilities.semanticTokensProvider = nil
        --     end
        --   end,
        --   -- 2. Desativa na inicialização interna do próprio Ruby LSP (Prism Engine)
        --   init_options = {
        --     enabledFeatures = {
        --       "documentSymbols",
        --       "documentLink",
        --       "hover",
        --       "foldingRange",
        --       "selectionRanges",
        --       -- "semanticHighlighting", -- REMOVA OU COMENTE ESSA LINHA SE ELA EXISTIR
        --       "formatting",
        --       "definition",
        --       "references",
        --       "completion",
        --     },
        --   },
        --   settings = {
        --     formatter = "none",
        --     linter = "none",
        --   },
        -- },

        -- RuboCop LSP
        rubocop = {
          cmd = {
            "docker",
            "compose",
            "exec",
            "-T",
            "api",
            "bundle",
            "exec",
            "rubocop",
            "--lsp",
            "--config",
            ".rubocop.yml",
          },
        },

        -- -- TypeScript / React LSP (Modificado para usar on_new_config)
        -- vtsls = {
        --   -- Deixamos um cmd base padronizado
        --   cmd = { "docker", "compose", "exec", "-T", "web", "npx", "vtsls", "--stdio" },
        --   on_new_config = function(new_config, new_root_dir)
        --     local container = string.find(new_root_dir or "", "/ops") and "ops" or "web"
        --     -- Substitui dinamicamente o alvo do container com base na pasta ativa
        --     new_config.cmd = { "docker", "compose", "exec", "-T", container, "npx", "vtsls", "--stdio" }
        --   end,
        --   settings = {
        --     typescript = { tsserver = { useSyntaxServer = "atps" } },
        --   },
        -- },

        -- Tailwind CSS (Modificado para usar on_new_config)
        tailwindcss = {
          cmd = { "docker", "compose", "exec", "-T", "web", "npx", "@tailwindcss/language-server", "--stdio" },
          on_new_config = function(new_config, new_root_dir)
            local container = string.find(new_root_dir or "", "/ops") and "ops" or "web"
            new_config.cmd =
              { "docker", "compose", "exec", "-T", container, "npx", "@tailwindcss/language-server", "--stdio" }
          end,
        },
      },
    },
  },
}
