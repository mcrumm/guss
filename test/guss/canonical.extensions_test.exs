defmodule Guss.Canonical.ExtensionsTest do
  use ExUnit.Case, async: true
  doctest Guss.Canonical.Extensions
  alias Guss.Canonical.Extensions

  describe "to_iodata/1" do
    test "when empty, returns empty list" do
      headers = Extensions.to_iodata([])

      assert is_nil(headers)
    end

    test "prefixes headers with x-goog-" do
      headers = Extensions.to_iodata(acl: :public_read, foo: "bar")

      assert IO.iodata_to_binary(headers) == "x-goog-acl:public-read\nx-goog-foo:bar\n"
    end

    test "converts boolean values" do
      headers = Extensions.to_iodata(foo: true, bar: false)

      assert IO.iodata_to_binary(headers) == "x-goog-bar:false\nx-goog-foo:true\n"
    end

    test "ignores empty values" do
      headers = Extensions.to_iodata(foo: "", bar: nil)

      assert is_nil(headers)
    end

    test "ignores default :acl value" do
      headers = Extensions.to_iodata(acl: :private)

      assert is_nil(headers)
    end

    test "with :meta, expands keys" do
      headers =
        Extensions.to_iodata(meta: [foo: "bar", project: [name: "My Project", version: "1.0.0"]])

      assert IO.iodata_to_binary(headers) ==
               "x-goog-meta-foo:bar\nx-goog-meta-project-name:My Project\nx-goog-meta-project-version:1.0.0\n"
    end

    test "with :meta, dasherizes keys" do
      headers =
        Extensions.to_iodata(
          meta: [foo: "bar", project_name: "My Project", project_version: "1.0.0"]
        )

      assert IO.iodata_to_binary(headers) ==
               "x-goog-meta-foo:bar\nx-goog-meta-project-name:My Project\nx-goog-meta-project-version:1.0.0\n"
    end
  end
end
