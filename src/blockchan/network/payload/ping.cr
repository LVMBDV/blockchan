require "../payload"

module Blockchan::Payloads
  class Ping < Payload
    JSON.mapping(nonce: UInt64)

    def initialize(@nonce = Random.rand(UInt64::MAX))
    end
  end

  class Pong < Ping
  end
end
