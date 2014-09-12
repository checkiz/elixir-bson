defmodule Bson.Decoder do
  defstruct [new_doc: &Bson.Decoder.elist_to_atom_map/1]

  defmodule Error do
    defstruct [what: nil, reason: nil, acc: nil, rest: nil]
    defimpl Inspect, for: Error do
      def inspect(e,_), do: inspect([what: e.what, reason: e.reason, acc: e.acc, rest: e.rest])
    end
  end

  defdelegate elist_to_map(elist), to: :maps, as: :from_list
  def elist_to_atom_map(elist), do: elist |> Enum.map(fn{k, v} -> {String.to_atom(k), v} end) |> elist_to_map
  def elist_to_hashdict(elist), do: elist |> Enum.reduce %HashDict{}, fn({k, v}, h) -> HashDict.put(h, k, v) end

  @doc """
  Decodes the first document of a Bson buffer
    iex> <<4, 0, 0, 0, 0, 0>> |> Bson.decode
    {:error, "length of a document must be at least 5"}

    iex> <<5, 0, 0, 0, 0, 0>> |> Bson.decode
    {:error, {"buffer not empty after reading document", %{}}, <<0>>}

    iex> <<27, 0, 0, 0, 16, 97, 0, 1, 0, 0, 0, 3, 98, 0, 12, 0, 0, 0, 16, 99, 0, 3, 0, 0, 0, 0, 0>> |> Bson.decode
    %{a: 1, b: %{c: 3}}

    iex> [%{},
    ...>  %{a: 3},
    ...>  %{a: "r"},
    ...>  %{a: 1, b: 5},
    ...>  %{a: 1, b: %{c: 3}},
    ...>  %{a: [1, 2, 3]},
    ...>  %{a: 1.1},
    ...>  %{a: :atom},
    ...>  %{n:  %Bson.Regex{pattern: "p", opts: "o"}},
    ...>  %{o2: %Bson.JS{scope: %{x: 0, y: "foo"}, code: "function(a) = a + x"},
    ...>    p: :atom},
    ...>  %{a: [1, 2, %{aa: 2}]}
    ...> ] |> Enum.all? fn(term) -> assert term == term |> Bson.encode |> Bson.decode end
    true

    iex> term = %{
    ...> a:  4.1,
    ...> b:  2}
    ...> assert term == term |> Bson.encode |> Bson.decode
    true

  """
  def document(bsonbuffer, opts)
  def document(<<size::32-signed-little, _::binary>>, _) when size<5, do: {:error, "length of a document must be at least 5"}
  def document(<<size::32-signed-little, _::binary>>=bson, _) when size>byte_size(bson), do: {:error, "length of document (#{size}) greater than buffer (#{byte_size(bson)})"}
  def document(<<size::32-signed-little, _::binary>>=bson, opts) do
    case value(0x03, bson, size, opts) do
      %Error{}=error -> {:error, error}
      {0, rest, doc} -> {doc, rest}
    end
  end

  # Embeded document
  defp value(0x03, buffer, restsize, opts) do
    case buffer do
      <<size::32-signed-little, rest::binary>> when restsize>=size ->
        case elist(rest, size-5, opts) do
          %Error{}=error -> %Error{what: :document, reason: {error.what, error.reason}, acc: {size, error.acc}, rest: error.rest}
          {<<0, rest::binary>>, list} -> {restsize-size, rest, list}
          {rest, array} -> %Error{what: :document, reason: :"excpecting null", acc: array, rest: {restsize-size, rest}}
        end
      _ -> %Error{what: :document, reason: :"fail decoding size", rest: {restsize, buffer}}
    end
  end

  # array
  defp value(0x04, buffer, restsize, opts) do
    case buffer do
      <<size::32-signed-little, rest::binary>> when restsize>=size ->
        case ilist(rest, size-5, opts) do
          %Error{}=error -> %Error{what: :array, reason: {error.what, error.reason}, acc: {size, error.acc}, rest: error.rest}
          {<<0, rest::binary>>, list} -> {restsize-size, rest, list}
          {rest, array} -> %Error{what: :array, reason: :"excpecting null", acc: array, rest: {restsize-size, rest}}
        end
      _ -> %Error{what: :array, reason: :"fail decoding size", rest: {restsize, buffer}}
    end
  end


  # String
  defp value(0x02, buffer, restsize, _) do
    case buffer do
      <<size::32-little-signed, rest::binary>> when restsize>size+3 ->
        case string(rest, size-1, restsize-4) do
          :error -> %Error{what: :string, reason: :"fail decoding", acc: size, rest: {restsize, buffer}}
          {restsize, rest, string} -> {restsize, rest, string}
        end
      _ -> %Error{what: :string, reason: :"fail decoding size", rest: {restsize, buffer}}
    end
  end
  # Atom
  defp value(0x0e, buffer, restsize, _) do
    case buffer do
      <<size::32-little-signed, rest::binary>> when restsize>size+3 ->
        case string(rest, size-1, restsize-4) do
          :error -> %Error{what: :atom, reason: :"fail decoding", acc: size, rest: {restsize, buffer}}
          {restsize, rest, string} -> {restsize, rest, string|>String.to_atom}
        end
      _ -> %Error{what: :atom, reason: :"fail decoding size", rest: {restsize, buffer}}
    end
  end
  # Int32
  defp value(0x10, <<i::32-little-signed, rest::binary>>, restsize, _), do: {restsize-4, rest, i}
  # Int64
  defp value(0x12, <<i::64-little-signed, rest::binary>>, restsize, _) , do: {restsize-8, rest, i}
  # Float
  defp value(0x01, <<rest::binary>>, restsize, _) when restsize>7, do: float(rest, restsize)
  # Object Id
  defp value(0x07, <<oid::96, rest::binary>>, restsize, _), do: {restsize-12, rest, %Bson.ObjectId{oid: <<oid::96>>}}
  # Boolean
  defp value(0x08, <<0, rest::binary>>, restsize, _), do: {restsize-1, rest, false}
  defp value(0x08, <<1, rest::binary>>, restsize, _), do: {restsize-1, rest, true}
  defp value(0x09, <<ms::64-little-signed, rest::binary>>, restsize, _) when restsize>7, do: {restsize-8, rest, %Bson.UTC{ms: ms}}
  # null
  defp value(0x06, <<rest::binary>>, restsize, _), do: {restsize, rest, nil}
  defp value(0x0a, <<rest::binary>>, restsize, _), do: {restsize, rest, nil}
  # Timestamp
  defp value(0x11, <<inc::32-little-signed, ts::32-little-signed, rest::binary>>, restsize, _), do: {restsize-8, rest, %Bson.Timestamp{inc: inc, ts: ts}}
  # Constants
  defp value(0xff, <<rest::binary>>, restsize, _), do: {restsize, rest, :min_key}
  defp value(0x7f, <<rest::binary>>, restsize, _), do: {restsize, rest, :max_key}
  # regex
  defp value(0x0b, buffer, restsize, _) when restsize>1 do
    case cstring(buffer, restsize) do
      %Error{}=error -> %Error{what: :regex_pattern, reason: error.reason, acc: error.acc, rest: {restsize, buffer}}
      {optsrestsize, optsrest, pattern} ->
        case cstring(optsrest, optsrestsize) do
          %Error{}=error -> %Error{what: :regex_opts, reason: error.reason, acc: {error.acc, pattern}, rest: {optsrestsize, optsrest}}
          {restsize, rest, opts} -> {restsize, rest, %Bson.Regex{pattern: pattern, opts: opts}}
        end
    end
  end
  # javascript
  defp value(0x0d, buffer, restsize, _) do
    case buffer do
      <<size::32-little-signed, rest::binary>> when restsize>=size ->
        case string(rest, size-1, restsize-4) do
          :error -> %Error{what: :js_code, reason: :"Fail decoding", acc: size, rest: {restsize, buffer}}
          {restsize, rest, jscode} -> {restsize, rest, %Bson.JS{code: jscode}}
        end
      _ -> %Error{what: :js_size, reason: :"fail decoding", rest: {restsize, buffer}}
    end
  end
  # javascript with scope
  defp value(0x0f, buffer, restsize, opts) do
    case buffer do
      <<size::32-little-signed, jssize::32-little-signed, rest::binary>> when restsize>=size ->
        case string(rest, (jssize-1), size-8) do
          :error -> %Error{what: :js_code, reason: :"fail decoding", acc: {size, jssize}, rest: {restsize, buffer}}
          {scoperestsize, scopebuffer, jscode} ->
            case scopebuffer do
              <<scopesize::32-little-signed, scoperest::binary>> when scoperestsize>scopesize-1 ->
                case elist(scoperest, scopesize-5, opts) do
                  %Error{}=error -> %Error{what: :js_scope, reason: {error.what, error.reason}, acc: {scopesize, error.acc, jscode}, rest: {scoperestsize, scoperest}}
                  {<<0, rest::binary>>, scope} -> {restsize-size, rest, %Bson.JS{code: jscode, scope: scope}}
                  {rest, scope} -> %Error{what: :js_scope, reason: :"excpecting null", acc: {scope, jscode}, rest: {scoperestsize, rest}}
                end
              _ -> %Error{what: :js_scope_size, reason: :"fail decoding", acc: jscode, rest: {scoperestsize, scopebuffer}}
            end
        end
      _ -> %Error{what: :js_size, reason: :"fail decoding", rest: {restsize, buffer}}
    end
  end
  # binary
  defp value(0x05, buffer, restsize, _opts) do
    case buffer do
      <<size::32-little-signed, subtype, rest::binary>> when restsize>size+4 ->
        bitsize = size * 8
        case rest do
          <<bin::size(bitsize), rest::binary>> when restsize>size+3 -> {restsize-size-5, rest, %Bson.Bin{bin: <<bin::size(bitsize)>>, subtype: subtype}}
          _ -> %Error{what: :binary, reason: :"fail decoding", acc: {size, subtype}, rest: {restsize, rest}}
        end
      _ -> %Error{what: :binary_size, reason: :"fail decoding", rest: {restsize, buffer}}
    end
  end
  # not supported
  defp value(kind, buffer, restsize, _), do: %Error{what: :unsupported, reason: :"fail decoding", acc: kind, rest: {restsize, buffer}}

  #decodes a string
  defp string(buffer, size, restsize) do
    bitsize = size * 8
    case buffer do
      <<s::size(bitsize), 0, rest::binary>> -> {restsize-(size+1), rest, <<s::size(bitsize)>>}
      _ -> :error
    end
  end

  #Decodes a float from a binary at a given position. It will decode atoms nan, +inf and -inf as well
  defp float(<<0::48, 248, 127, rest::binary>>, max), do: {max-8, rest, :nan}
  defp float(<<0::48, 248, 255, rest::binary>>, max), do: {max-8, rest, :nan}
  defp float(<<0::48, 240, 127, rest::binary>>, max), do: {max-8, rest, :"+inf"}
  defp float(<<0::48, 240, 255, rest::binary>>, max), do: {max-8, rest, :"-inf"}
  defp float(<<f::64-float-little, rest::binary>>, max), do: {max-8, rest, f}
  defp float(_, _), do: %Error{what: :float, reason: :"fail decoding"}

  defp cstring(buffer, max, acc \\ [])
  defp cstring(<<0, rest::binary>>, max, acc), do: {max-1, rest, reverse_binof(acc)}
  defp cstring(<<c, rest::binary>>, max, acc), do: cstring(rest, max-1, [c|acc])
  defp cstring(_, 0, acc), do: %Error{what: :cstring, reason: :"reached end of document", acc: reverse_binof(acc)}
  defp cstring(<<>>, _, acc), do: %Error{what: :cstring, reason: :"reached end of buffer", acc: reverse_binof(acc)}

  defp elist(buffer, 0, _), do: {buffer, %{}}
  defp elist(buffer, size, opts, elist \\ [])
  defp elist(<<kind, rest::binary>>, size, opts, elist) do
    case cstring(rest, size-1)  do
      %Error{}=error -> %Error{what: :elist_next, reason: error.reason, acc: {error.acc, Enum.reverse(elist)}, rest: {size-1, rest}}
      {restsize, rest, name} ->
        case value(kind, rest, restsize, opts) do
          %Error{}=error -> %Error{what: :elist_value, reason: {name, error.what, error.reason}, acc: {error.acc, Enum.reverse(elist)}, rest: {restsize, rest}}
          {0, rest, value} -> {rest, opts.new_doc.([{name, value}|elist])}
          {restsize, buffer, value} ->
            {name, restsize, buffer |> byte_size}
            elist(buffer, restsize, opts, [{name, value}|elist])
        end
    end
  end

  defp ilist(buffer, size, opts, ilist \\ [])
  defp ilist(<<kind, rest::binary>>, size, opts, ilist) do
    case skip_cstring(rest, size-1) do
      %Error{}=error -> %Error{what: :ilist_next, reason: error.reason, acc: ilist, rest: {size-1, rest}}
      {restsize, rest} ->
        case value(kind, rest, restsize, opts) do
          %Error{}=error -> %Error{what: :ilist_value, reason: {error.what, error.reason}, acc: {Enum.reverse(ilist), error.acc}, rest: error.rest}
          {0, rest, value} -> {rest, [value|ilist] |> Enum.reverse}
          {restsize, buffer, value} -> ilist(buffer, restsize, opts, [value|ilist])
        end
    end
  end

  defp skip_cstring(buffer, max)
  defp skip_cstring(<<0, rest::binary>>, max), do: {max-1, rest}
  defp skip_cstring(<<_, rest::binary>>, max), do: skip_cstring(rest, max-1)
  defp skip_cstring(_, 0), do: %Error{what: :skip_cstring, reason: :"reached end of document"}
  defp skip_cstring(<<>>, _), do: %Error{what: :skip_cstring, reason: :"reached end of buffer"}

  defp reverse_binof(iolist), do: iolist |> Enum.reverse |> :erlang.iolist_to_binary

end
