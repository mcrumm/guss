defmodule Guss.Canonical.Extensions do
  @moduledoc """
  Generates iodata for Canonicalized Extension Headers

  Extension headers are generated using the following algorithm:

  1. Make all custom header names lowercase.
  2. Sort all custom headers by header name using a lexicographical sort by code point value.
  3. If present, remove the `x-goog-encryption-key` and `x-goog-encryption-key-sha256` headers. These headers contain sensitive information that must not be included in the string-to-sign; however, these headers must still be used in any requests that use the generated signed URL.
  4. Eliminate duplicate header names by creating one header name with a comma-separated list of values. Be sure there is no whitespace between the values, and be sure that the order of the comma-separated list matches the order that the headers appear in your request. For more information, see [RFC 7230 section 3.2](https://tools.ietf.org/html/rfc7230#section-3.2).
  5. Replace any folding whitespace or newlines (CRLF or LF) with a single space. For more information about folding whitespace, see [RFC 7230, section 3.2.4](https://tools.ietf.org/html/rfc7230#section-3.2.4).
  6. Remove any whitespace around the colon that appears after the header name.
  7. Append a newline `\\n` (U+000A) to each custom header.
  8. Concatenate all custom headers.
  """

  @doc """
  Converts resource extensions into canonical extension headers.

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
