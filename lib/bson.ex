defmodule Bson do
  @moduledoc """
  `Bson` provides encoding and decoding function for Bson format
  see http://bsonspec.org/

  Usage:

  ```elixir
  term = %{
      a:  -4.230845,
      b:  "hello",
      c:  %{x: -1, y: 2.2001},
      d:  [23, 45, 200],
      eeeeeeeee:  Bson.Bin[ subtype: Bson.Bin.subtyx(Binary),
                    bin:  <<200, 12, 240, 129, 100, 90, 56, 198, 34, 0, 0>>],
      f:  Bson.Bin[ subtype: Bson.Bin.subtyx(Function),
                    bin:  <<200, 12, 240, 129, 100, 90, 56, 198, 34, 0, 0>>],
      g:  Bson.Bin[ subtype: Bson.Bin.subtyx(UUID),
                    bin:  <<49, 0, 0, 0, 4, 66, 83, 79, 78, 0, 38, 0, 0, 0,
                            2, 48, 0, 8, 0, 0, 0, 97, 119, 101, 115, 111, 109,
                            101, 0, 1, 49, 0, 51, 51, 51, 51, 51, 51, 20, 64,
                            16, 50, 0, 194, 7, 0, 0, 0, 0>>],
      h:  Bson.Bin[ subtype: Bson.Bin.subtyx(MD5),
                    bin:  <<200, 12, 240, 129, 100, 90, 56, 198, 34, 0, 0>>],
      i:  Bson.Bin[ subtype: Bson.Bin.subtyx(User),
                    bin:  <<49, 0, 0, 0, 4, 66, 83, 79, 78, 0, 38, 0, 0, 0, 2,
                            48, 0, 8, 0, 0, 0, 97, 119, 101, 115, 111, 109, 101,
                            0, 1, 49, 0, 51, 51, 51, 51, 51, 51, 20, 64, 16, 50,
                            0, 194, 7, 0, 0, 0, 0>>],
      j:  Bson.ObjectId[oid: <<82, 224, 229, 161, 0, 0, 2, 0, 3, 0, 0, 4>>],
      k1: false,
      k2: true,
      l:  {1390, 470561, 277000},
      m:  nil,
      n:  Bson.Regex[pattern: "p", opts: "o"],
      o1: Bson.JS[code: "function(x) = x + 1;"],
      o2: Bson.JS[scope: %{x: 0, y: "foo"}, code: "function(a) = a + x"],
      p:  :atom,
      q1: -2000444000,
      q2: -8000111000222001,
      r:  Bson.Timestamp[inc: 1, ts: 2],
      s1: MIN_KEY,
      s2: MAX_KEY
    }
  bson = Bson.encode(term)
  term = Bson.decode(bson)
  ```

  see `encode/1` and `decode/1`

  """
  defrecord ObjectId,
    oid: nil do
    @moduledoc """
    Represents the [MongoDB ObjectId](http://docs.mongodb.org/manual/reference/object-id/)

    * `:oid` - contains a binary size 12
    """
    defimpl Inspect, for: Bson.ObjectId do
      def inspect(Bson.ObjectId[oid: nil],_), do: "ObjectId()"
      def inspect(Bson.ObjectId[oid: oid],_) do
        "ObjectId(" <>
        (bc <<b::4>> inbits oid do
          <<integer_to_binary(b,16)::binary>>
        end |> String.downcase) <> ")"
      end
    end
  end
  defrecord Regex,
    pattern: "",
    opts: "" do
    @moduledoc """
    Represents a Regex 

    * `:pattern` - a bynary that is the regex pattern
    * `:opts` - a bianry that contains the regex options string identified by characters, which must be stored in alphabetical order. Valid options are 'i' for case insensitive matching, 'm' for multiline matching, 'x' for verbose mode, 'l' to make \w, \W, etc. locale dependent, 's' for dotall mode ('.' matches everything), and 'u' to make \w, \W, etc. match unicode
    """
  end
  defrecord JS,
    code: "",
    scope: nil do
    @moduledoc """
    Represents a Javascript function and optionally its scope 

    * `:code` - a bynary that is the function code
    * `:scope` - a Map representing a bson document, the scope of the function
    """
  end
  defrecord Timestamp,
    inc: nil,
    ts: nil do
    @moduledoc """
    Represents the special internal type Timestamp used by MongoDB
    """
  end
  defrecord Bin,
    bin: "",
    subtype: "\x00" do
    @moduledoc """
    Represents Binary data
    """
    @doc """
    Returns the subtype of the bynary data (`Binary` is the default). Other subtypes according to specs are:

    * `Binary` - Binary / Generic
    * `Function` - Function
    * `Binary.Old` - Binary (Old)
    * `UUID.Old` - UUID (Old)
    * `UUID` - UUID
    * `MD5` - MD5
    * `User` - User defined
    """
    def subtyx(Binary),     do: "\x00"
    def subtyx(Function),   do: "\x01"
    def subtyx(Binary.Old), do: "\x02"
    def subtyx(UUID.Old),   do: "\x03"
    def subtyx(UUID),       do: "\x04"
    def subtyx(MD5),        do: "\x05"
    def subtyx(User),       do: <<0x80>>

    @doc """
    Returns the atom coresponding to the subtype of the bynary data
    """
    def xsubty("\x00"),     do: Binary
    def xsubty("\x01"),     do: Function
    def xsubty("\x02"),     do: Binary
    def xsubty("\x03"),     do: UUID
    def xsubty("\x04"),     do: UUID
    def xsubty("\x05"),     do: MD5
    def xsubty(<<0x80>>),   do: User
  end

  @doc """
  Returns a binary representing a Bson document.

  It accepts a Map and returns a binary

  ```elixir
  Bson.encode({}) == <<5, 0, 0, 0, 0>>
  Bson.encode(a: 1) == <<12, 0, 0, 0, 16, 97, 0, 1, 0, 0, 0, 0>>
  Bson.encode(a: 2, b: 2) == <<19, 0, 0, 0, 16, 97, 0, 1, 0, 0, 0, 16, 98, 0, 2, 0, 0, 0, 0>>
  ```

  It delegates this job to protocol `BsonEncoder`

  """
  def encode(term) do
    <<_::16, doc::binary>> = BsonEncoder.encode(term, "")
    doc
  end

  @doc """
  Returns a decoded term from a Bson binary

  see protocol `BsonDecoder`
  """
  def decode(bson), do: tokenize(bson) |> Enum.map(&decode_kv(&1, bson)) |> :maps.from_list
  @doc """
  Same as `decode/1` but will start at a given postion in the binary
  """
  def decode(part, bson), do: tokenize(part, bson) |> Enum.map &(decode_kv(&1, bson))

  @doc """
  Returns tokens of the Bson document (no decoding)
  """
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

  @doc """
  Same as `tokenize/1` but will start at a given postion in the binary
  """
  def tokenize({from, len}, bson), do: BsonTk.tokenize_e_list(bson, from+4, from+len-1)

  @doc """
  Formats a bson document using the document strings (add size and trailing null character)
  """
  def doc(s),     do: int32(size(s)+5) <> s <> "\x00"

  @doc """
  Formats a bson string using the document strings (add size and trailing null character)
  """
  def string(s),  do: int32(size(s)+1) <> s <> "\x00"

  @doc """
  Formats a integer in a int32 binary
  """
  def int32(i),   do: <<(i)::[size(32),signed,little]>>

  @doc """
  Formats a integer in a int64 binary
  """
  def int64(i),   do: <<(i)::[size(64),signed,little]>>

  @doc """
  Formats true or false
  """
  def bool(bson, from) do
    case binary_part(bson, from, 1) do
      "\x00" -> false
      "\x01" -> true
    end
  end

  @doc """
  Decodes an integer (int32) from a binary at a given position
  """
  def int32(bson, from) do
    at  = from*8
    <<_::[size(at)], i::[size(32),signed,little], _::binary>> = bson
    i
  end

  @doc """
  Decodes an integer (int64) from a binary at a given position
  """
  def int64(bson, from) do
    at  = from*8
    <<_::[size(at)], i::[size(64),signed,little], _::binary>> = bson
    i
  end

  @doc """
  Decodes a float from a binary at a given position. It will decode atoms nan, +inf and -inf as floats
  """
  def float(bson, off) do
    case binary_part(bson, off, 8) do
      <<0, 0, 0, 0, 0, 0, 248, 127>> -> :nan
      <<0, 0, 0, 0, 0, 0, 248, 255>> -> :nan
      <<0, 0, 0, 0, 0, 0, 240, 127>> -> :'+inf'
      <<0, 0, 0, 0, 0, 0, 240, 255>> -> :'-inf'
      <<f::[size(64),float,little]>> -> f
    end
  end

  @doc """
  Peeks for the end of a cstring
  """
  def peek_cstring_end(bson, from, to) do
    {cstring_end, _} = :binary.match(bson, "\x00", [{:scope, {from, to-from+1}}])
    cstring_end
  end

  @doc """
  Decodes a key-value pair (one element of a document)
  """
  def decode_kv({tk_name, tk_element}, bson) do
    { :erlang.binary_part(bson, tk_name) |> binary_to_atom,
      BsonDecoder.decode(tk_element, bson)}
  end

  @doc """
  Decodes one array item. Here the name token is not decoded, it contains the position of the item in the list.
  """
  def decode_v({_, tk_element}, bson) do
    BsonDecoder.decode(tk_element, bson)
  end
end
