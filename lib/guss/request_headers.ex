defmodule Guss.RequestHeaders do
  @moduledoc """
  Conveniences for working with canonical request headers.
  """

  @doc """
  Convert the enumerable to a dasherized list, suitable for URL signing.

  The enumerable will have the following transformations applied:
  * Header keys are lower-cased.
  * Underscores (`"_"`) are replaced with dashes (`"-"`).
  * Leading and trailing whitespace is removed.
  * Keys with empty values will be removed.
  * Atom values will be dasherized like header keys. This is useful for some built-in values,
    like `:public_read`.
  * Integer values are converted to strings.
  * Enumerable values will be expanded following the same transformation rules. See the examples
    for more details.

  The result is a list of `{key, value}` tuples for each request header, sorted by key name.

  ## Examples

      iex> Guss.RequestHeaders.dasherize(x_foo_bar: "qux")
      [{"x-foo-bar", "qux"}]

      iex> Guss.RequestHeaders.dasherize(x: [foo_bar: "qux"])
      [{"x-foo-bar", "qux"}]

      iex> Guss.RequestHeaders.dasherize(x: [foo: [bar: "qux"]])
      [{"x-foo-bar", "qux"}]

      ies> Guss.RequestHeaders.dasherize(x: [meta: [int: 42, atom: :foo_bar]])
      [{"x-meta-int", "42"}, {"x-meta-atom", "foo-bar"}]

      iex> Guss.RequestHeaders.dasherize(content_type: "text/plain", content_md5: "3a0ef89...")
      [{"content-md5", "3a0ef89..."}, {"content-type", "text/plain"}]

      iex> Guss.RequestHeaders.dasherize(X: [{:user, "Bob"}, {"User", "Alice"}])
      [{"x-user", "Bob"}, {"x-user", "Alice"}]

      iex> Guss.RequestHeaders.dasherize(x: [vendor: [id: "guss"], goog: [acl: :public_read]])
      [{"x-goog-acl", "public-read"}, {"x-vendor-id", "guss"}]

      iex> Guss.RequestHeaders.dasherize(%{"X" => %{"Goog" => %{"Acl" => "public-read", "Meta" => %{"Value" => 1}}}})
      [{"x-goog-acl", "public-read"}, {"x-goog-meta-value", "1"}]

      iex> Guss.RequestHeaders.dasherize(%{"X" => %{"Goog" => %{"Meta" => %{"  Value  " => 1}}}})
      [{"x-goog-meta-value", "1"}]
  """
  def dasherize(data) when is_map(data) and data == %{}, do: []
  def dasherize(data) when is_map(data), do: data |> Enum.into([]) |> do_dasherize()
  def dasherize(data) when is_list(data), do: data |> do_dasherize()

  # Starts collapsing items. Empty lists are ignored.
  defp do_dasherize([]), do: []
  defp do_dasherize(enum), do: dasherize_items(enum, [])

  # Input values exhausted
  defp dasherize_items([], acc), do: acc |> ordered_sort()

  # Expands nested values
  defp dasherize_items([{key, val} | rest], acc) when is_list(val) or is_map(val) do
    dasherize_items(rest, dasherize_nested(key_name(key), val, acc))
  end

  # Ignores empty values
  defp dasherize_items([{_, val} | rest], acc) when is_nil(val) or val == "" do
    dasherize_items(rest, acc)
  end

  # Dasherizes atom values
  defp dasherize_items([{key, val} | rest], acc) when is_atom(val) do
    dasherize_items(rest, [{key_name(key), to_dashed(val)} | acc])
  end

  # Dasherizes key and stringifies values
  defp dasherize_items([{key, val} | rest], acc) do
    dasherize_items(rest, [{key_name(key), to_string(val)} | acc])
  end

  defp dasherize_nested(prefix, enum, acc) do
    Enum.reduce(enum, acc, fn {key, val}, acc ->
      next_key = "#{prefix}-#{key_name(key)}"

      case val do
        val when is_map(val) -> dasherize_nested(next_key, Enum.into(val, []), acc)
        val when is_list(val) -> dasherize_nested(next_key, val, acc)
        val when is_atom(val) -> [{next_key, to_dashed(val)} | acc]
        val -> [{next_key, to_string(val)} | acc]
      end
    end)
  end

  defp to_dashed(str) when is_atom(str), do: to_dashed(Atom.to_string(str))
  defp to_dashed(str) when is_binary(str), do: String.replace(str, "_", "-")

  defp key_name(key), do: key |> to_dashed() |> String.trim() |> String.downcase()

  defp ordered_sort(items) do
    items
    |> Enum.reverse()
    |> Enum.with_index()
    |> Enum.sort_by(fn {{k, _v}, i} -> {k, i} end)
    |> Enum.unzip()
    |> elem(0)
  end

  @doc """
  Eliminates duplicate keys in the enumerable.

  Duplicate keys will be replaced with a single key and a
  comma-separated list of values.

  The result is a list sorted alphabetically by key. Values will
  retain their ordering in the original list.

  ## Examples

    iex> Guss.RequestHeaders.deduplicate([{"x", "foo"}, {"x", "bar"}])
    [{"x", "foo,bar"}]

    iex> Guss.RequestHeaders.deduplicate([{"x", "this"}, {"bar", "qux"}, {"x", "that"}])
    [{"bar", "qux"}, {"x", "this,that"}]
  """
  def deduplicate(enumerable) do
    for {k, v} <- Enum.group_by(enumerable, &elem(&1, 0), &elem(&1, 1)) do
      {k, join_values(v, ",")}
    end
    |> Enum.into([])
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp join_values(items, joiner) when is_list(items) do
    items |> Enum.map_join(joiner, &String.trim/1)
  end
end
