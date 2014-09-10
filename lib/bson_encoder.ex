defprotocol BsonEncoder do
  @moduledoc """
  `BsonEncoder` protocol defines Bson encoding according to Elixir types or Bson specific struct (see `Bson`).

  List of the protocol implementations:

  * `Map` - Encodes a map into a document
  * `Integer` - Encodes integer in 32 or 64 bits
  * `Float` - Encodes float in 64 bits
  * `Atom` - Encodes special atom (`false`, `true`, `nil`,
  `:nan`, `:+inf`, `:-inf`, `MIN_KEY` and `MAX_KEY`) in appropriate format
  others in special type Symbol
  * `Tuple` - Encodes the return of `now/1`
  * `BitString` - as binary string
  * `List` - Encodes a list as array
  * `Bson.Regex' - see specs
  * `Bson.ObjectId' - see specs
  * `Bson.JS' - see specs
  * `Bson.Bin' - see specs
  * `Bson.Timestamp  ' - see specs

  """

  @doc """
  Returns a binary representing a named term in Bson format

  """
  def encode(term, name)
end

defimpl BsonEncoder, for: Integer do
  def encode(i, name) when -0x80000000 <= i and i <= 0x80000000, do: <<0x10>> <> name <> <<0x00>> <> <<i::32-signed-little>>
  def encode(i, name) when -0x8000000000000000 <= i and i <= 0x8000000000000000, do: <<0x12>> <> name <> <<0x00>> <> <<i::64-signed-little>>
  def encode(i, name), do: {:error, {"cannot encode integer", name, i}}
end

defimpl BsonEncoder, for: Float do
  def encode(f, name), do: <<0x01>> <> name <> <<0x00>> <> <<(f)::size(64)-float-little>>
end

defimpl BsonEncoder, for: Atom do
  # predefind Bson value
  def encode(false, name),   do: <<0x08>> <> name <> <<0x00>> <> <<0x00>>
  def encode(true, name),    do: <<0x08>> <> name <> <<0x00>> <> <<0x01>>
  def encode(nil, name),     do: <<0x0a>> <> name <> <<0x00>>
  def encode(:nan, name),    do: <<0x01>> <> name <> <<0x00>> <> <<0, 0, 0, 0, 0, 0, 248, 127>>
  def encode(:'+inf', name), do: <<0x01>> <> name <> <<0x00>> <> <<0, 0, 0, 0, 0, 0, 240, 127>>
  def encode(:'-inf', name), do: <<0x01>> <> name <> <<0x00>> <> <<0, 0, 0, 0, 0, 0, 240, 255>>
  def encode(MIN_KEY, name), do: <<0xff>> <> name <> <<0x00>>
  def encode(MAX_KEY, name), do: <<0x7f>> <> name <> <<0x00>>
  # other Elixir atom are encoded like strings ()
  def encode(atom, name),    do: <<0x0e>> <> name <> <<0x00>> <> (atom |> Atom.to_string |> Bson.string)
end

defimpl BsonEncoder, for: Regex do
  def encode(regex, name), do: <<0x0b>> <> name <> <<0x00>> <> regex.source <> <<0x00>> <> regex.opts <> <<0x00>>
end

defimpl BsonEncoder, for: Bson.ObjectId do
  def encode(%Bson.ObjectId{oid: oid}, name) when is_binary(oid), do: <<0x07>> <> name <> <<0x00>> <> oid
  def encode(obj, name), do: {:error, {"cannot encode object id", name, obj}}
end

defimpl BsonEncoder, for: Bson.JS do
  def encode(%Bson.JS{code: js, scope: nil}, name) when is_binary(js) do
    <<0x0d>> <> name <> <<0x00>> <> Bson.string(js)
  end
  def encode(%Bson.JS{code: js, scope: ctx}, name) when is_binary(js) and is_map(ctx) do
    case BsonEncoder.Map.encode(ctx, "") do
      {:error, reason} ->
        {:error, {"cannot encode context of js", name, reason}}
      <<_::16, ctxBin::binary>> ->
        <<0x0f>> <> name <> <<0x00>> <> js_ctx(Bson.string(js) <> ctxBin)
    end
  end
  def encode(js, name), do: {:error, "cannot encode '#{name}' : #{inspect(js)}"}

  defp js_ctx(jsctx), do: Bson.int32(byte_size(jsctx)+4) <> jsctx
end

defimpl BsonEncoder, for: Bson.Bin do
  def encode(%Bson.Bin{bin: bin, subtype: subtype}, name)
    when is_binary(bin) and is_binary(subtype) and byte_size(subtype) == 1,
    do:  <<0x05>> <> name <> <<0x00>> <> Bson.int32(byte_size(bin)) <> subtype <> bin
  def encode(bin, name), do: {"cannot encode binary", name, bin}
end

defimpl BsonEncoder, for: Bson.Timestamp do
  def encode(%Bson.Timestamp{inc: i, ts: t}, name)
    when is_integer(i) and -0x80000000 <= i and i <= 0x80000000
     and is_integer(t) and -0x80000000 <= t and t <= 0x80000000,
    do: <<0x11>> <> name <> <<0x00, i::32-signed-little, t::32-signed-little>>
    def encode(ts, name), do: {"cannot encode timestamp", name, ts}
end

defimpl BsonEncoder, for: BitString do
  def encode(s, name) when is_binary(s),  do: <<0x02>> <> name <> <<0x00>> <> Bson.string(s)
  def encode(bits, name), do: {:error, {"cannot encode non-binary bitsrings", name, bits}}
end

defimpl BsonEncoder, for: List do
  def encode(array, name) do
    case Enumerable.reduce(array, {:cont, {[], 0}},
      fn(item, {bufferAcc, i}) ->
        name = i |> Integer.to_string
        case BsonEncoder.encode(item, name) do
          {:error, reason} -> {:halt, {"cannot encode item in array", name, reason}}
          encoded -> {:cont, {[encoded | bufferAcc], i+1}}
        end
      end) do
      {:halted, reason} ->
        {:error, reason}
      {:done, {bufferAcc, _}} ->
        <<0x04>> <> name <> <<0x00>> <> (bufferAcc |> Enum.reverse |> IO.iodata_to_binary |> Bson.doc)
    end
  end
end

defimpl BsonEncoder, for: Map do
  def encode(map, name) do
    case Enumerable.reduce(map, {:cont, []},
      fn({key, val}, bufferAcc) ->
        name = if is_atom(key), do: Atom.to_string(key), else: key
        case BsonEncoder.encode(val, name) do
          {:error, reason} -> {:halt, {"cannot encode element in array", name, reason}}
          encoded -> {:cont, [encoded | bufferAcc]}
        end
      end) do
      {:halted, reason} ->
        {:error, reason}
      {:done, bufferAcc} ->
        <<0x03>> <> name <> <<0x00>> <> (bufferAcc |> Enum.reverse |> IO.iodata_to_binary |> Bson.doc)
    end
  end
end
