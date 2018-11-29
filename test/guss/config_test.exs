defmodule Guss.ConfigTest do
  use ExUnit.Case
  alias Guss.Resource
  alias Guss.Config

  describe "for_resource/2" do
    setup _ do
      resource = %Resource{bucket: "bucket", objectname: "objectname"}

      {:ok, resource: resource}
    end

    test "with unknown account, returns error", %{resource: resource} do
      resource = %{resource | account: "unknown-account@guss-config-test"}

      assert {:error, {:config, "client_email"}} = Config.for_resource(Goth.Config, resource)
    end

    test "with invalid credentials, returns error", %{resource: resource} do
      config = fixture(:invalid_config)
      resource = %{resource | account: config["client_email"]}

      assert {:error, {:config, "private_key"}} = Config.for_resource(Goth.Config, resource)
    end

    test "with service account, returns client email from token", %{resource: resource} do
      {:ok, email} = Goth.Config.get("client_email")
      {:ok, pk} = Goth.Config.get("private_key")

      assert {:ok, {^email, ^pk}} = Config.for_resource(Goth.Config, resource)
    end
  end

  defp fixture(:invalid_config) do
    config = %{
      "client_email" => "authorized_user@guss-config-test",
      "refresh_token" => "foo",
      "client_id" => "foo@bar",
      "client_secret" => "bar",
      "type" => "authorized_user"
    }

    :ok = Goth.Config.add_config(config)

    config
  end
end
