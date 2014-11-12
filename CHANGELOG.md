# v0.4.3-dev
* Decode crash if the buffer size is < 5, now it generates a %Bson.Decoder.Error{} return message
# v0.4.2
* new helper function `Bson.ObjectId.from_string/1`
# v0.4.1
* allow setting options to Bson.decode
* improve documentation
# v0.4.0
* prépartion pour elixir v1
* Bson.Regex is obsolete and replaced with Regex
* Improved error messages
* Keys of maps are strings when decoded, by default
* encoder prototcol does not fallback to any to allow custom implementation
* removed encoding / decoding of the triplet tuple representing a time stamp (need to implement locally if needed)
* UTC is implemented using struct `Bson.UTC`
* in `Bson.Bin`, subtypes are positif integer (<256) not a binary anymore
* all atom representing constant like :min_key are in small caps (used to be MIN_KEY)
* allow user specific encoding / decoding of binary
# v0.3.1
* compatible with Elixir v0.15.1
# v0.3
* compatible with Elixir v0.14.1
