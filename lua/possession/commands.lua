local M = {}

local session = require('possession.session')
local utils = require('possession.utils')
local info = require('possession.info')

local function complete_list(candidates, opts)
    opts = vim.tbl_extend('force', {
        sort = true,
    }, opts or {})

    vim.validate { candidates = { candidates, { 'table', 'function' } } }

    local get_candidates = function()
        local list = type(candidates) == 'function' and candidates() or candidates
        if opts.sort then
            table.sort(list)
        end
        return list
    end

    return function(arg_lead, cmd_line, cursor_pos)
        return vim.tbl_filter(function(c)
            return vim.startswith(c, arg_lead)
        end, get_candidates())
    end
end

-- Limits filesystem access by caching the results by time
M.complete_session = complete_list(utils.throttle(function()
    local files = vim.tbl_keys(session.list { no_read = true })
    return vim.tbl_map(utils.session_name_from_path, files)
end, 3000))

function M.save(name, no_confirm)
    session.save(name, { no_confirm = no_confirm })
end

function M.load(name)
    session.load(name)
end

function M.delete(name)
    session.delete(name)
end

function M.show(name)
    local path = utils.session_path(name)
    local data = vim.json.decode(path:read())
    data.file = path:absolute()

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    info.display_session(data, buf)
    vim.api.nvim_win_set_buf(0, buf)
end

function M.list(full)
    local sessions = session.list()
    local lines = {}
    for file, data in pairs(sessions) do
        table.insert(lines, 'Name: ' .. data.name)
        table.insert(lines, '  File: ' .. file)
        table.insert(lines, '  Cwd: ' .. data.cwd)

        table.insert(lines, '  User data:')
        local user_data = vim.inspect(data.user_data, { indent= '    ' })
        for _, line in ipairs(vim.split(user_data, '\n', { plain = true })) do
            table.insert(lines, '  ' .. line)
        end

        if full then
            -- Does not really make sense to list vimscript, at least join lines.
            table.insert(lines, '  Vimscript: ' .. data.vimscript:gsub('\n', '\\n'))
        end
    end
    print(table.concat(lines, '\n'))
end

return M
