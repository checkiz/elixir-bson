defmodule Bson do
  
  def encode(term) do
    <<_::16, doc::binary>> = BsonEncoder.encode(term, "")
    doc
  end

  def tokenize({from, len}, bson), do: BsonTk.tokenize_e_list(bson, from+4, from+len-1)
  def tokenize(bson) do
    sizebson = size(bson)
    cond do
      sizebson < 5 ->
        raise Not_a_valid_bson,
          at: 0,
          msg: "total length of bson document must be at least 5"
      sizebson != int32(bson, 0) ->
        raise Not_a_valid_bson,
          at: 0,
          msg: "total length of bson document does not match document header"
      true ->
        BsonTk.tokenize_e_list(bson, 4, sizebson-1)
    end
  end

  def decode(part, bson), do: tokenize(part, bson) |> Enum.map &(decode_kv(&1, bson))
  def decode(bson), do: tokenize(bson) |> Enum.map &(decode_kv(&1, bson))

  def doc(s),     do: int32(size(s)+5) <> s <> "\x00"
  def string(s),  do: int32(size(s)+1) <> s <> "\x00"
  def int32(i),   do: <<(i)::[size(32),signed,little]>>
  def int64(i),   do: <<(i)::[size(64),signed,little]>>

  def bool(bson, from) do
    case binary_part(bson, from, 1) do
      "\x00" -> false
      "\x01" -> true
    end
  end

  def int32(bson, from) do
    at  = from*8
    <<_::[size(at)], i::[size(32),signed,little], _::binary>> = bson
    i
  end

  def int64(bson, from) do
    at  = from*8
    <<_::[size(at)], i::[size(64),signed,little], _::binary>> = bson
    i
  end

  def float(bson, off) do
    at  = off*8
    <<_::[size(at)], f::[size(64),float,little], _::binary>> = bson
    f
  end

  def peek_cstring_end(bson, from, to) do
    {cstring_end, _} = :binary.match(bson, "\x00", [{:scope, {from, to-from+1}}])
    cstring_end
  end

  def decode_kv({tk_name, tk_element}, bson) do
    { :erlang.binary_part(bson, tk_name) |> binary_to_atom,
      BsonDecoder.decode(tk_element, bson)}
  end
  def decode_v({_, tk_element}, bson) do
    BsonDecoder.decode(tk_element, bson)
  end
end
