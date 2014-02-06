defmodule BsonTk do
  @moduledoc """
  `BsonTk` tokenize a bson document see tokenize/1 in module `Bson`
  """

  defrecord Int32,     part: nil
  defrecord Int64,     part: nil
  defrecord Float,     part: nil
  defrecord Doc,       part: nil
  defrecord Array,     part: nil
  defrecord String,    part: nil
  defrecord Atom,      part: nil
  defrecord Bool,      part: nil
  defrecord ObjectId,  part: nil
  defrecord Bin,       part: nil, subtype: nil
  defrecord Regex,     pattern: nil, opts: nil
  defrecord JS,        code: nil, scope: nil
  defrecord Now,       part: nil
  defrecord Timestamp, inc: nil, ts: nil

  @doc """
  tokenize one element, this is a key-value pair, of a bson document starting at position `from`.

  It returns {{`tk_name`, `tk_element`}, `tk_end} where:

  * `tk_name` - is the token of the element name (binary part {from, to})
  * `tk_element` - is the token of the element value
  * `tk_end` - is the end position of the element
  """
  def tokenize(bson, from, to) do
    name_end = Bson.peek_cstring_end(bson, from+1, to)
    tk_name = {from+1, name_end-(from+1)}
    tk_head = binary_part(bson, from, 1)
    {tk_element, tk_end} = tokenize_element(tk_head, bson, name_end+1)
    {{tk_name, tk_element}, tk_end}
  end

  @doc """
  tokenize one element value of bson starting at position 'from'. Tag identifies the element type to decode.

  It returns {`tk_element`, `tk_end`} where:

  * `tk_element` - is the token of the element value. It can be an atom `nil`, `MIN_KEY`, `MAX_KEY`
  or a record
  (`BsonTk.Int32`, `BsonTk.Int64`, `BsonTk.Float`, `BsonTk.Doc`, `BsonTk.Array`, `BsonTk.String`, `BsonTk.Atom`,
  `BsonTk.Bool`, `BsonTk.ObjectId`, `BsonTk.Bin`, `BsonTk.Regex`, `BsonTk.JS`, `BsonTk.Now`, `BsonTk.Timestamp`)
  * `tk_end` - is the end position of the element
  """
  def tokenize_element("\x10", _, from), do: {{BsonTk.Int32, {from, 4}}, from+4}
  def tokenize_element("\x12", _, from), do: {{BsonTk.Int64, {from, 8}}, from+8}
  def tokenize_element("\x01", _, from), do: {{BsonTk.Float, {from, 8}}, from+8}
  def tokenize_element("\x07", _, from), do: {BsonTk.ObjectId[part: {from, 12}], from+12}
  def tokenize_element("\x08", _, from), do: {{BsonTk.Bool , {from, 1}}, from+1}
  def tokenize_element("\x09", _, from), do: {{BsonTk.Now  , {from, 8}}, from+8}
  def tokenize_element("\x06", _, from), do: {nil, from+0}
  def tokenize_element("\x0a", _, from), do: {nil, from+0}
  def tokenize_element("\x11", _, from), do: {BsonTk.Timestamp[inc: {from, 4}, ts: {from+4, 4}], from+8}
  def tokenize_element(<<0xff>>, _, from), do: {MIN_KEY, from+0}
  def tokenize_element("\x7f", _, from), do: {MAX_KEY, from+0}

  # string
  def tokenize_element("\x02", bson, from) do
    len = Bson.int32(bson, from)-1
    {{BsonTk.String, {from+4, len}}, from+len+4+1}
  end

  # atom
  def tokenize_element("\x0e", bson, from) do
    len = Bson.int32(bson, from)-1
    {{BsonTk.Atom, {from+4, len}}, from+len+4+1}
  end

  # document
  def tokenize_element("\x03", bson, from) do
    len = Bson.int32(bson, from)-5
    {{BsonTk.Doc, {from+4, len}}, from+len+4+1}
  end

  # array
  def tokenize_element("\x04", bson, from) do
    len = Bson.int32(bson, from)-5
    {{BsonTk.Array, {from+4, len}}, from+len+4+1}
  end

  # regex
  def tokenize_element("\x0b", bson, from) do
    BsonTk.Regex[]
    to = size(bson) -1
    patternend = Bson.peek_cstring_end(bson, from, to)
    optsend = Bson.peek_cstring_end(bson, patternend+1, to)
    {BsonTk.Regex[pattern: {from, patternend-from}, opts: {patternend+1, optsend-(patternend+1)}], optsend+1}
  end
  # javascript
  def tokenize_element("\x0d", bson, from) do
    len = Bson.int32(bson, from)-1
    {BsonTk.JS[code: {from+4, len}], from+len+4+1}
  end
  # javascript with scope
  def tokenize_element("\x0f", bson, code_ws_from) do
    # code_ws_len = Bson.int32(bson, code_ws_from)-1    #code_w_s length
    codefrom = code_ws_from+4
    codelen = Bson.int32(bson, codefrom)-1    #string length
    scopefrom = codefrom+4+codelen+1
    scopelen = Bson.int32(bson, scopefrom)-5  #doc length
    {BsonTk.JS[code: {codefrom+4, codelen}, scope: {scopefrom+4, scopelen}], scopefrom+scopelen+4+1}
  end
  # binary
  def tokenize_element("\x05", bson, from) do
    len = Bson.int32(bson, from)
    {BsonTk.Bin[part: {from+5, len}, subtype: binary_part(bson, from+4, 1)], from+len+5}
  end
  # binary
  def tokenize_element(tag, _, _), do: raise "unsupported tag (" <> tag <> ")"

  @doc """
  Tokenize elements of a bson document (e_list in the spec)
  """
  def tokenize_e_list(bson, from, to), do: tokenize_e_list(bson, from, to, [])
  defp tokenize_e_list(_bson, from, from, acc), do: acc |> Enum.reverse
  defp tokenize_e_list(bson, from, to, acc) do
    {tk, tk_end} = tokenize(bson, from, to)
    tokenize_e_list(bson, tk_end, to, [tk | acc])
  end

end