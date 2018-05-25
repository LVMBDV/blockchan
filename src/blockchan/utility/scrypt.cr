require "big"
require "scrypt"

require "./bigint_serialization"

module Blockchan
  SCRYPT_N = 0x10000
  SCRYPT_R =       1
  SCRYPT_P =       1
  SCRYPT_K =     512

  module Scrypt
    def scrypt_hash(data : String | Bytes, salt : String | Bytes, n : Int32 = SCRYPT_N, r : Int32 = SCRYPT_R, p : Int32 = SCRYPT_P, k : Int32 = SCRYPT_K)
      buffer = Bytes.new(k)
      status = LibScrypt.crypto_scrypt(data, data.bytesize, salt, salt.bytesize, n, r, p, buffer, buffer.bytesize)
      raise "libscrypt threw an error" if status != 0
      BigInt.new(buffer.hexstring, base: 16)
    end
  end
end
