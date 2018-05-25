require "../payload"
require "../../blockchain/block"

module Blockchan::Payloads
  class GetBlock < Payload
    alias BlockRequest = NamedTuple(id: BigInt, index: UInt64)
    JSON.mapping(blocks: Array(BlockRequest))

    def initialize(@blocks)
    end
  end

  class Block < Payload
    JSON.mapping(block: Blockchan::Block)

    def initialize(@block)
    end
  end
end
