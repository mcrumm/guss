defmodule Guss.StorageV2SignerTest do
  use ExUnit.Case, async: true

  alias Guss.StorageV2Signer

  describe "string_to_sign/1" do
    setup _ do
      {:ok, account} = Goth.Config.get("client_email")
      {:ok, private_key} = Goth.Config.get("private_key")

      {:ok, account: account, private_key: private_key}
    end

    test "without content_type and extensions" do
      expires = Guss.expires_in({1, :hour})
      url = Guss.put("foo", "bar.txt", expires: expires)

      expected_string = "PUT\n\n\n#{expires}\n/foo/bar.txt"

      assert StorageV2Signer.string_to_sign(url) == expected_string
    end

    test "without extensions" do
      expires = Guss.expires_in({1, :hour})

      url =
        Guss.put("foo", "bar.txt",
          expires: expires,
          content_type: "image/jpeg"
        )

      expected_string = "PUT\n\nimage/jpeg\n#{expires}\n/foo/bar.txt"

      assert StorageV2Signer.string_to_sign(url) == expected_string
    end

    test "with extensions" do
      expires = Guss.expires_in({1, :hour})

      url =
        Guss.put("foo", "bar.txt",
          expires: expires,
          content_type: "image/jpeg",
          acl: :public_read,
          meta: [environment: :test]
        )

      expected_string =
        "PUT\n\nimage/jpeg\n#{expires}\nx-goog-acl:public-read\nx-goog-meta-environment:test\n/foo/bar.txt"

      assert StorageV2Signer.string_to_sign(url) == expected_string
    end
  end
end
