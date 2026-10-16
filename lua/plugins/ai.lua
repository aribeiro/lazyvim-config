return {
  -- Sidekick (ai.sidekick extra): open the GitHub Copilot CLI directly instead of a tool picker.
  -- <leader>as still picks another CLI tool.
  {
    "folke/sidekick.nvim",
    keys = {
      {
        "<leader>aa",
        function()
          require("sidekick.cli").toggle({ name = "copilot", focus = true })
        end,
        desc = "Sidekick Toggle Copilot CLI",
      },
    },
  },
}
