use Mix.Config

config :bson,
    decoder_new_doc: &Bson.Decoder.elist_to_atom_map/1
