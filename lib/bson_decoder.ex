defprotocol BsonDecoder do
  @moduledoc """
  Similarly to `BsonEncoder`, this protocol defines decoding of chunks of Bson document.
  Chunks are identified by tokens and isolate an element of a Bson document.

  There is one implementation of the protocol for every record defined in `BsonTk`

  """

  @doc """
  Returns a elixir term decoded from a chunk of a Bson document.

  """
  def decode(token, bson)
end

defimpl BsonDecoder, for: BsonTk.Int32 do
  def decode(BsonTk.Int32[part: {from, _}], bson), do: Bson.int32(bson, from)
end

defimpl BsonDecoder, for: BsonTk.Int64 do
  def decode(BsonTk.Int64[part: {from, _}], bson), do: Bson.int64(bson, from)
end

defimpl BsonDecoder, for: BsonTk.String do
  def decode(BsonTk.String[part: part], bson), do: :erlang.binary_part(bson, part)
end

defimpl BsonDecoder, for: BsonTk.Atom do
  def decode(BsonTk.Atom[part: part], bson), do: :erlang.binary_part(bson, part) |> binary_to_atom
end

defimpl BsonDecoder, for: BsonTk.Float do
  def decode(BsonTk.Float[part: {from, _}], bson), do: Bson.float(bson, from)
end

defimpl BsonDecoder, for: BsonTk.Bool do
  def decode(BsonTk.Bool[part:  {from, _}], bson), do: Bson.bool(bson, from)
end

defimpl BsonDecoder, for: BsonTk.Doc do
  def decode(BsonTk.Doc[part: {from, len}], bson) do
    BsonTk.tokenize_e_list(bson, from, from+len)
      |> Enum.map &(Bson.decode_kv(&1, bson))
  end
end

defimpl BsonDecoder, for: BsonTk.Array do
  def decode(BsonTk.Array[part: {from, len}], bson) do
    BsonTk.tokenize_e_list(bson, from, from+len)
      |> Enum.map &(Bson.decode_v(&1, bson))
  end
end

defimpl BsonDecoder, for: Atom do
  def decode(nil, _bson)                         , do: nil
  def decode(MIN_KEY, _bson)                     , do: MIN_KEY
  def decode(MAX_KEY, _bson)                     , do: MAX_KEY
end

defimpl BsonDecoder, for: BsonTk.ObjectId do
  def decode(oid, bson) do
    Bson.ObjectId[oid: :erlang.binary_part(bson, oid.part)]
  end
end

defimpl BsonDecoder, for: BsonTk.Bin do
  def decode(bin, bson) do
    Bson.Bin[bin: :erlang.binary_part(bson, bin.part), subtype: bin.subtype]
  end
end

defimpl BsonDecoder, for: BsonTk.Regex do
  def decode(regex, bson) do
    Bson.Regex[pattern: :erlang.binary_part(bson, regex.pattern), opts: :erlang.binary_part(bson, regex.opts)]
  end
end

defimpl BsonDecoder, for: BsonTk.JS do
  def decode(js, bson) do

    Bson.JS[code: :erlang.binary_part(bson, js.code), scope:
      case js.scope do
        nil -> nil
        part -> BsonDecoder.BsonTk.Doc.decode(BsonTk.Doc[part: part], bson)
      end]
  end
end

defimpl BsonDecoder, for: BsonTk.Timestamp do
  def decode(BsonTk.Timestamp[inc: {inc_from, _}, ts: {ts_from, _}], bson) do
    Bson.Timestamp[inc: Bson.int32(bson, inc_from), ts: Bson.int32(bson, ts_from)]
  end
end

defimpl BsonDecoder, for: BsonTk.Now do
  def decode(BsonTk.Now[part: {from, _}], bson) do
    ms = Bson.int64(bson, from)
    {div(ms, 1000000000), rem(div(ms, 1000), 1000000), rem(ms * 1000, 1000000)}
  end
end