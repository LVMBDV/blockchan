require "openssl"
require "big"

require "./bigint_serialization"

module Blockchan
  SHA256D_OUTPUT_SIZE = 32

  module SHA256D
    def sha256d(data : String | Bytes)
      first_cycle = OpenSSL::Digest.new("sha256").update(data)
      second_cycle = OpenSSL::Digest.new("sha256").update(first_cycle.digest)
      BigInt.new(second_cycle.hexdigest, base: 16)
    end
  end
end
