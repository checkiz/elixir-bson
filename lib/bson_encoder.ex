defrecord Bson.ObjectId, oid: nil, nop: nil
defrecord Bson.Regex, pattern: "", opts: ""
defrecord Bson.JS, code: "", scope: []
defrecord Bson.Timestamp, inc: nil, ts: nil
defrecord Bson.Bin, bin: "", subtype: "\x00" do
  def subtyx(Binary),     do: "\x00"
  def subtyx(Function),   do: "\x01"
  def subtyx(Binary.Old), do: "\x02"
  def subtyx(UUID.Old),   do: "\x03"
  def subtyx(UUID),       do: "\x04"
  def subtyx(MD5),        do: "\x05"
  def subtyx(User),       do: <<0x80>>
  def xsubty("\x00"),     do: Binary
  def xsubty("\x01"),     do: Function
  def xsubty("\x02"),     do: Binary
  def xsubty("\x03"),     do: UUID
  def xsubty("\x04"),     do: UUID
  def xsubty("\x05"),     do: MD5
  def xsubty(<<0x80>>),   do: User
end

defprotocol BsonEncoder do
  def encode(term, name)
end

defimpl BsonEncoder, for: Integer do
  def encode(i, name), do: pre(i) <> name <> "\x00" <> int(i)

  def int(i) when -0x80000000 <= i and i <= 0x80000000, do: Bson.int32(i)
  def int(i) when -0x8000000000000000 <= i and i <= 0x8000000000000000, do: Bson.int64(i)

  defp pre(i) when -0x80000000 <= i and i <= 0x80000000, do: "\x10"
  defp pre(i) when -0x8000000000000000 <= i and i <= 0x8000000000000000, do: "\x12"
end

defimpl BsonEncoder, for: Float do
  def encode(f, name), do: "\x01" <> name <> "\x00" <> float(f)

  def float(f),   do: <<(f)::[size(64),float,little]>>
end

defimpl BsonEncoder, for: Atom do
  # encode pair where value is an atom
  def encode(false, name),   do: "\x08" <> name <> "\x00" <> "\x00"
  def encode(true, name),    do: "\x08" <> name <> "\x00" <> "\x01"
  def encode(nil, name),     do: "\x0a" <> name <> "\x00"
  def encode(MIN_KEY, name), do: <<0xff>> <> name <> "\x00"
  def encode(MAX_KEY, name), do: "\x7f" <> name <> "\x00"
  def encode(atom, name),    do: "\x0e" <> name <> "\x00" <> Bson.string(atom_to_binary(atom))
end

defimpl BsonEncoder, for: Bson.Regex do
  def encode(Bson.Regex[pattern: p, opts: o], name),      do:  "\x0b" <> name <> "\x00" <> p <> "\x00" <> o <> "\x00"
end

defimpl BsonEncoder, for: Bson.ObjectId do
  def encode(Bson.ObjectId[oid: oid], name),              do:  "\x07" <> name <> "\x00" <> oid
end

defimpl BsonEncoder, for: Bson.JS do
  def encode(Bson.JS[code: js, scope: []], name),        do:  "\x0d" <> name <> "\x00" <> Bson.string(js)
  def encode(Bson.JS[code: js, scope: ctx], name),        do:  "\x0f" <> name <> "\x00" <> js_ctx(Bson.string(js) <> BsonEncoder.List.encode_e_list(ctx))

  defp js_ctx(jsctx), do: Bson.int32(size(jsctx)+4) <> jsctx
end

defimpl BsonEncoder, for: Bson.Bin do
  def encode(Bson.Bin[bin: bin, subtype: subtype], name), do:  "\x05" <> name <> "\x00" <> Bson.int32(size(bin)) <> subtype <> bin
end

defimpl BsonEncoder, for: Bson.Timestamp do
  def encode(Bson.Timestamp[inc: i, ts: t], name),        do:  "\x11" <> name <> "\x00" <> Bson.int32(i) <> Bson.int32(t)
end

defimpl BsonEncoder, for: Tuple do
  def encode({}, name),         do:  "\x03" <> name <> "\x00" <> Bson.doc(<<>>)
  def encode({a, s, o}, name),  do:  "\x09" <> name <> "\x00" <> Bson.int64(a * 1000000000 + s * 1000 + div(o, 1000))
end

defimpl BsonEncoder, for: BitString do
  def encode(s, name) when is_binary(s),  do: "\x02" <> name <> "\x00" <> Bson.string(s)
end

defimpl BsonEncoder, for: List do
  # def encode([], name),                  do:  "\x03" <> name <> "\x00" <> Bson.doc(<<>>)
  def encode([{k,_}|_] = kw, name) when is_atom(k) do
    "\x03" <> name <> "\x00" <> encode_e_list(kw)
  end
  def encode(array, name) when is_list(array) do
    "\x04" <> name <> "\x00" <> encode_array(array)
  end

  def encode_e_list(keyword) do
    keyword
      |> Enum.reduce([], fn({k,v}, acc) -> [BsonEncoder.encode(v, k |> atom_to_binary) | acc] end)
      |> docbits
  end

  defp encode_array(arr) do
    {_, arrbin } = arr
      |> Enum.reduce({0, []}, fn(item, {n, acc}) ->
          {n+1, [BsonEncoder.encode(item, n |> integer_to_binary) | acc]}
        end)
    arrbin |> docbits
  end

  defp docbits(arrbin), do: arrbin |> Enum.reverse |> iolist_to_binary |> Bson.doc

end
