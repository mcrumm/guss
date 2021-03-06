defmodule Guss.Config do
  @moduledoc false
  alias Guss.Resource

  @spec for_resource(mod :: atom, Guss.Resource.t()) ::
          {:error, {:config, binary()}} | {:ok, {any(), any()}}
  def for_resource(mod, %Resource{account: account}) when is_atom(mod) do
    with {:ok, email} <- from_config(mod, account, "client_email"),
         {:ok, private_key} <- from_config(mod, account, "private_key") do
      {:ok, {email, private_key}}
    end
  end

  defp from_config(mod, account, key) when is_atom(mod) do
    with {:ok, value} <- apply(mod, :get, [account, key]) do
      {:ok, value}
    else
      :error -> {:error, {:config, key}}
    end
  end
end
