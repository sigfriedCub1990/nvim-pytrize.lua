local utils = require("pytrize.utils")

describe("with_buf", function()
    it("loads a file into a buffer, calls fn, and cleans up", function()
        local tmp = vim.fn.tempname() .. ".py"
        local f = io.open(tmp, "w")
        f:write("x = 1\n")
        f:close()

        local result = utils.with_buf(tmp, function(bufnr)
            local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
            return lines[1]
        end, { force_delete = true })

        assert.are.equal("x = 1", result)

        -- buffer should have been cleaned up
        assert.are.equal(-1, vim.fn.bufnr(tmp))
        vim.fn.delete(tmp)
    end)

    it("suppresses file-info messages by loading via vim.fn.execute", function()
        local tmp = vim.fn.tempname() .. ".py"
        local f = io.open(tmp, "w")
        f:write("x = 1\n")
        f:close()

        -- The C-level file-info message ("path" NL, NB) that bufload()
        -- emits does not appear in :messages or headless output, so we
        -- cannot assert on captured text.  Instead we verify the
        -- suppression mechanism: with_buf must route through
        -- vim.fn.execute() which uses :redir to swallow all output.
        local original_execute = vim.fn.execute
        local execute_calls = {}
        vim.fn.execute = function(cmd)
            table.insert(execute_calls, cmd)
            return original_execute(cmd)
        end

        utils.with_buf(tmp, function(_) end, { force_delete = true })

        vim.fn.execute = original_execute

        -- At least one call should be the bufload wrapper
        local found = false
        for _, cmd in ipairs(execute_calls) do
            if type(cmd) == "string" and cmd:find("bufload") then
                found = true
                break
            end
        end
        assert.is_true(found, "with_buf should call vim.fn.execute() with bufload to suppress file-info messages")

        vim.fn.delete(tmp)
    end)

    it("propagates errors from fn", function()
        local tmp = vim.fn.tempname() .. ".py"
        local f = io.open(tmp, "w")
        f:write("x = 1\n")
        f:close()

        assert.has_error(function()
            utils.with_buf(tmp, function(_)
                error("test error")
            end, { force_delete = true })
        end)

        vim.fn.delete(tmp)
    end)
end)
