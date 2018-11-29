defmodule Guss.SignatureTest do
  use ExUnit.Case, async: true
  alias Guss.Resource
  alias Guss.Signature

  describe "generate/2" do
    test "with invalid private key, returns error" do
      url = %Resource{bucket: "bucket", objectname: "objectname"}

      assert {:error, {:signature, _}} = Signature.generate(url, "thiskeyisnotvalid")
    end

    test "with valid private key, returns {:ok, signature}" do
      url = %Resource{bucket: "bucket", objectname: "objectname"}

      {:ok, key} = Goth.Config.get("private_key")

      assert {:ok, string} = Signature.generate(url, key)

      assert is_binary(string)
      assert string != ""
    end
  end
end
