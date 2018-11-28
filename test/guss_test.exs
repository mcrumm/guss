defmodule GussTest do
  use ExUnit.Case, async: true
  alias Guss.Resource
  alias Guss

  describe "expires_in/1" do
    test "returns a timestamp for a future second" do
      expires = Guss.expires_in(3600)
      assert_valid_expires(expires, 3600)

      expires = Guss.expires_in({30, :seconds})
      assert_valid_expires(expires, 30)
    end

    test "returns a timestamp for a future hour" do
      expires = Guss.expires_in({1, :hour})

      assert_valid_expires(expires, 3600)
    end

    test "returns a timestamp for a future day" do
      expires = Guss.expires_in({3, :day})

      assert_valid_expires(expires, 3600 * 24 * 3)
    end
  end

  test "get/3 returns a GET resource" do
    assert %Resource{http_verb: :get} = Guss.get("bucket", "objectname")
  end

  test "post/3 returns a GET resource" do
    assert %Resource{http_verb: :post} = Guss.post("bucket", "objectname")
  end

  test "put/3 returns a GET resource" do
    assert %Resource{http_verb: :put} = Guss.put("bucket", "objectname")
  end

  test "delete/3 returns a GET resource" do
    assert %Resource{http_verb: :delete} = Guss.delete("bucket", "objectname")
  end

  describe "new/3" do
    test "builds a URL to :get" do
      assert %Resource{http_verb: :get, bucket: "foo", objectname: "bar.txt"} =
               Guss.new("foo", "bar.txt")
    end

    test "sets :http_verb from opts" do
      Enum.each([:get, :put, :post, :delete], fn verb ->
        assert %Resource{http_verb: ^verb} = Guss.new("foo", "bar.txt", http_verb: verb)
      end)
    end

    test "sets :account from opts" do
      assert %Resource{account: "user@example.com"} =
               Guss.new("foo", "bar.txt", account: "user@example.com")
    end

    test "sets base_url from opts" do
      assert %Resource{base_url: "https://api.localhost"} =
               Guss.new("foo", "bar.txt", base_url: "https://api.localhost")
    end

    test "sets content_type from opts" do
      assert %Resource{content_type: "video/mp4"} =
               Guss.new("foo", "bar.mp4", content_type: "video/mp4")
    end

    test "sets content_md5 from opts" do
      hash = :md5 |> :crypto.hash("some content") |> Base.encode16(case: :lower)

      assert %Resource{content_md5: ^hash} = Guss.new("foo", "bar.mp4", content_md5: hash)
    end

    test "sets expires from opts" do
      expires = Guss.expires_in({1, :day})

      assert %Resource{expires: ^expires} = Guss.new("foo", "bar.txt", expires: expires)
    end
  end

  describe "sign/1" do
    setup _ do
      {:ok, account} = Goth.Config.get("client_email")
      {:ok, private_key} = Goth.Config.get("private_key")

      {:ok, account: account, private_key: private_key}
    end

    test "with default params, url expires in 1 hour" do
      url = %Resource{bucket: "foo", objectname: "bar.txt"}

      expected_url = %{url | expires: Guss.expires_in({1, :hour})}

      {:ok, string} = Guss.sign(url)

      assert {:ok, ^string} = Guss.sign(expected_url)
    end

    test "with valid params, returns {:ok, url}", %{account: account, private_key: private_key} do
      url = %Resource{
        bucket: "foo",
        objectname: "bar.txt",
        expires: Guss.expires_in({2, :hours})
      }

      {:ok, string} = Guss.sign(url)

      assert String.match?(string, ~r/^https:\/\/storage.googleapis.com\/foo\/bar.txt\?Expires=/)

      parsed_url = URI.parse(string)

      query = parsed_url |> Map.fetch!(:query) |> URI.decode_query()

      assert is_map(query)

      assert Map.get(query, "GoogleAccessId", false)
      assert Map.get(query, "GoogleAccessId") == account

      assert Map.get(query, "Expires", false)

      query
      |> Map.get("Expires")
      |> String.to_integer()
      |> assert_valid_expires(3600 * 2)

      {:ok, expected_signature} = Guss.Signature.generate(url, private_key)

      assert Map.get(query, "Signature", false)
      assert Map.get(query, "Signature", false) == expected_signature
    end
  end

  defp assert_valid_expires(expires, seconds, delta \\ 1) do
    now = DateTime.utc_now() |> DateTime.to_unix()
    expected = now + seconds

    assert_in_delta(
      expires,
      expected,
      delta,
      "expires delta expected to be less than #{delta} second(s), but it is not"
    )
  end
end
