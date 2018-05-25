require "big"

struct BigInt
  def initialize(pull : JSON::PullParser)
    hex = pull.read_string
    LibGMP.init_set_str(out @mpz, hex.to_s, 16)
  end

  def to_json(json : JSON::Builder)
    json.string(self.to_s(base: 16))
  end

  def to_bytes(format : IO::ByteFormat = IO::ByteFormat::LittleEndian)
    hex = self.to_s(base: 16)
    hex = "0" + hex if hex.size % 2 != 0
    (format == IO::ByteFormat::SystemEndian) ? hex.hexbytes : hex.hexbytes.reverse!
  end
end
