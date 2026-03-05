describe("settings", function()
  local settings_mod

  before_each(function()
    -- Reload module to reset state
    package.loaded["pytrize.settings"] = nil
    package.loaded["pytrize.warn"] = nil
    settings_mod = require("pytrize.settings")
  end)

  it("has default values", function()
    assert.are.equal(false, settings_mod.settings.no_commands)
    assert.are.equal("LineNr", settings_mod.settings.highlight)
  end)

  it("updates a valid key", function()
    settings_mod.update({ no_commands = true })
    assert.are.equal(true, settings_mod.settings.no_commands)
  end)

  it("updates multiple keys at once", function()
    settings_mod.update({ no_commands = true, highlight = "Comment" })
    assert.are.equal(true, settings_mod.settings.no_commands)
    assert.are.equal("Comment", settings_mod.settings.highlight)
  end)

  it("does not crash on unknown key", function()
    local original_notify = vim.notify
    local notified = false
    vim.notify = function() notified = true end
    settings_mod.update({ nonexistent_key = "value" })
    vim.notify = original_notify
    assert.is_true(notified)
  end)

  it("rejects wrong type for a setting", function()
    local original_notify = vim.notify
    local warned = false
    vim.notify = function(msg)
      if type(msg) == "string" and msg:find("invalid type") then
        warned = true
      end
    end
    settings_mod.update({ highlight = 123 })  -- should be string, not number
    vim.notify = original_notify
    assert.is_true(warned)
    -- value should not have changed
    assert.are.equal("LineNr", settings_mod.settings.highlight)
  end)
end)
