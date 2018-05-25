# Copyright © 2017-2018 The SushiChain Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the SushiChain Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

require "big"

require "./sha256d"

module Blockchan::ECDSA
  include SHA256D

  def mod_inv(a : BigInt, mod : BigInt)
    lim, him = BigInt.new(1), BigInt.new(0)
    low, high = a % mod, mod

    while low > 1
      ratio = high / low
      nm = him - lim * ratio
      new = high - low * ratio
      him = lim
      high = low
      lim = nm
      low = new
    end

    lim % mod
  end

  class Point
    getter x : BigInt
    getter y : BigInt

    include ::Blockchan::ECDSA

    def initialize(@x : BigInt, @y : BigInt, @group : Group = Secp256k1.instance, @infinity : Bool = false)
    end

    def mod : BigInt
      @group._p
    end

    def _a
      @group._a
    end

    def _b
      @group._b
    end

    def +(other : Point) : Point
      return other if infinity?
      return self if other.infinity?

      lambda = ((other.y - @y) * mod_inv(other.x - @x, mod)) % mod
      x = (lambda ** 2 - @x - other.x) % mod
      y = (lambda * (@x - x) - @y) % mod

      return Point.new(x, y, @group)
    end

    def double : Point
      return self if infinity?

      lambda = ((3 * (@x ** 2) + _a) * mod_inv(2 * @y, mod)) % mod
      x = (lambda ** 2 - 2 * @x) % mod
      y = (lambda * (@x - x) - @y) % mod

      Point.new(x, y, @group)
    end

    def *(other : BigInt) : Point
      res = @group.infinity
      v = self

      while other > 0
        res = res + v if other.odd?
        v = v.double
        other >>= 1
      end

      res
    end

    def is_on? : Bool
      (@y ** 2 - @x ** 3 - _b) % mod == 0
    end

    def infinity? : Bool
      @infinity
    end
  end

  abstract class Group
    abstract def _gx : BigInt
    abstract def _gy : BigInt
    abstract def _a : BigInt
    abstract def _b : BigInt
    abstract def _n : BigInt
    abstract def _p : BigInt

    include ::Blockchan::ECDSA

    def gp : Point
      Point.new(_gx, _gy, self)
    end

    def infinity : Point
      Point.new(BigInt.new(0), BigInt.new(0), self, true)
    end

    def create_key_pair(key_length : Int)
      loop do
        random_hex = Random::Secure.hex(key_length)
        next if random_hex[0, 2].to_i(base: 16) < 0xFF
        secret_key = BigInt.new(random_hex, base: 16)
        public_key = gp * secret_key
        next if public_key.x.to_s(base: 16).size != key_length
        next if public_key.y.to_s(base: 16).size != key_length
        return {secret_key: secret_key, public_key: public_key}
      end
    end

    def sign(secret_key : BigInt, message : String | Bytes) : Array(BigInt)
      hash = sha256d(message)

      loop do
        key_length = secret_key.to_s(base: 16).size / 2
        random_keypair = create_key_pair(key_length)
        k = random_keypair[:secret_key]
        r = random_keypair[:public_key].x
        next if r == 0
        s = (mod_inv(k, _n) * (hash + secret_key * r)) % _n
        next if s == 0
        return [r, s]
      end
    end

    def verify(public_key : Point, message : String | Bytes, r : BigInt, s : BigInt) : Bool
      hash = sha256d(message)

      c = mod_inv(s, _n)

      u1 = (hash * c) % _n
      u2 = (r * c) % _n
      xy = (gp * u1) + (public_key * u2)

      v = xy.x % _n
      v == r
    end
  end

  class Secp256k1 < Group
    @@instance = new

    def self.instance
      @@instance
    end

    def _gx : BigInt
      BigInt.new("79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798", base: 16)
    end

    def _gy : BigInt
      BigInt.new("483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8", base: 16)
    end

    def _a : BigInt
      BigInt.new("0000000000000000000000000000000000000000000000000000000000000000", base: 16)
    end

    def _b : BigInt
      BigInt.new("0000000000000000000000000000000000000000000000000000000000000007", base: 16)
    end

    def _n : BigInt
      BigInt.new("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141", base: 16)
    end

    def _p : BigInt
      BigInt.new("fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f", base: 16)
    end
  end
end
