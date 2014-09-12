Code.require_file "test_helper.exs", __DIR__

defmodule Bson.Test do
  use ExUnit.Case

  doctest Bson
  doctest Bson.ObjectId
  doctest Bson.UTC
  doctest Bson.Decoder
  doctest Bson.Encoder.Protocol.Float
  doctest Bson.Encoder.Protocol.Integer
  doctest Bson.Encoder.Protocol.Atom
  doctest Bson.Encoder.Protocol.Bson.Regex
  doctest Bson.Encoder.Protocol.Bson.ObjectId
  doctest Bson.Encoder.Protocol.Bson.JS
  doctest Bson.Encoder.Protocol.Bson.Bin
  doctest Bson.Encoder.Protocol.Bson.Timestamp
  doctest Bson.Encoder.Protocol.BitString
  doctest Bson.Encoder.Protocol.Bson.UTC
  doctest Bson.Encoder.Protocol.List
  doctest Bson.Encoder.Protocol.Map

end
