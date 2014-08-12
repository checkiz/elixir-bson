defmodule BsonJson do
  @moduledoc """
  Converts a Bson document into a JSON document.

  """

  @doc """
  Returns a json representation of set of Bson documents
  transcodeing the following element type:

  * int32 -> number
  * int64 -> number (capped at js maximum)
  * float -> number
  * string -> string (utf8)
  * document -> object
  * array document -> array
  * objectId -> 24 character length hexadecimal string
  """
  def stringify(bson) do
    case document(bson) do
      {acc, rest} -> {acc|>List.flatten|>IO.iodata_to_binary, rest}
    end
  end
  defp int32(<<i::size(32)-signed-little, rest::binary>>), do: {to_string(i), rest}
  defp int64(<<i::size(64)-signed-little, rest::binary>>), do: {to_string(i), rest}

  defp float(<<0, 0, 0, 0, 0, 0, 248, 127, rest::binary>>), do: {"null", rest} #nan
  defp float(<<0, 0, 0, 0, 0, 0, 248, 255, rest::binary>>), do: {"null", rest} #nan
  defp float(<<0, 0, 0, 0, 0, 0, 240, 127, rest::binary>>), do: {"9007199254740992", rest}  #+inf
  defp float(<<0, 0, 0, 0, 0, 0, 240, 255, rest::binary>>), do: {"-9007199254740992", rest} #-inf
  defp float(<<f::size(64)-float-little, rest::binary>>), do: {to_string(f), rest}

  defp string(<<l::size(32)-signed-little, rest::binary>>) do
    bitsize = (l-1)*8
    <<string::size(bitsize), 0, rest::binary>> = rest
    { [?", <<string::size(bitsize)>>, ?"],
      rest }
  end
  defp objectid(<<oid::96, rest::binary>>) do
    {<<?">> <> (for << <<b::size(4)>> <- <<oid::size(96)>> >>, into: <<>> do
          <<Integer.to_string(b,16)::binary>>
        end |> String.downcase) <> <<?">>, rest}
  end

  defp document(<<l::size(32)-signed-little, rest::binary>>) do
    bitsize = (l-5)*8
    <<bsondoc::size(bitsize), 0, rest::binary>> = rest
    { document(<<bsondoc::size(bitsize)>>, '', '{'), rest}
  end
  defp document("", _, acc), do: Enum.reverse([?}|acc])
  defp document(<<head, rest::binary>>, prefix, acc) do
    {el_name, rest} = peek_cstring(rest, [])
    {el_value, rest} = element(head, rest)
    document(rest, ?,, [el_value, ?:, ?", el_name, ?", prefix | acc])
  end

  defp array(<<l::size(32)-signed-little, rest::binary>>) do
    bitsize = (l-5)*8
    <<bsondoc::size(bitsize), 0, rest::binary>> = rest
    { array(<<bsondoc::size(bitsize)>>, '', [?[]), rest}
  end
  defp array("", _, acc), do: Enum.reverse([?]|acc])
  defp array(<<head, rest::binary>>, prefix, acc) do
    {_, rest} = peek_cstring(rest, [])
    {el_value, rest} = element(head, rest)
    array(rest, ?,, [el_value, prefix | acc])
  end

  defp element(head, bson) do
    case head do
      0x01 -> float(bson)
      0x02 -> string(bson)
      0x03 -> document(bson)
      0x04 -> array(bson)
      0x07 -> objectid(bson)
      0x10 -> int32(bson)
      0x12 -> int64(bson)
    end
  end

  defp peek_cstring(<<0, rest::binary>>, acc), do: {acc|>Enum.reverse|>IO.iodata_to_binary, rest}
  defp peek_cstring(<<c, rest::binary>>, acc), do: peek_cstring(rest, [c|acc])
  defp peek_cstring("", _acc), do: raise "bson corrupted: expecting cstring end mark"
end
