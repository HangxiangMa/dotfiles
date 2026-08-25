-- codecompanion.nvim wired to the same internal Breeze / QGenie model
-- gateways used elsewhere (e.g. by pi, this assistant, via ~/.pi/agent),
-- following the same integration shape: an Anthropic-Messages-compatible
-- endpoint reached with `X-Api-Key` auth, just pointed at an internal base
-- URL instead of api.anthropic.com. codecompanion's built-in "anthropic"
-- adapter already speaks that exact wire format, so both gateways are just
-- `extend("anthropic", { url = ..., env = { api_key = ... } })`.
--
-- Neither gateway's URL nor API key is checked into this (public) repo.
-- Export all four of these from your own private shell rc before starting
-- nvim (not from anything in this repo):
--
--   export NVIM_AI_BREEZE_URL="https://<breeze endpoint>/v1/messages"
--   export NVIM_AI_BREEZE_KEY="<breeze api key>"
--   export NVIM_AI_QGENIE_URL="https://<qgenie endpoint>/v1/messages"
--   export NVIM_AI_QGENIE_KEY="<qgenie api key>"
--
-- Only the *_URL vars are read directly here (to decide whether to register
-- the adapter at all, and to fill the adapter's literal `url` field, which
-- the "anthropic" base adapter does not template from `env`). The *_KEY vars
-- are never read into this config or into memory up front: `env.api_key`
-- below holds the environment variable's *name*, which is codecompanion's
-- own documented convention for lazily resolving secrets per-request (see
-- "Environment Variables" in codecompanion's adapters-http docs) — so the
-- key value itself never gets copied into this Lua table.
--
-- Any gateway whose *_URL var is unset is simply not registered; if none are
-- set, this plugin still loads with whatever adapters codecompanion ships by
-- default, plus a one-time notification so the gap isn't silent.
return {
	{
		"olimorris/codecompanion.nvim",
		cmd = { "CodeCompanion", "CodeCompanionChat", "CodeCompanionActions", "CodeCompanionCmd" },
		-- <leader>a is already the "Diagnostics" group (see plugin/ui/which-key.lua),
		-- and every other single lowercase letter that isn't a plain vim mode-entry
		-- key (i/a/o/...) is likewise claimed by some other plugin — so this uses
		-- <leader>z (fold-prefix in bare vim, but unused as a leader group here and
		-- not a mode change) as the new "AI" group.
		keys = {
			{
				"<leader>zc",
				"<cmd>CodeCompanionChat Toggle<cr>",
				mode = { "n", "v" },
				desc = "CodeCompanion: Toggle chat",
			},
			{ "<leader>za", "<cmd>CodeCompanionActions<cr>", mode = { "n", "v" }, desc = "CodeCompanion: Actions" },
		},
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-treesitter/nvim-treesitter",
		},
		config = function()
			local adapters_http = {}
			local configured_gateways = {}

			---@param key string adapter key other config (e.g. interactions.chat.adapter) refers to
			---@param formatted_name string display label in adapter pickers
			---@param url_env string env var holding the full messages-endpoint URL
			---@param key_env string env var holding the API key (name only, resolved lazily)
			---@param models string[] model ids offered by this gateway, first is the default
			local function add_gateway(key, formatted_name, url_env, key_env, models)
				local url = os.getenv(url_env)
				if not url or url == "" then
					return
				end
				if not os.getenv(key_env) or os.getenv(key_env) == "" then
					vim.notify(
						string.format(
							"codecompanion: %s is set but %s is not — %s adapter will 401 until it is",
							url_env,
							key_env,
							key
						),
						vim.log.levels.WARN
					)
				end
				adapters_http[key] = function()
					return require("codecompanion.adapters").extend("anthropic", {
						formatted_name = formatted_name,
						url = url,
						env = { api_key = key_env },
						schema = {
							model = {
								default = models[1],
								choices = models,
							},
						},
					})
				end
				table.insert(configured_gateways, key)
			end

			add_gateway("breeze", "Breeze (internal)", "NVIM_AI_BREEZE_URL", "NVIM_AI_BREEZE_KEY", {
				"claude-sonnet-5",
				"claude-opus-5",
				"claude-sonnet-4-6",
			})
			add_gateway("qgenie", "QGenie (internal)", "NVIM_AI_QGENIE_URL", "NVIM_AI_QGENIE_KEY", {
				"anthropic::claude-5-sonnet",
				"anthropic::claude-5-opus",
				"anthropic::claude-4-6-sonnet",
			})

			if #configured_gateways == 0 then
				vim.notify(
					"codecompanion: no internal gateway configured — set NVIM_AI_BREEZE_URL/KEY and/or "
						.. "NVIM_AI_QGENIE_URL/KEY in your shell to use Breeze/QGenie; falling back to whatever "
						.. "adapters codecompanion ships by default (needs their own API keys).",
					vim.log.levels.WARN
				)
			end

			-- Prefer breeze, then qgenie, as the default for interactive chat/inline
			-- use; leave codecompanion's own defaults alone when neither is set.
			local default_gateway = configured_gateways[1]

			require("codecompanion").setup({
				adapters = { http = adapters_http },
				interactions = default_gateway
					and {
						chat = { adapter = default_gateway },
						inline = { adapter = default_gateway },
					}
					or nil,
				display = {
					chat = {
						show_settings = true,
					},
				},
			})
		end,
	},
}
