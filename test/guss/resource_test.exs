defmodule Guss.ResourceTest do
  use ExUnit.Case, async: true
  alias Guss.Resource

  setup _ do
    {:ok, resource: %Resource{bucket: "bucket", objectname: "objectname"}}
  end

  describe "defimpl String.Chars" do
    test "returns URL string without query params", %{resource: resource} do
      assert to_string(resource) == "https://storage.googleapis.com/bucket/objectname"
    end
  end

  describe "defimpl List.Chars" do
    test "with defaults", %{resource: resource} do
      assert resource |> to_charlist() == [
               ["GET", ?\n],
               ["", ?\n],
               ["", ?\n],
               ["", ?\n],
               [?/, resource.bucket, ?/, resource.objectname]
             ]
    end

    test "with required properties", %{resource: resource} do
      expires = DateTime.utc_now() |> DateTime.to_unix()
      resource = %{resource | expires: expires}

      expires_str = Integer.to_string(expires)

      assert [_, _, _, [^expires_str, _], _] = resource |> to_charlist()
    end

    test "with :http_verb", %{resource: resource} do
      resource = %{resource | http_verb: :put}

      assert [["PUT", _] | _] = resource |> to_charlist()
    end

    test "with :content_md5", %{resource: resource} do
      hash = :md5 |> :crypto.hash("some content") |> Base.encode16(case: :lower)

      resource = %{resource | content_md5: hash}

      assert [_, [^hash, _] | _] = resource |> to_charlist()
    end

    test "with :content_type", %{resource: resource} do
      content_type = "video/mp4"
      resource = %{resource | content_type: content_type}

      assert [_, _, [^content_type, _] | _] = resource |> to_charlist()
    end

    test "with :expires timestamp", %{resource: resource} do
      expires = DateTime.utc_now() |> DateTime.to_unix()
      resource = %{resource | expires: expires}

      expected = Integer.to_string(expires)

      assert [_, _, _, [^expected, _] | _] = resource |> to_charlist()
    end

    test "extensions", %{resource: resource} do
      resource = %{resource | expires: 12345, extensions: [acl: :public_read, meta: [foo: "bar"]]}

      assert IO.iodata_to_binary(to_charlist(resource)) ==
               "GET\n\n\n12345\nx-goog-acl:public-read\nx-goog-meta-foo:bar\n/bucket/objectname"
    end
  end
end
