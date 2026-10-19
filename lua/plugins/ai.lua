-- Copilot in the projects listed in local.lua (copilot_dirs), where it's the only AI tool allowed;
-- Claude Code everywhere else. local.lua is git-ignored, since it names machine-specific (and
-- possibly private) paths:
--
--   return { copilot_dirs = { "~/work/some-project" } }
local ok, settings = pcall(dofile, vim.fn.stdpath("config") .. "/local.lua")
local copilot_dirs = vim.tbl_map(vim.fs.normalize, ok and settings.copilot_dirs or {})

-- Whether Neovim's cwd or the current file is in one of those projects. Either counts, so a project
-- file opened from somewhere else still gets Copilot.
local function copilot_only()
  local paths = { vim.fn.getcwd(), vim.api.nvim_buf_get_name(0) }
  for _, dir in ipairs(copilot_dirs) do
    for _, path in ipairs(paths) do
      if path ~= "" and vim.fs.relpath(dir, path) then
        return true
      end
    end
  end
  return false
end

-- A key that uses the Copilot CLI through Sidekick in those projects and Claude Code through
-- claudecode.nvim everywhere else. Requiring claudecode loads it, which defines its commands.
local function ai_key(copilot, claude_cmd)
  return function()
    if copilot_only() then
      copilot(require("sidekick.cli"))
    else
      require("claudecode")
      vim.cmd(claude_cmd)
    end
  end
end

return {
  -- The <leader>a keys both extras define go to whichever tool the project uses. They live on
  -- Sidekick so that pressing one in a Copilot-only project never loads claudecode, whose server
  -- would let Claude Code connect to this Neovim.
  {
    "folke/sidekick.nvim",
    keys = {
      {
        "<leader>aa",
        ai_key(function(cli)
          cli.toggle({ name = "copilot", focus = true })
        end, "ClaudeCode"),
        desc = "Toggle AI CLI",
      },
      {
        "<leader>af",
        ai_key(function(cli)
          cli.send({ msg = "{file}" })
        end, "ClaudeCodeAdd %"),
        desc = "Send File to AI",
      },
      {
        "<leader>as",
        ai_key(function(cli)
          cli.send({ msg = "{selection}" })
        end, "ClaudeCodeSend"),
        mode = "x",
        desc = "Send Selection to AI",
      },
    },
  },

  -- claudecode.nvim (ai.claudecode extra): drop the keys replaced above, and move diff accept/deny
  -- off <leader>aa/<leader>ad, which mean toggle/detach above. :w in a diff also accepts it.
  {
    "coder/claudecode.nvim",
    keys = {
      { "<leader>ac", false },
      { "<leader>af", false },
      { "<leader>as", false, mode = "v" },
      { "<leader>aa", false },
      { "<leader>ad", false },
      { "<leader>ay", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept Claude Diff" },
      { "<leader>an", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny Claude Diff" },
    },
  },
}
