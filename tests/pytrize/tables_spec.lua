local tables = require("pytrize.tables")

describe("reverse", function()
  it("reverses a list", function()
    assert.are.same({ 3, 2, 1 }, tables.reverse({ 1, 2, 3 }))
  end)

  it("handles empty list", function()
    assert.are.same({}, tables.reverse({}))
  end)

  it("handles single element", function()
    assert.are.same({ 1 }, tables.reverse({ 1 }))
  end)
end)

describe("list_map", function()
  it("applies function to each element", function()
    local result = tables.list_map(function(x) return x * 2 end, { 1, 2, 3 })
    assert.are.same({ 2, 4, 6 }, result)
  end)

  it("returns empty list for empty input", function()
    assert.are.same({}, tables.list_map(function(x) return x end, {}))
  end)

  it("works with identity function", function()
    assert.are.same({ "a", "b" }, tables.list_map(function(x) return x end, { "a", "b" }))
  end)
end)

