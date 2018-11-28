defmodule Guss.CanonicalTest do
  use ExUnit.Case, async: true
  alias Guss.Resource
  alias Guss.Canonical

  describe "canonicalise/2 :resource" do
    test "returns path as iodata" do
      url = %Resource{bucket: "bucket", objectname: "objectname"}

      assert Canonical.canonicalise(url, :resource) == [?/, url.bucket, ?/, url.objectname]
    end
  end

  describe "canonicalise/2 extension headers algorithm" do
    setup _ do
      {:ok, url: %Resource{bucket: "bucket", objectname: "objectname"}}
    end

    test "1. downcases header names", %{url: url} do
      url = %{
        url
        | extensions: [acl: :public_read, STORAGE_CLASS: "MAINLINE", meta: [FOO: "bar"]]
      }

      headers = Canonical.canonicalise(url, :extensions)

      assert IO.iodata_to_binary(headers) ==
               "x-goog-acl:public-read\nx-goog-meta-foo:bar\nx-goog-storage-class:MAINLINE\n"
    end

    test "2. sorts headers alphabetically", %{url: url} do
      url = %{url | extensions: [foo: "bar", acl: :public_read, abc: "xyz"]}

      headers = Canonical.canonicalise(url, :extensions)

      assert IO.iodata_to_binary(headers) ==
               "x-goog-abc:xyz\nx-goog-acl:public-read\nx-goog-foo:bar\n"
    end

    test "3. removes encryption key", %{url: url} do
      url = %{url | extensions: [encryption_key: "private"]}

      headers = Canonical.canonicalise(url, :extensions)

      assert is_nil(headers)
    end

    test "3. removes encryption key sha256", %{url: url} do
      url = %{url | extensions: [encryption_key_sha256: "private"]}

      headers = Canonical.canonicalise(url, :extensions)

      assert is_nil(headers)
    end

    test "4. eliminates duplicate headers via csv", %{url: url} do
      url = %{
        url
        | extensions: [{"foo", "a"}, foo: "b", foo: "c", meta_name: "Alice", meta: [name: "Bob"]]
      }

      headers = Canonical.canonicalise(url, :extensions)

      assert IO.iodata_to_binary(headers) == "x-goog-foo:a,b,c\nx-goog-meta-name:Alice,Bob\n"
    end

    test "5. replaces folding whitespace via RFC 7230, section 3.2.4", %{url: url} do
      foo = "bar\n\tbar\n bar\r\n b  a  r\r\n   \t  bar"

      url = %{
        url
        | extensions: [foo: foo, acl: :public_read, abc: "xyz", storage_class: "COLDLINE"]
      }

      headers = Canonical.canonicalise(url, :extensions)

      assert IO.iodata_to_binary(headers) ==
               "x-goog-abc:xyz\nx-goog-acl:public-read\nx-goog-foo:bar bar bar b  a  r bar\nx-goog-storage-class:COLDLINE\n"
    end

    test "6. removes whitespace around the colon after the header name", %{url: url} do
      url = %{
        url
        | extensions: [{"foo  ", "bar"}, acl: :public_read, abc: "xyz"]
      }

      headers = Canonical.canonicalise(url, :extensions)

      assert IO.iodata_to_binary(headers) ==
               "x-goog-abc:xyz\nx-goog-acl:public-read\nx-goog-foo:bar\n"
    end
  end
end
