Code.require_file "test_helper.exs", __DIR__

defmodule Bson.Test do
  use ExUnit.Case

  doctest Bson

  test "Encoding elementary type" do
    assert Bson.encode([2]) == <<12, 0, 0, 0, 16, 48, 0, 2, 0, 0, 0, 0>>
    assert Bson.encode([-0x80000001]) == <<16, 0, 0, 0, 18, 48, 0, 255, 255, 255, 127, 255, 255, 255, 255, 0>>
    assert Bson.encode([1.1]) == <<16, 0, 0, 0, 1, 48, 0, 154, 153, 153, 153, 153, 153, 241, 63, 0>>
    assert Bson.encode([true]) == <<9, 0, 0, 0, 8, 48, 0, 1, 0>>
    assert Bson.encode([nil]) == <<8, 0, 0, 0, 10, 48, 0, 0>>
    assert Bson.encode([~r/p/i]) == <<12, 0, 0, 0, 11, 48, 0, 112, 0, 105, 0, 0>>
    assert Bson.encode([MIN_KEY]) == <<8, 0, 0, 0, 255, 48, 0, 0>>
    assert Bson.encode([:nan])    == <<16, 0, 0, 0, 1, 48, 0, 0, 0, 0, 0, 0, 0, 248, 127, 0>>
    assert Bson.encode([:'+inf']) == <<16, 0, 0, 0, 1, 48, 0, 0, 0, 0, 0, 0, 0, 240, 127, 0>>
    assert Bson.encode([:'-inf']) == <<16, 0, 0, 0, 1, 48, 0, 0, 0, 0, 0, 0, 0, 240, 255, 0>>
  end

  test "site sample" do
    assert Bson.encode(%{hello: "world"}) == "\x16\x00\x00\x00\x02hello\x00\x06\x00\x00\x00world\x00\x00"
    assert Bson.encode(%{BSON: ["awesome", 5.05, 1986]})
    == <<49,0,0,0,4,66,83,79,78,0,38,0,0,0,2,48,0,8,0,0,0,97,119,101,115,111,109,101,0,1,49,0,51,51,51,51,51,51,20,64,16,50,0,194,7,0,0,0,0>>
  end

  test "tokenizer" do
    # {a: 1}
    assert <<12, 0, 0, 0, 16, 97, 0, 1, 0, 0, 0, 0>>
      |> Bson.tokenize |> hd == {{5, 1}, %BsonTk.Int32{part: {7, 4}}}
    assert <<19, 0, 0, 0, 16, 97, 0, 1, 0, 0, 0, 16, 49, 0, 2, 0, 0, 0, 0>>
      |> Bson.tokenize |> hd == {{5, 1}, %BsonTk.Int32{part: {7, 4}}}
    # {a: 1, b: {c: 2}}
    assert <<27, 0, 0, 0, 16, 97, 0, 1, 0, 0, 0, 3, 98, 0, 12, 0, 0, 0, 16, 99, 0, 2, 0, 0, 0, 0, 0>>
      |> Bson.tokenize == [{{5, 1}, %BsonTk.Int32{part: {7, 4}}}, {{12, 1}, %BsonTk.Doc{part: {18, 7}}}]
  end

  test "document" do
    # {} to encode empty js object (will be decode as an empty Map, though)
    term = %{}
    bson = <<5, 0, 0, 0, 0>>
    assert Bson.encode(term) == bson
    assert %{} == Bson.decode(bson)

    # {a: 2}
    term = %{a: 2}
    bson = <<12, 0, 0, 0, 16, 97, 0, 2, 0, 0, 0, 0>>
    assert Bson.encode(term) == bson
    assert term == Bson.decode(bson)

    # {a: 1, b: 2}
    term = %{a: 1, b: 2}
    bson = <<19, 0, 0, 0, 16, 97, 0, 1, 0, 0, 0, 16, 98, 0, 2, 0, 0, 0, 0>>
    assert Bson.encode(term) == bson
    assert term == Bson.decode(bson)

    # {a: 1, b: {c: 2}}
    term = %{a: 1, b: %{c: 2}}
    bson = <<27, 0, 0, 0, 16, 97, 0, 1, 0, 0, 0, 3, 98, 0, 12, 0, 0, 0, 16, 99, 0, 2, 0, 0, 0, 0, 0>>
    assert Bson.encode(term) == bson
    assert term == Bson.decode(bson)
  end

  test "array" do
    term = %{"0": [2,3]}
    bson = <<27, 0, 0, 0, 4, 48, 0, 19, 0, 0, 0, 16, 48, 0, 2, 0, 0, 0, 16, 49, 0, 3, 0, 0, 0, 0, 0>>
    assert Bson.encode(term) == bson
    assert term == Bson.decode(bson)

    term = %{"0": [1,[nil]]}
    bson = <<31, 0, 0, 0, 4, 48, 0, 23, 0, 0, 0, 16, 48, 0, 1, 0, 0, 0, 4, 49, 0, 8, 0, 0, 0, 10, 48, 0, 0, 0, 0>>
    assert Bson.encode(term) == bson
    assert term == Bson.decode(bson)

    term = %{"0": [1,[2,3]]}
    bson = <<42, 0, 0, 0, 4, 48, 0, 34, 0, 0, 0, 16, 48, 0, 1, 0, 0, 0, 4, 49, 0, 19, 0, 0, 0, 16, 48, 0, 2, 0, 0, 0, 16, 49, 0, 3, 0, 0, 0, 0, 0, 0>>
    assert Bson.encode(term) == bson
    assert term == Bson.decode(bson)
  end

  test "ObjectId" do
    assert %Bson.ObjectId{} = %Bson.ObjectId{oid: nil}

    bson = <<20, 0, 0, 0, 7, 48, 0, 82, 224, 252, 230, 0, 0, 2, 0, 3, 0, 0, 4, 0>>
    term = %Bson.ObjectId{oid: <<82, 224, 252, 230, 0, 0, 2, 0, 3, 0, 0, 4>>}

    assert Bson.encode(%{"0": term}) == bson
    assert %{"0": term} == Bson.decode(bson)
  end

  test "JS" do
    term = %Bson.JS{code: "1+1;"}
    bson = <<17, 0, 0, 0, 13, 48, 0, 5, 0, 0, 0, 49, 43, 49, 59, 0, 0>>

    assert Bson.encode(%{"0": term}) == bson
    assert %{"0": term} == Bson.decode(bson)
  end

  test "JS with scope" do
    term = %Bson.JS{scope: %{a: 0, b: "c"},code: "1+1;"}
    bson = <<42, 0, 0, 0, 15, 48, 0, 34, 0, 0, 0, 5, 0, 0, 0, 49, 43, 49, 59, 0, 21, 0, 0, 0, 16, 97, 0, 0, 0, 0, 0, 2, 98, 0, 2, 0, 0, 0, 99, 0, 0, 0>>

    assert Bson.encode(%{"0": term}) == bson
    assert %{"0": term} == Bson.decode(bson)
  end

  test "regex" do
    term = ~r/p/i
    bson = <<12, 0, 0, 0, 11, 48, 0, 112, 0, 105, 0, 0>>

    assert Bson.encode(%{"0": term}) == bson
    assert %{"0": term} == Bson.decode(bson)
  end

  test "timestamp" do
    term = %Bson.Timestamp{inc: 1, ts: 2}
    bson = <<16, 0, 0, 0, 17, 48, 0, 1, 0, 0, 0, 2, 0, 0, 0, 0>>

    assert Bson.encode(%{"0": term}) == bson
    assert %{"0": term} == Bson.decode(bson)
  end

  test "binary" do
    term = %Bson.Bin{bin: "e", subtype: Bson.Bin.subtyx(User)}
    bson = <<14, 0, 0, 0, 5, 48, 0, 1, 0, 0, 0, 128, 101, 0>>

    assert Bson.encode(%{"0": term}) == bson
    assert %{"0": term} == Bson.decode(bson)
  end

  test "xdoc" do
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
        m:  nil,
        n:  ~r/p/i,
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
    <<177,1,0,0,1,97,0,206,199,181,161,98,236,16,192,2,98,0,6,0,0,0,104,101,108,108,111,0,3,99,0,23,0,0,0,16,120,0,255,
    255,255,255,1,121,0,210,111,95,7,206,153,1,64,0,4,100,0,26,0,0,0,16,48,0,23,0,0,0,16,49,0,45,0,0,0,16,50,0,200,0,
    0,0,0,5,101,101,101,101,101,101,101,101,101,0,11,0,0,0,0,200,12,240,129,100,90,56,198,34,0,0,5,102,0,11,0,0,0,1,
    200,12,240,129,100,90,56,198,34,0,0,5,103,0,49,0,0,0,4,49,0,0,0,4,66,83,79,78,0,38,0,0,0,2,48,0,8,0,0,0,97,119,101,
    115,111,109,101,0,1,49,0,51,51,51,51,51,51,20,64,16,50,0,194,7,0,0,0,0,5,104,0,11,0,0,0,5,200,12,240,129,100,90,56,
    198,34,0,0,5,105,0,49,0,0,0,128,49,0,0,0,4,66,83,79,78,0,38,0,0,0,2,48,0,8,0,0,0,97,119,101,115,111,109,101,0,1,49,
    0,51,51,51,51,51,51,20,64,16,50,0,194,7,0,0,0,0,7,106,0,82,224,229,161,0,0,2,0,3,0,0,4,8,107,49,0,0,8,107,50,0,1,10,
    109,0,11,110,0,112,0,105,0,13,111,49,0,21,0,0,0,102,117,110,99,116,105,111,110,40,120,41,32,61,32,120,32,43,32,49,59,
    0,15,111,50,0,51,0,0,0,20,0,0,0,102,117,110,99,116,105,111,110,40,97,41,32,61,32,97,32,43,32,120,0,23,0,0,0,16,120,0,
    0,0,0,0,2,121,0,4,0,0,0,102,111,111,0,0,14,112,0,5,0,0,0,97,116,111,109,0,16,113,49,0,160,165,195,136,18,113,50,0,
    207,6,171,1,241,147,227,255,17,114,0,1,0,0,0,2,0,0,0,255,115,49,0,127,115,50,0,0>>

    assert Bson.encode(term) == bson
    assert term == Bson.decode(bson)
  end

end
