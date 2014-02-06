defprotocol BsonEncoder do
  @moduledoc """
  `BsonEncoder` protocol defines Bson encoding according to Elixir types or Bson specific record (see `Bson`).

  List of the protocol implementations:

  * `Integer` - Encodes integer in 32 or 64 bits
  * `Float` - Encodes float in 64 bits
  * `Atom` - Encodes special atom (`false`, `true`, `nil`, 
  `:nan`, `:+inf`, `:-inf`, `MIN_KEY` and `MAX_KEY`) in appropriate format 
  others in special type Symbol
  * `Tuple` - Encodes the empty document `{}` and the return of `now/1`
  * `BitString` - as binary string
  * `List` - Encodes a `Keyword` list as a document and any other list as array
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

  def encode(i, name), do: pre(i) <> name <> "\x00" <> int(i)

  defp int(i) when -0x80000000 <= i and i <= 0x80000000, do: Bson.int32(i)
  defp int(i) when -0x8000000000000000 <= i and i <= 0x8000000000000000, do: Bson.int64(i)

  defp pre(i) when -0x80000000 <= i and i <= 0x80000000, do: "\x10"
  defp pre(i) when -0x8000000000000000 <= i and i <= 0x8000000000000000, do: "\x12"
end

defimpl BsonEncoder, for: Float do
  def encode(f, name), do: "\x01" <> name <> "\x00" <> float(f)

  defp float(f),   do: <<(f)::[size(64),float,little]>>
end

defimpl BsonEncoder, for: Atom do
  # encode pair where value is an atom
  def encode(false, name),   do: "\x08" <> name <> "\x00" <> "\x00"
  def encode(true, name),    do: "\x08" <> name <> "\x00" <> "\x01"
  def encode(nil, name),     do: "\x0a" <> name <> "\x00"
  def encode(:nan, name),    do: "\x01" <> name <> "\x00" <> <<0, 0, 0, 0, 0, 0, 248, 127>>
  def encode(:'+inf', name), do: "\x01" <> name <> "\x00" <> <<0, 0, 0, 0, 0, 0, 240, 127>>
  def encode(:'-inf', name), do: "\x01" <> name <> "\x00" <> <<0, 0, 0, 0, 0, 0, 240, 255>>
  def encode(MIN_KEY, name), do: <<0xff>> <> name <> "\x00"
  def encode(MAX_KEY, name), do: "\x7f" <> name <> "\x00"
  def encode(atom, name),    do: "\x0e" <> name <> "\x00" <> Bson.string(atom_to_binary(atom))
end

defimpl BsonEncoder, for: Bson.Regex do
  def encode(Bson.Regex[pattern: p, opts: o], name) when is_binary(p) and is_binary(o) do
    "\x0b" <> name <> "\x00" <> p <> "\x00" <> o <> "\x00"
  end
end

defimpl BsonEncoder, for: Bson.ObjectId do
  def encode(Bson.ObjectId[oid: oid], name) when is_binary(oid) do
    "\x07" <> name <> "\x00" <> oid
  end
end

defimpl BsonEncoder, for: Bson.JS do
  def encode(Bson.JS[code: js, scope: nil], name) when is_binary(js) do
    "\x0d" <> name <> "\x00" <> Bson.string(js)
  end
  def encode(Bson.JS[code: js, scope: ctx], name) when is_binary(js) and is_list(ctx) do
    "\x0f" <> name <> "\x00" <> js_ctx(Bson.string(js) <> BsonEncoder.List.encode_e_list(ctx))
  end

  defp js_ctx(jsctx), do: Bson.int32(size(jsctx)+4) <> jsctx
end

defimpl BsonEncoder, for: Bson.Bin do
  def encode(Bson.Bin[bin: bin, subtype: subtype], name), do:  "\x05" <> name <> "\x00" <> Bson.int32(size(bin)) <> subtype <> bin
end

defimpl BsonEncoder, for: Bson.Timestamp do
  def encode(Bson.Timestamp[inc: i, ts: t], name),        do:  "\x11" <> name <> "\x00" <> Bson.int32(i) <> Bson.int32(t)
end

defimpl BsonEncoder, for: Tuple do
  defexception Error, reason: nil do
    @moduledoc """
    Only 2 tuple formats can be encoded. An empty tuple and the one given by now/0
    """
    def message(Error[reason: reason]) do
      reason
    end
  end
  def encode({}, name),         do:  "\x03" <> name <> "\x00" <> Bson.doc(<<>>)
  def encode({a, s, o}, name) when is_integer(a) and is_integer(s) and is_integer(o) do
    "\x09" <> name <> "\x00" <> Bson.int64(a * 1000000000 + s * 1000 + div(o, 1000))
  end
  def encode(t, name) do
    raise Error, reason: "cannot encode tuple of size " <> to_string(size(t)) <> " (" <> name <> ")"
  end
end

defimpl BsonEncoder, for: BitString do
  def encode(s, name) when is_binary(s),  do: "\x02" <> name <> "\x00" <> Bson.string(s)
end

defimpl BsonEncoder, for: List do
  defexception Error, reason: nil do
    @moduledoc """
    Only Keyword list or list of terms that can be encoded. If a list starts with key-value tuple it is assumed to be a Keyword List.
    """
    def message(Error[reason: reason]) do
      reason
    end
  end
  # def encode([], name),                  do:  "\x03" <> name <> "\x00" <> Bson.doc(<<>>)
  def encode([{k,_}|_] = kw, name) when is_atom(k) and k != Bson.ObjectId do
    "\x03" <> name <> "\x00" <> encode_e_list(kw)
  end
  def encode(array, name) when is_list(array) do
    "\x04" <> name <> "\x00" <> encode_array(array)
  end

  def encode_e_list(keyword) do
    keyword
      |> Enum.reduce([], &(reduce_kv_pair/2))
      |> bitlist_to_bsondoc
  end
  defp reduce_kv_pair({k, v}, acc) when is_atom(k), do: [BsonEncoder.encode(v, k |> atom_to_binary)|acc]
  defp reduce_kv_pair(item, _) do
    case item do
      {k, _} ->
        raise Error, reason: to_string(k) <> "key is not an atom (in a list that looks like a Keyword)"
      _ ->
        raise Error, reason: "cannot encode an item that is not a key-value pair (in a list that looks like a Keyword)"
    end
  end

  defp encode_array(arr) do
    {_, arrbin } = arr
      |> Enum.reduce({0, []}, fn(item, {n, acc}) ->
          {n+1, [BsonEncoder.encode(item, n |> integer_to_binary) | acc]}
        end)
    arrbin |> bitlist_to_bsondoc
  end

  defp bitlist_to_bsondoc(arrbin), do: arrbin |> Enum.reverse |> iolist_to_binary |> Bson.doc

end
