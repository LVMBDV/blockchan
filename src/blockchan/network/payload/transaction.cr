require "../payload"
require "../../blockchain/transaction"

module Blockchan::Payloads
  class Transaction < Payload
    JSON.mapping(transaction: Blockchan::Transaction)

    def initialize(@transaction)
    end
  end
end
