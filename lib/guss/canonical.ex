defmodule Guss.Canonical do
  @moduledoc false

  alias __MODULE__
  alias Guss.Resource

  @doc """
  Returns iodata for a canonical value from the resource.
  """
  @spec canonicalise(resource :: Guss.Resource.t(), key :: atom()) :: nil | [any()]
  def canonicalise(resource, key)

  def canonicalise(%Resource{extensions: extensions}, :extensions) do
    Canonical.Extensions.to_iodata(extensions)
  end

  def canonicalise(%Resource{bucket: bucket, objectname: objectname}, :resource) do
    [?/, bucket, ?/, objectname]
  end

  def canonicalise(resource, key) do
    resource |> Map.fetch!(key) |> to_iodata(key)
  end

  defp to_iodata(verb, :http_verb) when is_atom(verb) do
    verb |> Atom.to_string() |> to_iodata(:http_verb)
  end

  defp to_iodata(verb, :http_verb) when is_binary(verb) do
    [String.upcase(verb, :ascii), lf()]
  end

  defp to_iodata(value, _) when is_integer(value), do: [Integer.to_string(value), lf()]
  defp to_iodata(value, _) when is_binary(value), do: [value, lf()]
  defp to_iodata(_, _), do: ["", lf()]

  @doc """
  Returns the code point for a line feed (LF).
  """
  def lf(), do: ?\n
end
