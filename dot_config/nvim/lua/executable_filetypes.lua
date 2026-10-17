local shell = {
	zshrc = "zsh",
	zshenv = "zsh",
	zprofile = "zsh",
	zlogin = "zsh",
	zlogout = "zsh",
	bashrc = "bash",
	bash_profile = "bash",
	bash_aliases = "bash",
	bash_logout = "bash",
	profile = "sh",
}
local pattern = {}
for name, kind in pairs(shell) do
	local fn = function()
		if kind == "bash" then
			return "sh", function(buf)
				vim.b[buf].is_bash = 1
			end
		end
		return kind
	end
	pattern[".*/[%w_]*dot_" .. name .. ".*"] = { fn, { priority = 10 } }
end
vim.filetype.add({ pattern = pattern })
