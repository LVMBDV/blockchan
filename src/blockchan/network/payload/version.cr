require "../payload"
require "../../version"

module Blockchan::Payloads
  class Version < Payload
    JSON.mapping(
      version: VersionTuple,
      block_height: UInt64,
      address: String
    )

    def initialize(@version, @block_height, @address)
    end
  end

  class VersionAck < EmptyPayload
  end
end
