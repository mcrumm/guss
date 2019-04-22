defmodule Guss.RequestHeadersTest do
  use ExUnit.Case
  doctest Guss.RequestHeaders

  describe "dasherize/1" do
    test "is idempotent" do
      opts = [
        a_foo_bar: "qux",
        a: [foo_qux: "one"],
        content_type: "text/plain",
        content_md5: "3a0ef89...",
        b: [
          maps: %{"foo" => "bar", "ints" => 8701},
          atoms: :project_private,
          integers: 42
        ]
      ]

      expected = Guss.RequestHeaders.dasherize(opts)

      assert Guss.RequestHeaders.dasherize(expected) == expected
    end
  end
end
