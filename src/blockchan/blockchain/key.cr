require "json"

require "../utility/ecdsa"
require "../utility/bigint_serialization"
require "../utility/sha256d"

module Blockchan
  EC_KEY_SIZE = 64

  struct Signature
    JSON.mapping(r: BigInt, s: BigInt)

    def initialize(@r, @s)
    end
  end

  struct PublicKey
    include SHA256D

    JSON.mapping(x: BigInt, y: BigInt)

    def initialize(@x, @y)
    end

    def initialize(point : ECDSA::Point)
      @x = point.x
      @y = point.y
    end

    def checksum
      sha256d(self.to_json)
    end

    def verify(message : Bytes | String, signature : Signature)
      ECDSA::Secp256k1.instance.verify(ECDSA::Point.new(x, y), message, signature.r, signature.s)
    end
  end

  struct PrivateKey
    JSON.mapping(secret: BigInt)

    def initialize(@secret)
    end

    def sign(message : Bytes | String)
      r, s = ECDSA::Secp256k1.instance.sign(@secret, message)
      Signature.new(r, s)
    end
  end

  struct KeyPair
    JSON.mapping(private_key: PrivateKey, public_key: PublicKey)

    def initialize
      pair = ECDSA::Secp256k1.instance.create_key_pair(::Blockchan::EC_KEY_SIZE)
      @private_key = PrivateKey.new(pair[:secret_key])
      @public_key = PublicKey.new(pair[:public_key])
    end

    def initialize(@private_key, @public_key)
    end
  end
end
