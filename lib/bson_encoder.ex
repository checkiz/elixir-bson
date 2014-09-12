defmodule Bson.Encoder do
  defprotocol Protocol do
    @moduledoc """
    `Bson.Encoder.Protocol` protocol defines Bson encoding according to Elxir terms and some Bson predefined structs (see `Bson`).

    List of the protocol implementations:

    * `Map` - Encodes a map into a document
    * `HasDict` - Encodes a HashDict into a document
    * `Keyword` - Encodes a Keyword into a document
    *  `List` - Encodes a list of key-alue pairs into a document otherwize encode list into array
    * `Integer` - Encodes integer in 32 or 64 bits
    * `Float` - Encodes float in 64 bits
    * `Atom` - Encodes special atom (`false`, `true`, `nil`,
    `:nan`, `:+inf`, `:-inf`, `MIN_KEY` and `MAX_KEY`) in appropriate format
    others in special type Symbol
    * `BitString` - as binary string
    * `Bson.Regex' - see specs
    * `Bson.ObjectId' - see specs
    * `Bson.JS' - see specs
    * `Bson.Bin' - see specs
    * `Bson.Timestamp  ' - see specs
    """

    @doc """
    Returns a binary representing a term in Bson format
    """
    def encode(term)
  end
  defmodule Error do
    @moduledoc """
    Container for error messages

    * `what` has triggerred the error
    * `acc` contains what was already decoded for this term (ie the size of a string when the string itself could not be decoded)
    * `term` that failed to be encoded
    """
    defstruct [what: nil, acc: [], term: nil]
    defimpl Inspect, for: Error do
      def inspect(e,_), do: inspect([what: e.what, term: e.term, acc: e.acc])
    end
  end

  @doc """
  Creates a document using a collection of element, this is, a key-value pair
  """
  def document(element_list) do
    case Enumerable.reduce(element_list, {:cont, []},
      fn({key, value}, acc) when is_binary(key) -> accumulate_elist(key, value, acc)
        ({key, value}, acc) when is_atom(key) -> accumulate_elist(Atom.to_string(key), value, acc)
        (element, acc) -> {:halt, %Error{what: [:element], term: element, acc: acc |> Enum.reverse}}
      end) do
      {:halted, error} -> error
      {:done, acc} ->
        acc |> Enum.reverse |> IO.iodata_to_binary |> wrap_document
    end
  end

  defimpl Protocol, for: Integer do
    @doc """
    iex> Bson.Encoder.Protocol.encode(2)
    {<<16>>, <<2, 0, 0, 0>>}
    iex> Bson.Encoder.Protocol.encode(-2)
    {<<16>>, <<254, 255, 255, 255>>}
    iex> Bson.Encoder.Protocol.encode -0x80000001
    {<<18>>, <<255, 255, 255, 127, 255, 255, 255, 255>>}

    iex> Bson.Encoder.Protocol.encode 0x8000000000000001
    %Bson.Encoder.Error{what: [Integer], term: 0x8000000000000001}
    """
    def encode(i) when -0x80000000 <= i and i <= 0x80000000, do: {<<0x10>>, <<i::32-signed-little>>}
    def encode(i) when -0x8000000000000000 <= i and i <= 0x8000000000000000, do: {<<0x12>>, <<i::64-signed-little>>}
    def encode(i), do: %Error{what: [Integer], term: i}
  end

  defimpl Protocol, for: Float do
    @doc """
    iex> Bson.Encoder.Protocol.encode(1.1)
    {<<1>>, <<154, 153, 153, 153, 153, 153, 241, 63>>}
    """
    def encode(f), do: {<<0x01>>, <<(f)::size(64)-float-little>>}
  end

  defimpl Protocol, for: Atom do
    @doc """
    iex> Bson.Encoder.Protocol.encode(true)
    {<<8>>, <<1>>}
    iex> Bson.Encoder.Protocol.encode(nil)
    {<<10>>, <<>>}
    iex> Bson.Encoder.Protocol.encode(:max_key)
    {<<127>>, <<>>}
    iex> Bson.Encoder.Protocol.encode(:min_key)
    {<<255>>, <<>>}
    iex> Bson.Encoder.Protocol.encode(:nan)
    {<<1>>, <<0, 0, 0, 0, 0, 0, 248, 127>>}
    iex> Bson.Encoder.Protocol.encode(:'+inf')
    {<<1>>, <<0, 0, 0, 0, 0, 0, 240, 127>>}
    iex> Bson.Encoder.Protocol.encode(:'-inf')
    {<<1>>, <<0, 0, 0, 0, 0, 0, 240, 255>>}
    iex> Bson.Encoder.Protocol.encode(:atom)
    {<<14>>, [<<5, 0, 0, 0>>, "atom", <<0>>]}

    """
    # predefind Bson value
    def encode(false),   do: {<<0x08>>, <<0x00>>}
    def encode(true),    do: {<<0x08>>, <<0x01>>}
    def encode(nil),     do: {<<0x0a>>, <<>>}
    def encode(:nan),    do: {<<0x01>>, <<0, 0, 0, 0, 0, 0, 248, 127>>}
    def encode(:'+inf'), do: {<<0x01>>, <<0, 0, 0, 0, 0, 0, 240, 127>>}
    def encode(:'-inf'), do: {<<0x01>>, <<0, 0, 0, 0, 0, 0, 240, 255>>}
    def encode(:min_key), do: {<<0xff>>, <<>>}
    def encode(:max_key), do: {<<0x7f>>, <<>>}
    # other Elixir atom are encoded like strings ()
    def encode(atom),    do: {<<0x0e>>, (atom |> Atom.to_string |> Bson.Encoder.wrap_string)}
  end

  defimpl Protocol, for: Bson.UTC do
    @doc """
    iex> Bson.Encoder.Protocol.encode(Bson.UTC.from_now({1390, 324703, 518471}))
    {<<9>>, <<30, 97, 207, 181, 67, 1, 0, 0>>}
    """
    def encode(%Bson.UTC{ms: ms}) when is_integer(ms), do: {<<0x09>>, <<ms::64-little-signed>>}
    def encode(utc), do: %Error{what: [Bson.UTC], term: utc}
  end

  defimpl Protocol, for: Bson.Regex do
    @doc """
    iex> Bson.Encoder.Protocol.encode(%Bson.Regex{pattern: "p", opts: "i"})
    {<<11>>, ["p", <<0>>, "i", <<0>>]}
    """
    def encode(%Bson.Regex{pattern: p, opts: o}) when is_binary(p) and is_binary(o), do: {<<0x0b>>, [p, <<0x00>>, o, <<0x00>>]}
    def encode(regex), do: %Error{what: [Bson.Regex], term: regex}
  end

  defimpl Protocol, for: Bson.ObjectId do
    @doc """
    iex> Bson.Encoder.Protocol.encode(%Bson.ObjectId{oid: <<0xFF>>})
    {<<0x07>>, <<255>>}

    iex> Bson.Encoder.Protocol.encode(%Bson.ObjectId{oid: 123})
    %Bson.Encoder.Error{what: [Bson.ObjectId], term: %Bson.ObjectId{oid: 123}}
    """
    def encode(%Bson.ObjectId{oid: oid}) when is_binary(oid), do: {<<0x07>>, oid}
    def encode(oid), do: %Error{what: [Bson.ObjectId], term: oid}
  end

  defimpl Protocol, for: Bson.JS do
    @doc """
    iex> Bson.Encoder.Protocol.encode(%Bson.JS{code: "1+1;"})
    {<<13>>, [<<5, 0, 0, 0>>, "1+1;", <<0>>]}
    iex> Bson.Encoder.Protocol.encode(%Bson.JS{code: "1+1;", scope: %{a: 0, b: "c"}})
    {<<15>>, <<34, 0, 0, 0, 5, 0, 0, 0, 49, 43, 49, 59, 0, 21, 0, 0, 0, 16, 97, 0, 0, 0, 0, 0, 2, 98, 0, 2, 0, 0, 0, 99, 0, 0>>}
    """
    def encode(%Bson.JS{code: js, scope: nil}) when is_binary(js) do
      {<<0x0d>>, Bson.Encoder.wrap_string(js)}
    end
    def encode(%Bson.JS{code: js, scope: ctx}) when is_binary(js) and is_map(ctx) do
      case Bson.Encoder.document(ctx) do
        %Error{}=error -> %Error{error|what: {:js_context, error.what}}
        ctxBin ->
          {<<0x0f>>, [Bson.Encoder.wrap_string(js), ctxBin] |> IO.iodata_to_binary |> js_ctx}
      end
    end
    def encode(js), do: %Error{what: [Bson.JS], term: js}

    defp js_ctx(jsctx), do: <<(byte_size(jsctx)+4)::32-little-signed, jsctx::binary>>
  end

  defimpl Protocol, for: Bson.Bin do
    @doc """
    iex> Bson.Encoder.Protocol.encode(%Bson.Bin{bin: "e", subtype: Bson.Bin.subtyx(:user)})
    {<<5>>,[<<1, 0, 0, 0>>, 128, "e"]}
    """
    def encode(%Bson.Bin{bin: bin, subtype: subtype}), do: encode(bin, subtype)
    def encode(bin, subtype)
      when is_binary(bin) and is_integer(subtype),
      do:  {<<0x05>>, [<<byte_size(bin)::32-little-signed>>, subtype, bin]}
    def encode(bin, subtype), do: %Error{what: [Bson.Bin], term: {bin, subtype}}
  end

  defimpl Protocol, for: Bson.Timestamp do
    @doc """
    iex> Bson.Encoder.Protocol.encode(%Bson.Timestamp{inc: 1, ts: 2})
    {<<17>>,<<1, 0, 0, 0, 2, 0, 0, 0>>}
    """
    def encode(%Bson.Timestamp{inc: i, ts: t})
      when is_integer(i) and -0x80000000 <= i and i <= 0x80000000
       and is_integer(t) and -0x80000000 <= t and t <= 0x80000000,
      do: {<<0x11>>, <<i::32-signed-little, t::32-signed-little>>}
      def encode(ts), do: %Error{what: [Bson.Timestamp], term: ts}
  end

  defimpl Protocol, for: BitString do
    @doc """
    iex> Bson.Encoder.Protocol.encode("a")
    {<<2>>, [<<2, 0, 0, 0>>, "a", <<0>>]}
    """
    def encode(s) when is_binary(s),  do: {<<0x02>>, Bson.Encoder.wrap_string(s)}
    def encode(bits), do: %Error{what: [BitString], term: bits}
  end

  defimpl Protocol, for: List do
    @doc """
    iex> Bson.Encoder.Protocol.encode([])
    {<<4>>,<<5, 0, 0, 0, 0>>}
    iex> Bson.Encoder.Protocol.encode([2, 3])
    {<<4>>,<<19, 0, 0, 0, 16, 48, 0, 2, 0, 0, 0, 16, 49, 0, 3, 0, 0, 0, 0>>}
    iex> Bson.Encoder.Protocol.encode([1,[nil]])
    {<<4>>,<<23, 0, 0, 0, 16, 48, 0, 1, 0, 0, 0, 4, 49, 0, 8, 0, 0, 0, 10, 48, 0, 0, 0>>}
    iex> Bson.Encoder.Protocol.encode([1,[2, 3]])
    {<<4>>,<<34, 0, 0, 0, 16, 48, 0, 1, 0, 0, 0, 4, 49, 0, 19, 0, 0, 0, 16, 48, 0, 2, 0, 0, 0, 16, 49, 0, 3, 0, 0, 0, 0, 0>>}

    # Keyword and list of key-value pairs
    iex> Bson.Encoder.Protocol.encode([a: "r"])
    {<<3>>,<<14, 0, 0, 0, 2, 97, 0, 2, 0, 0, 0, 114, 0, 0>>}
    iex> Bson.Encoder.Protocol.encode([{"a", "s"}])
    {<<3>>,<<14, 0, 0, 0, 2, 97, 0, 2, 0, 0, 0, 115, 0, 0>>}

    iex> Bson.Encoder.Protocol.encode([{"a", "s"}, {:b, "r"}, 1, 2])
    %Bson.Encoder.Error{
      term: 1,
      what: [:element],
      acc: [[<<2>>, "a", <<0>>, [<<2, 0, 0, 0>>, "s", <<0>>]],
            [<<2>>, "b", <<0>>, [<<2, 0, 0, 0>>, "r", <<0>>]]]}

    iex> Bson.Encoder.Protocol.encode([2, 3, ])
    {<<4>>,<<19, 0, 0, 0, 16, 48, 0, 2, 0, 0, 0, 16, 49, 0, 3, 0, 0, 0, 0>>}

    """
    def encode([{k, _}|_]=elist) when is_atom(k) or is_binary(k) do
      case Bson.Encoder.document(elist) do
        %Error{}=error -> error
        encoded_elist -> {<<0x03>>, encoded_elist}
      end
    end
    def encode(list) do
      case Bson.Encoder.array(list) do
        %Error{}=error -> error
        encoded_list -> {<<0x04>>, encoded_list}
      end
    end
  end

  defimpl Protocol, for: [Map, HashDict, Keyword] do
    @doc """
    # Map
    iex> Bson.Encoder.Protocol.encode(%{})
    {<<3>>,<<5, 0, 0, 0, 0>>}
    iex> Bson.Encoder.Protocol.encode(%{a: "r"})
    {<<3>>,<<14, 0, 0, 0, 2, 97, 0, 2, 0, 0, 0, 114, 0, 0>>}
    iex> Bson.Encoder.Protocol.encode(%{a: 1, b: 5})
    {<<3>>,<<19, 0, 0, 0, 16, 97, 0, 1, 0, 0, 0, 16, 98, 0, 5, 0, 0, 0, 0>>}
    iex> Bson.Encoder.Protocol.encode(%{a: 1, b: %{c: 3}})
    {<<3>>,<<27, 0, 0, 0, 16, 97, 0, 1, 0, 0, 0, 3, 98, 0, 12, 0, 0, 0, 16, 99, 0, 3, 0, 0, 0, 0, 0>>}

    # HashDict
    iex> Bson.Encoder.Protocol.encode(%HashDict{})
    {<<3>>,<<5, 0, 0, 0, 0>>}
    iex> Bson.Encoder.Protocol.encode(HashDict.put(%HashDict{}, :a, "r"))
    {<<3>>,<<14, 0, 0, 0, 2, 97, 0, 2, 0, 0, 0, 114, 0, 0>>}

    iex> Bson.Encoder.Protocol.encode(%{a: "va", b: "vb", u: %Bson.UTC{ms: "e"}})
    %Bson.Encoder.Error{
      what: ["u", Bson.UTC],
      term: %Bson.UTC{ms: "e"},
      acc: [[[<<2>>, "a", <<0>>, [<<3, 0, 0, 0>>, "va", <<0>>]],
             [<<2>>, "b", <<0>>, [<<3, 0, 0, 0>>, "vb", <<0>>]]]]}
    iex> Bson.Encoder.Protocol.encode([1, 2, %Bson.UTC{ms: "e"}])
    %Bson.Encoder.Error{
      what: ["2", Bson.UTC],
      term: %Bson.UTC{ms: "e"},
      acc: [[[<<16>>, "0", <<0>>, <<1, 0, 0, 0>>],
             [<<16>>, "1", <<0>>, <<2, 0, 0, 0>>]]]}
    iex> Bson.Encoder.Protocol.encode(%{a: "va", b: "vb", c: %{c1: "vc1", cu: %Bson.UTC{ms: "e"}}})
    %Bson.Encoder.Error{
      what: ["c", "cu", Bson.UTC],
      term: %Bson.UTC{ms: "e"},
      acc: [[[<<2>>, "a", <<0>>, [<<3, 0, 0, 0>>, "va", <<0>>]],
            [<<2>>, "b", <<0>>,  [<<3, 0, 0, 0>>, "vb", <<0>>]]],
           [[<<2>>, "c1", <<0>>, [<<4, 0, 0, 0>>, "vc1", <<0>>]]]]}
    iex> Bson.Encoder.Protocol.encode(%{a: "va", b: "vb", c: ["c0", %Bson.UTC{ms: "e"}]})
    %Bson.Encoder.Error{
      what: ["c", "1", Bson.UTC],
      term: %Bson.UTC{ms: "e"},
      acc: [[[<<2>>, "a", <<0>>, [<<3, 0, 0, 0>>, "va", <<0>>]],
            [<<2>>, "b", <<0>>, [<<3, 0, 0, 0>>, "vb", <<0>>]]],
           [[<<2>>, "0", <<0>>, [<<3, 0, 0, 0>>, "c0", <<0>>]]]]}

    """
    def encode(dict) do
      case Bson.Encoder.document(dict) do
        %Error{}=error -> error
        encoded_dict -> {<<0x03>>, encoded_dict}
      end
    end
  end

  @doc """
  Creates a document for an array (list of items)
  """
  def array(item_list) do
    case Enumerable.reduce(item_list, {:cont, {[], 0}},
      fn(item, {acc, i}) ->
        case accumulate_elist(Integer.to_string(i), item, acc) do
          {:cont, acc} -> {:cont, {acc, i+1}}
          {:halt, error} -> {:halt, error}
        end
      end) do
      {:halted, error} -> error
      {:done, {bufferAcc, _}} ->
        bufferAcc |> Enum.reverse |> IO.iodata_to_binary |> wrap_document
    end
  end

  @doc """
  Wraps a bson document with size and trailing null character
  """
  def wrap_document(elist), do: <<(byte_size(elist)+5)::32-little-signed>> <> elist <> <<0x00>>

  @doc """
  Wraps a bson document with size and trailing null character
  """
  def wrap_string(string), do: [<<(byte_size(string)+1)::32-little-signed>>, string, <<0x00>>]

  @doc """
  Accumulate element in an element list
  """
  def accumulate_elist(name, value, elist) do
    case element(name, value) do
      %Error{}=error -> {:halt, %Error{error|acc: [Enum.reverse(elist)|error.acc]}}
      encoded_element -> {:cont, [encoded_element | elist]}
    end
  end

  @doc """
  Returns encoded element using its name and value
  """
  def element(name, value) do
    case Bson.Encoder.Protocol.encode(value) do
      %Error{}=error -> %Error{error|what: [name|error.what]}
      {kind, encoded_value} -> [kind, name, <<0x00>>, encoded_value]
    end
  end
end
