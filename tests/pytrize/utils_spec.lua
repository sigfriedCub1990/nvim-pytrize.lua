local utils = require("pytrize.utils")

describe("min", function()
  it("returns the smaller value", function()
    assert.are.equal(1, utils.min(1, 2))
    assert.are.equal(1, utils.min(2, 1))
  end)

  it("returns the value when equal", function()
    assert.are.equal(5, utils.min(5, 5))
  end)

  it("works with negative numbers", function()
    assert.are.equal(-3, utils.min(-3, -1))
  end)
end)

describe("max", function()
  it("returns the larger value", function()
    assert.are.equal(2, utils.max(1, 2))
    assert.are.equal(2, utils.max(2, 1))
  end)

  it("returns the value when equal", function()
    assert.are.equal(5, utils.max(5, 5))
  end)

  it("works with negative numbers", function()
    assert.are.equal(-1, utils.max(-3, -1))
  end)
end)
