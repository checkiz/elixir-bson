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

  def encode(i, name), do: pre(i) <> name <> <<0x00>> <> int(i)

  defp int(i) when -0x80000000 <= i and i <= 0x80000000, do: Bson.int32(i)
  defp int(i) when -0x8000000000000000 <= i and i <= 0x8000000000000000, do: Bson.int64(i)

  defp pre(i) when -0x80000000 <= i and i <= 0x80000000, do: <<0x10>>
  defp pre(i) when -0x8000000000000000 <= i and i <= 0x8000000000000000, do: <<0x12>>
end

defimpl BsonEncoder, for: Float do
  def encode(f, name), do: <<0x01>> <> name <> <<0x00>> <> float(f)

  defp float(f),   do: <<(f)::size(64)-float-little>>
end

defimpl BsonEncoder, for: Atom do
  # encode pair where value is an atom
  def encode(false, name),   do: <<0x08>> <> name <> <<0x00>> <> <<0x00>>
  def encode(true, name),    do: <<0x08>> <> name <> <<0x00>> <> <<0x01>>
  def encode(nil, name),     do: <<0x0a>> <> name <> <<0x00>>
  def encode(:nan, name),    do: <<0x01>> <> name <> <<0x00>> <> <<0, 0, 0, 0, 0, 0, 248, 127>>
  def encode(:'+inf', name), do: <<0x01>> <> name <> <<0x00>> <> <<0, 0, 0, 0, 0, 0, 240, 127>>
  def encode(:'-inf', name), do: <<0x01>> <> name <> <<0x00>> <> <<0, 0, 0, 0, 0, 0, 240, 255>>
  def encode(MIN_KEY, name), do: <<0xff>> <> name <> <<0x00>>
  def encode(MAX_KEY, name), do: <<0x7f>> <> name <> <<0x00>>
  def encode(atom, name),    do: <<0x0e>> <> name <> <<0x00>> <> Bson.string(Atom.to_string(atom))
end

defimpl BsonEncoder, for: Regex do
  def encode(regex, name), do: <<0x0b>> <> name <> <<0x00>> <> regex.source <> <<0x00>> <> regex.opts <> <<0x00>>
end

defimpl BsonEncoder, for: Bson.ObjectId do
  def encode(%Bson.ObjectId{oid: oid}, name) when is_binary(oid) do
    <<0x07>> <> name <> <<0x00>> <> oid
  end
end

defimpl BsonEncoder, for: Bson.JS do
  def encode(%Bson.JS{code: js, scope: nil}, name) when is_binary(js) do
    <<0x0d>> <> name <> <<0x00>> <> Bson.string(js)
  end
  def encode(%Bson.JS{code: js, scope: ctx}, name) when is_binary(js) and is_map(ctx) do
    <<0x0f>> <> name <> <<0x00>> <> js_ctx(Bson.string(js) <> BsonEncoder.Map.encode_e_list(ctx))
  end

  defp js_ctx(jsctx), do: Bson.int32(byte_size(jsctx)+4) <> jsctx
end

defimpl BsonEncoder, for: Bson.Bin do
  def encode(%Bson.Bin{bin: bin, subtype: subtype}, name), do:  <<0x05>> <> name <> <<0x00>> <> Bson.int32(byte_size(bin)) <> subtype <> bin
end

defimpl BsonEncoder, for: Bson.Timestamp do
  def encode(%Bson.Timestamp{inc: i, ts: t}, name),        do:  <<0x11>> <> name <> <<0x00>> <> Bson.int32(i) <> Bson.int32(t)
end

defimpl BsonEncoder, for: BitString do
  def encode(s, name) when is_binary(s),  do: <<0x02>> <> name <> <<0x00>> <> Bson.string(s)
end

defimpl BsonEncoder, for: List do
  # def encode([], name),                  do:  <<0x03>> <> name <> <<0x00>> <> Bson.doc(<<>>)
  def encode(array, name) when is_list(array) do
    <<0x04>> <> name <> <<0x00>> <> encode_array(array)
  end

  defp encode_array(arr) do
    {_, arrbin } = arr
      |> Enum.reduce({0, []}, fn(item, {n, acc}) ->
          {n+1, [BsonEncoder.encode(item, n |> Integer.to_string) | acc]}
        end)
    arrbin |> bitlist_to_bsondoc
  end

  defp bitlist_to_bsondoc(arrbin), do: arrbin |> Enum.reverse |> IO.iodata_to_binary |> Bson.doc

end

defimpl BsonEncoder, for: Map do
  # def encode(%{}, name),                  do:  <<0x03>> <> name <> <<0x00>> <> Bson.doc(<<>>)
  def encode(map, name) do
    <<0x03>> <> name <> <<0x00>> <> encode_e_list(map)
  end

  @doc """
  encode e_list, this is, concatenation of encoded element
  """
  def encode_e_list(map) do
    :maps.fold( fn
      k, v, acc when is_atom(k) -> [BsonEncoder.encode(v, k |> Atom.to_string)|acc]
      k, v, acc -> [BsonEncoder.encode(v, Bson.encode(k))|acc]
    end, [], map)
      |> bitlist_to_bsondoc
  end

  defp bitlist_to_bsondoc(arrbin), do: arrbin |> Enum.reverse |> IO.iodata_to_binary |> Bson.doc

end

defimpl BsonEncoder, for: Any do
  def encode(%{__struct__: _struct}=map, name) do
    <<0x03>> <> name <> <<0x00>> <> BsonEncoder.Map.encode_e_list(map)
  end
end
