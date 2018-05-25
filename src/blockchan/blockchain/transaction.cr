require "./key"
require "./post"
require "./block"
require "./blockchain"

module Blockchan
  struct TransactionInput
    JSON.mapping(
      block_hash: BigInt,
      block_index: UInt64,
      transaction_index: Int32,
      output_index: Int32,
      public_key: PublicKey,
    )

    def initialize(@block_hash, @block_index, @transaction_index, @output_index, @public_key)
    end

    def origin(blockchain : Blockchain)
      blockchain.get_block(@block_index).transactions[@transaction_index]
    end

    def origin?(blockchain : Blockchain)
      blockchain.get_block?(@block_index).transactions[@transaction_index]?
    end

    def output(blockchain : Blockchain)
      self.origin(blockchain).outputs[@output_index]
    end

    def output?(blockchain : Blockchain)
      tx = self.origin?(blockchain)
      tx && tx.outputs[@output_index]?
    end

    def amount(blockchain : Blockchain)
      self.output(blockchain).amount
    end

    def amount?(blockchain : Blockchain)
      output = self.output?(blockchain)
      output && output.amount
    end
  end

  struct TransactionOutput
    JSON.mapping(
      amount: UInt64,   # Amount of tokens in transfer
      recipient: BigInt # Hash value of the recipient's public key
    )

    def initialize(@amount, @recipient)
    end
  end

  class Transaction
    include SHA256D

    JSON.mapping(
      inputs: Array(TransactionInput),
      outputs: Array(TransactionOutput),
      signatures: Array(Signature)?,
      post: Post?,
      lock_height: UInt64?
    )

    def initialize(@inputs = [] of TransactionInput, @outputs = [] of TransactionOutput, @signatures = nil, @post = nil, @lock_height = nil)
    end

    def self.coinbase(profit : Int, solver : BigInt)
      raise "negative profit" if profit < 0
      self.new(outputs: [TransactionOutput.new(profit.to_u64, solver)])
    end

    def checksum
      saved_signatures = @signatures
      @signatures = nil
      checksum = sha256d(self.to_json)
      @signatures = saved_signatures
      checksum
    end

    def total_input(blockchain : Blockchain)
      @inputs.sum { |txin| txin.amount(blockchain) }
    end

    def total_output
      @outputs.sum { |txout| txout.amount }
    end

    def fee(blockchain : Blockchain)
      total_input = self.total_input(blockchain)
      raise "transaction overspent" if (total_output > total_input)
      (total_input - total_output)
    end

    def valid!(blockchain : Blockchain, block : Block? = nil)
      raise "not enough signatures/inputs" unless (@signatures.nil? && @inputs.empty?) || (@signatures.not_nil!.size == @inputs.size)

      checksum = self.checksum
      block_height = block ? block.header.index : blockchain.current_height

      total_input = 0_u64
      @inputs.each_with_index do |txin, i|
        origin = txin.origin(blockchain)
        raise "locked tx " if (origin.lock_height.not_nil! < block_height)
        output = origin.outputs[txin.output_index]
        raise "invalid key" if output.recipient != txin.public_key.checksum
        raise "invalid signature" unless txin.public_key.verify(checksum.to_bytes, @signatures.not_nil![i])
        total_input += output.amount
      end

      total_input += block.profit(blockchain) if block && (block.coinbase.checksum == checksum)
      raise "overspent tx" if total_output > total_input
    end

    def valid?(blockchain : Blockchain, block : Block? = nil)
      begin
        self.valid!(blockchain, block)
        true
      rescue
        false
      end
    end
  end
end
