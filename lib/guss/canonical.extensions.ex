defmodule Guss.Canonical.Extensions do
  @moduledoc false

  @doc """
  Converts resource extensions into canonical extension headers.

  For more information, see:
  https://cloud.google.com/storage/docs/access-control/signed-urls-v2

  ## Examples

      iex> to_string(Guss.Canonical.Extensions.to_iodata(acl: :public_read, meta: [project: [name: "guss"]]))
      "x-goog-acl:public-read\\nx-goog-meta-project-name:guss\\n"
  """
  @spec to_iodata([{any(), any()}]) :: nil | [any()]
  def to_iodata([]), do: nil
  def to_iodata(extensions) when is_list(extensions), do: build_attrs(extensions)

  defp headerize_attrs([]), do: nil

  defp headerize_attrs(attrs) do
    for {k, v} <- Enum.group_by(attrs, &elem(&1, 0), &elem(&1, 1)),
        filter_header({k, v}) do
      [hdr_prefix(), k, hdr_sep(), sanitize(v), hdr_delim()]
    end
    |> case do
      [] -> nil
      tags -> tags
    end
  end

  defp hdr_prefix, do: [?x, ?-, ?g, ?o, ?o, ?g, ?-]
  defp hdr_sep, do: ?:
  defp hdr_delim, do: ?\n

  defp nested_attrs(attr, dict, acc) do
    Enum.reduce(dict, acc, fn {k, v}, acc ->
      attr_name = "#{attr}-#{dasherize(k)}"

      case is_list(v) do
        true -> nested_attrs(attr_name, v, acc)
        false -> [{attr_name, v} | acc]
      end
    end)
  end

  defp build_attrs([]), do: []
  defp build_attrs(attrs), do: build_attrs(attrs, [])
  defp build_attrs([], acc), do: acc |> Enum.sort() |> headerize_attrs()

  # Builds nested :meta values
  defp build_attrs([{:meta, v} | t], acc) when is_list(v) do
    build_attrs(t, nested_attrs(dasherize(:meta), v, acc))
  end

  # Ignores default ACL policy
  defp build_attrs([{:acl, :private} | t], acc) do
    build_attrs(t, acc)
  end

  # Dasherizes ACL values
  defp build_attrs([{:acl, v} | t], acc) do
    build_attrs(t, [{dasherize(:acl), dasherize(v)} | acc])
  end

  # Ignores empty values
  defp build_attrs([{_, v} | t], acc) when is_nil(v) or v == "" do
    build_attrs(t, acc)
  end

  # Converts atom values to strings
  defp build_attrs([{k, v} | t], acc) when is_atom(v) do
    build_attrs(t, [{dasherize(k), Atom.to_string(v)} | acc])
  end

  defp build_attrs([{k, v} | t], acc) do
    build_attrs(t, [{dasherize(k), v} | acc])
  end

  defp dasherize(value) when is_atom(value), do: dasherize(Atom.to_string(value))

  defp dasherize(value) when is_binary(value),
    do: value |> String.trim() |> String.downcase() |> String.replace("_", "-")

  defp sanitize([]), do: []
  defp sanitize(values) when is_list(values), do: sanitize(values, [])

  defp sanitize(value) when is_binary(value) do
    value |> String.trim() |> String.replace(~r/[\r\n]+[\t\s]+/, " ")
  end

  defp sanitize([], acc), do: acc |> Enum.reverse() |> Enum.join(",")

  defp sanitize([value | t], acc) do
    sanitize(t, [sanitize(value) | acc])
  end

  defp filter_header({"encryption-key", _}), do: false
  defp filter_header({"encryption-key-sha256", _}), do: false
  defp filter_header(_kv), do: true
end
