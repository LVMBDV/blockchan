require "../payload"

module Blockchan::Payloads
  class Addr < Payload
    MAX_ADDRS = 100

    JSON.mapping(addresses: Array(String))

    def initialize(@addresses)
      raise "too many" if @addresses.size > MAX_ADDRS
    end
  end

  class GetAddr < EmptyPayload
  end
end
