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
        eeeeeeeee:  %Bson.Bin{ subtype: Bson.Bin.subtyx(Binary),
                      bin:  <<200, 12, 240, 129, 100, 90, 56, 198, 34, 0, 0>>},
        f:  %Bson.Bin{ subtype: Bson.Bin.subtyx(Function),
                      bin:  <<200, 12, 240, 129, 100, 90, 56, 198, 34, 0, 0>>},
        g:  %Bson.Bin{ subtype: Bson.Bin.subtyx(UUID),
                      bin:  <<49, 0, 0, 0, 4, 66, 83, 79, 78, 0, 38, 0, 0, 0,
                              2, 48, 0, 8, 0, 0, 0, 97, 119, 101, 115, 111, 109,
                              101, 0, 1, 49, 0, 51, 51, 51, 51, 51, 51, 20, 64,
                              16, 50, 0, 194, 7, 0, 0, 0, 0>>},
        h:  %Bson.Bin{ subtype: Bson.Bin.subtyx(MD5),
                      bin:  <<200, 12, 240, 129, 100, 90, 56, 198, 34, 0, 0>>},
        i:  %Bson.Bin{ subtype: Bson.Bin.subtyx(User),
                      bin:  <<49, 0, 0, 0, 4, 66, 83, 79, 78, 0, 38, 0, 0, 0, 2,
                              48, 0, 8, 0, 0, 0, 97, 119, 101, 115, 111, 109, 101,
                              0, 1, 49, 0, 51, 51, 51, 51, 51, 51, 20, 64, 16, 50,
                              0, 194, 7, 0, 0, 0, 0>>},
        j:  %Bson.ObjectId{oid: <<82, 224, 229, 161, 0, 0, 2, 0, 3, 0, 0, 4>>},
        k1: false,
        k2: true,
        l:  {1390, 470561, 277000},
        m:  nil,
        n:  %Bson.Regex{pattern: "p", opts: "o"},
        o1: %Bson.JS{code: "function(x) = x + 1;"},
        o2: %Bson.JS{scope: %{x: 0, y: "foo"}, code: "function(a) = a + x"},
        p:  :atom,
        q1: -2000444000,
        q2: -8000111000222001,
        r:  %Bson.Timestamp{inc: 1, ts: 2},
        s1: MIN_KEY,
        s2: MAX_KEY
      }
    bson =
    <<188,1,0,0,1,97,0,206,199,181,161,98,236,16,192,2,98,0,6,0,0,0,104,101,108,108,111,0,3,99,0,23,0,0,0,16,120,0,255,
    255,255,255,1,121,0,210,111,95,7,206,153,1,64,0,4,100,0,26,0,0,0,16,48,0,23,0,0,0,16,49,0,45,0,0,0,16,50,0,200,0,
    0,0,0,5,101,101,101,101,101,101,101,101,101,0,11,0,0,0,0,200,12,240,129,100,90,56,198,34,0,0,5,102,0,11,0,0,0,1,
    200,12,240,129,100,90,56,198,34,0,0,5,103,0,49,0,0,0,4,49,0,0,0,4,66,83,79,78,0,38,0,0,0,2,48,0,8,0,0,0,97,119,101,
    115,111,109,101,0,1,49,0,51,51,51,51,51,51,20,64,16,50,0,194,7,0,0,0,0,5,104,0,11,0,0,0,5,200,12,240,129,100,90,56,
    198,34,0,0,5,105,0,49,0,0,0,128,49,0,0,0,4,66,83,79,78,0,38,0,0,0,2,48,0,8,0,0,0,97,119,101,115,111,109,101,0,1,49,
    0,51,51,51,51,51,51,20,64,16,50,0,194,7,0,0,0,0,7,106,0,82,224,229,161,0,0,2,0,3,0,0,4,8,107,49,0,0,8,107,50,0,1,9,
    108,0,253,253,128,190,67,1,0,0,10,109,0,11,110,0,112,0,111,0,13,111,49,0,21,0,0,0,102,117,110,99,116,105,111,110,40,
    120,41,32,61,32,120,32,43,32,49,59,0,15,111,50,0,51,0,0,0,20,0,0,0,102,117,110,99,116,105,111,110,40,97,41,32,61,32,
    97,32,43,32,120,0,23,0,0,0,16,120,0,0,0,0,0,2,121,0,4,0,0,0,102,111,111,0,0,14,112,0,5,0,0,0,97,116,111,109,0,16,113,
    49,0,160,165,195,136,18,113,50,0,207,6,171,1,241,147,227,255,17,114,0,1,0,0,0,2,0,0,0,255,115,49,0,127,115,50,0,0>>

    assert Bson.encode(term) == bson
    assert term == Bson.decode(bson)
  ```

  see `encode/1` and `decode/1`

  """
  defmodule ObjectId do
    defstruct oid: nil
    @moduledoc """
    Represents the [MongoDB ObjectId](http://docs.mongodb.org/manual/reference/object-id/)

    * `:oid` - contains a binary size 12
    """
  end
    defimpl Inspect, for: Bson.ObjectId do
      def inspect(%Bson.ObjectId{oid: nil},_), do: "ObjectId()"
      def inspect(%Bson.ObjectId{oid: oid},_) do
        "ObjectId(" <>
        (for <<b::4<-oid>>, into: <<>> do
          <<Integer.to_string(b,16)::binary>>
        end |> String.downcase) <> ")"
      end
    end
  defmodule JS do
    defstruct code: "", scope: nil
    @moduledoc """
    Represents a Javascript function and optionally its scope

    * `:code` - a bynary that is the function code
    * `:scope` - a Map representing a bson document, the scope of the function
    """
  end
  defmodule Timestamp do
    defstruct inc: nil, ts: nil
    @moduledoc """
    Represents the special internal type Timestamp used by MongoDB
    """
  end
  defmodule Bin do
    defstruct bin: "", subtype: <<0x00>>
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
    def subtyx(Binary),     do: <<0x00>>
    def subtyx(Function),   do: <<0x01>>
    def subtyx(Binary.Old), do: <<0x02>>
    def subtyx(UUID.Old),   do: <<0x03>>
    def subtyx(UUID),       do: <<0x04>>
    def subtyx(MD5),        do: <<0x05>>
    def subtyx(User),       do: <<0x80>>

    @doc """
    Returns the atom coresponding to the subtype of the bynary data
    """
    def xsubty(<<0x00>>),     do: Binary
    def xsubty(<<0x01>>),     do: Function
    def xsubty(<<0x02>>),     do: Binary
    def xsubty(<<0x03>>),     do: UUID
    def xsubty(<<0x04>>),     do: UUID
    def xsubty(<<0x05>>),     do: MD5
    def xsubty(<<0x80>>),     do: User
  end

  @doc """
  Returns a binary representing a Bson document.

  It accepts a Map and returns a binary

  ```elixir
    iex> Bson.encode(%{})
    <<5, 0, 0, 0, 0>>
    iex> Bson.encode(%{a: 1})
    <<12, 0, 0, 0, 16, 97, 0, 1, 0, 0, 0, 0>>
    iex> Bson.encode(%{a: 1, b: 2})
    <<19, 0, 0, 0, 16, 97, 0, 1, 0, 0, 0, 16, 98, 0, 2, 0, 0, 0, 0>>

  ```

  It delegates this job to protocol `BsonEncoder`

  """
  def encode(term) do
    <<_::16, doc::binary>> = BsonEncoder.encode(term, "")
    doc
  end

  @doc """
  Returns a decoded term from a Bson binary


  ```elixir
    iex> %{} |> Bson.encode |> Bson.decode
    %{}
    iex> %{a: 1} |> Bson.encode |> Bson.decode
    %{a: 1}
    iex> %{a: 1, b: 2} |> Bson.encode |> Bson.decode
    %{a: 1, b: 2}

  ```
  see protocol `BsonDecoder`
  """
  def decode(bson), do: tokenize(bson) |> Enum.map(&decode_kv(&1, bson)) |> :maps.from_list
  @doc """
  Same as `decode/1` but will start at a given postion in the binary
  """
  def decode(part, bson), do: tokenize(part, bson) |> Enum.map(&decode_kv(&1, bson)) |> :maps.from_list

  @doc """
  Returns tokens of the Bson document (no decoding)

    iex> Bson.tokenize <<12, 0, 0, 0, 16, 97, 0, 1, 0, 0, 0, 0>>
    [{{5, 1}, %BsonTk.Int32{part: {7, 4}}}]

    iex> Bson.tokenize <<12, 0, 0>>
    ** (BsonDecodeError) total length of bson document must be at least 5 at 0 of <<12, 0, 0>>

    iex> Bson.tokenize <<12, 0, 0, 0, 0, 0>>
    ** (BsonDecodeError) total length of bson document does not match document header at 0 of <<12, 0, 0, 0, 0, 0>>

    iex> Bson.tokenize <<12, 0, 0, 0, 0, 97, 0, 1, 0, 0, 0, 0>>
    ** (BsonDecodeError) Unknown element type 00 at 7 of <<12, 0, 0, 0, 0, 97, 0, 1, 0, 0, 0, 0>>

  """
  def tokenize(bson) do
    sizebson = byte_size(bson)
    cond do
      sizebson < 5 ->
        raise BsonDecodeError,
          at: 0,
          msg: "total length of bson document must be at least 5",
          bson: bson
      sizebson != int32(bson, 0) ->
        raise BsonDecodeError,
          at: 0,
          msg: "total length of bson document does not match document header",
          bson: bson
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
  def doc(s),     do: <<(byte_size(s)+5)::32-signed-little, s::binary>> <> <<0x00>>

  @doc """
  Formats a bson string using the document strings (add size and trailing null character)
  """
  def string(s),  do: int32(byte_size(s)+1) <> s <> <<0x00>>

  @doc """
  Formats a integer in a int32 binary
  """
  def int32(i),   do: <<(i)::size(32)-signed-little>>

  @doc """
  Formats a integer in a int64 binary
  """
  def int64(i),   do: <<(i)::size(64)-signed-little>>

  @doc """
  Formats true or false
  """
  def bool(bson, from) do
    case binary_part(bson, from, 1) do
      <<0x00>> -> false
      <<0x01>> -> true
    end
  end

  @doc """
  Decodes an integer (int32) from a binary at a given position
  """
  def int32(bson, from) do
    at  = from*8
    <<_::size(at), i::size(32)-signed-little, _::binary>> = bson
    i
  end

  @doc """
  Decodes an integer (int64) from a binary at a given position
  """
  def int64(bson, from) do
    at  = from*8
    <<_::size(at), i::size(64)-signed-little, _::binary>> = bson
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
      <<f::size(64)-float-little>> -> f
    end
  end

  @doc """
  Peeks for the end of a cstring
  """
  def peek_cstring_end(bson, from, to) do
    {cstring_end, _} = :binary.match(bson, <<0x00>>, [{:scope, {from, to-from+1}}])
    cstring_end
  end

  @doc """
  Decodes a key-value pair (one element of a document)
  """
  def decode_kv({tk_name, tk_element}, bson) do
    { :erlang.binary_part(bson, tk_name) |> String.to_atom,
      BsonDecoder.decode(tk_element, bson)}
  end

  @doc """
  Decodes one array item. Here the name token is not decoded, it contains the position of the item in the list.
  """
  def decode_v({_, tk_element}, bson) do
    BsonDecoder.decode(tk_element, bson)
  end
end
