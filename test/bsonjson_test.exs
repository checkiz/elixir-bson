Code.require_file "test_helper.exs", __DIR__

defmodule BsonJson.Test do
  use ExUnit.Case

  test "Stringify" do
  	assert {"{}", ""} = BsonJson.stringify(Bson.encode(%{}))
  	assert {"{\"a\":1}", ""} = BsonJson.stringify(Bson.encode(%{a: 1}))
  	assert {"{\"a\":1.1}", ""} = BsonJson.stringify(Bson.encode(%{a: 1.1}))
  	assert {"{\"a\":\"ab\"}", ""} = BsonJson.stringify(Bson.encode(%{a: "ab"}))
  	assert {"{\"a\":\"a\",\"b\":\"b\"}", ""} = BsonJson.stringify(Bson.encode(%{a: "a", b: "b"}))
  	assert {"{\"a\":[1,2]}", ""} = BsonJson.stringify(Bson.encode(%{a: [1,2]}))
  end

  test "ObjectId" do
    term = %Bson.ObjectId{oid: <<82, 224, 252, 230, 0, 0, 2, 0, 3, 0, 0, 4>>}
    bson = Bson.encode(%{"0": term})

    assert {"{\"0\":\"52e0fce60000020003000004\"}", ""} == BsonJson.stringify(bson)
  end

end