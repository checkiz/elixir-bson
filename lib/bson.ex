defmodule Bson do
  @moduledoc """
  `Bson` provides encoding and decoding function for Bson format
  see http://bsonspec.org/

  Usage:

    iex> term = %{
    ...> a:  -4.230845,
    ...> b:  "hello",
    ...> c:  %{x: -1, y: 2.2001},
    ...> d:  [23, 45, 200],
    ...> eeeeeeeee:  %Bson.Bin{ subtype: Bson.Bin.subtyx(:binary),
    ...>               bin:  <<200, 12, 240, 129, 100, 90, 56, 198, 34, 0, 0>>},
    ...> f:  %Bson.Bin{ subtype: Bson.Bin.subtyx(:function),
    ...>               bin:  <<200, 12, 240, 129, 100, 90, 56, 198, 34, 0, 0>>},
    ...> g:  %Bson.Bin{ subtype: Bson.Bin.subtyx(:uuid),
    ...>               bin:  <<49, 0, 0, 0, 4, 66, 83, 79, 78, 0, 38, 0, 0, 0,
    ...>                       2, 48, 0, 8, 0, 0, 0, 97, 119, 101, 115, 111, 109,
    ...>                       101, 0, 1, 49, 0, 51, 51, 51, 51, 51, 51, 20, 64,
    ...>                       16, 50, 0, 194, 7, 0, 0, 0, 0>>},
    ...> h:  %Bson.Bin{ subtype: Bson.Bin.subtyx(:md5),
    ...>               bin:  <<200, 12, 240, 129, 100, 90, 56, 198, 34, 0, 0>>},
    ...> i:  %Bson.Bin{ subtype: Bson.Bin.subtyx(:user),
    ...>               bin:  <<49, 0, 0, 0, 4, 66, 83, 79, 78, 0, 38, 0, 0, 0, 2,
    ...>                       48, 0, 8, 0, 0, 0, 97, 119, 101, 115, 111, 109, 101,
    ...>                       0, 1, 49, 0, 51, 51, 51, 51, 51, 51, 20, 64, 16, 50,
    ...>                       0, 194, 7, 0, 0, 0, 0>>},
    ...> j:  %Bson.ObjectId{oid: <<82, 224, 229, 161, 0, 0, 2, 0, 3, 0, 0, 4>>},
    ...> k1: false,
    ...> k2: true,
    ...> l:  Bson.UTC.from_now({1390, 470561, 277000}),
    ...> m:  nil,
    ...> n:  %Bson.Regex{pattern: "p", opts: "o"},
    ...> o1: %Bson.JS{code: "function(x) = x + 1;"},
    ...> o2: %Bson.JS{scope: %{x: 0, y: "foo"}, code: "function(a) = a + x"},
    ...> p:  :atom,
    ...> q1: -2000444000,
    ...> q2: -8000111000222001,
    ...> r:  %Bson.Timestamp{inc: 1, ts: 2},
    ...> s1: :min_key,
    ...> s2: :max_key
    ...> }
    ...> bson = Bson.encode(term)
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
    ...> decodedTerm = Bson.decode(bson)
    ...> # assert that one by one all decoded element are identical to the original
    ...> Enum.all? term, fn({k, v}) -> assert Map.get(decodedTerm, k) == v end
    true

  ```

  see `encode/1` and `decode/1`

  """
  defmodule ObjectId do
    defstruct oid: nil
    @moduledoc """
    Represents the [MongoDB ObjectId](http://docs.mongodb.org/manual/reference/object-id/)

    * `:oid` - contains a binary size 12

    iex> inspect %Bson.ObjectId{}
    "ObjectId()"
    iex> inspect %Bson.ObjectId{oid: "\x0F\x1B\x01\x02\x03\x04\x05\x06\x07\x08\x09\x10"}
    "ObjectId(0f1b01020304050607080910)"

    """
    defimpl Inspect, for: Bson.ObjectId do
      def inspect(%Bson.ObjectId{oid: nil},_), do: "ObjectId()"
      def inspect(%Bson.ObjectId{oid: oid},_) when is_binary(oid), do: "ObjectId(#{Bson.hex(oid)|>String.downcase})"
      def inspect(%Bson.ObjectId{oid: oid},_), do: "InvalidObjectId(#{inspect(oid)})"
    end
  end

  def hex(bin), do: (for <<h::4 <- bin>>, into: <<>>, do: <<Integer.to_string(h,16)::binary>>)

  defmodule Regex do
    defstruct pattern: "", opts: ""
    @moduledoc """
    Represents a Regex

    * `:pattern` - a bynary that is the regex pattern
    * `:opts` - a bianry that contains the regex options string identified by characters, which must be stored in alphabetical order. Valid options are 'i' for case insensitive matching, 'm' for multiline matching, 'x' for verbose mode, 'l' to make \w, \W, etc. locale dependent, 's' for dotall mode ('.' matches everything), and 'u' to make \w, \W, etc. match unicode
    """
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
  defmodule UTC do
    defstruct ms: nil
    @moduledoc """
    Represent UTC datetime

    * `:ms` - miliseconds
    """
    @doc """
    Returns a struct `Bson.UTC` using a tuple given by `:erlang.now/0`

    iex> Bson.UTC.from_now({1410, 473634, 449058})
    %Bson.UTC{ms: 1410473634449}
    """
    def from_now({a, s, o}), do: %UTC{ms: a * 1000000000 + s * 1000 + div(o, 1000)}
    @doc """
    Returns a triplet tuple similar to the return value of `:erlang.now/0` using a struct `Bson.UTC`

    iex> Bson.UTC.to_now(%Bson.UTC{ms: 1410473634449})
    {1410, 473634, 449000}
    """
    def to_now(%UTC{ms: ms}), do: {div(ms, 1000000000), rem(div(ms, 1000), 1000000), rem(ms * 1000, 1000000)}
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
    def subtyx(:binary),     do: 0x00
    def subtyx(:function),   do: 0x01
    def subtyx(:binary_old), do: 0x02
    def subtyx(:uuid_old),   do: 0x03
    def subtyx(:uuid),       do: 0x04
    def subtyx(:md5),        do: 0x05
    def subtyx(:user),       do: 0x80

    @doc """
    Returns the atom coresponding to the subtype of the bynary data
    """
    def xsubty(0x00),     do: :binary
    def xsubty(0x01),     do: :function
    def xsubty(0x02),     do: :binary
    def xsubty(0x03),     do: :uuid
    def xsubty(0x04),     do: :uuid
    def xsubty(0x05),     do: :md5
    def xsubty(0x80),     do: :user
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
  defdelegate encode(term), to: Bson.Encoder, as: :document

  @doc """
  Returns decoded terms from a Bson binary document into a map with keys in the form of atoms (for other options use `Bson.Decoder.document/2`)


  ```elixir
    iex> %{} |> Bson.encode |> Bson.decode
    %{}

    iex> %{a: "a"} |> Bson.encode |> Bson.decode
    %{a: "a"}

    iex> %{a: 1, b: [2, "c"]} |> Bson.encode |> Bson.decode
    %{a: 1, b: [2, "c"]}

  ```
  see protocol `BsonDecoder`
  """
  def decode(bson) do
    case Bson.Decoder.document(bson, %Bson.Decoder{new_doc: &Bson.Decoder.elist_to_atom_map/1}) do
      {:error, reason} -> {:error, reason}
      {doc, <<>>} -> doc
      {doc, rest} -> {:error, {"buffer not empty after reading document", doc}, rest}
    end
  end

end
