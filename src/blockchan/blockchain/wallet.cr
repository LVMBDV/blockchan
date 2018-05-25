require "./key"
require "../utility/bigint_serialization"

module Blockchan
  struct Token
    JSON.mapping(
      block_hash: BigInt,
      block_index: UInt64,
      transaction_index: Int32,
      output_index: Int32,
      amount: UInt64,
      address: BigInt,
      lock_height: UInt64?
    )

    def initialize(@block_hash, @block_index, @transaction_index, @output_index, @amount, @address, @lock_height = nil)
    end

    def to_txin(public_key : PublicKey)
      raise "wrong public key" if @address != public_key.checksum
      TransactionInput.new(@block_hash, @block_index, @transaction_index, @output_index, public_key)
    end

    def self.from_txin(txin : TransactionInput, blockchain : Blockchain)
      self.new(txin.block_hash, txin.block_index, txin.transaction_index, txin.output_index, txin.amount(blockchain), txin.public_key.checksum)
    end
  end

  class Wallet
    JSON.mapping(
      keypairs: Hash(BigInt, KeyPair),
      tokens: Set(Token)
    )

    def initialize
      @keypairs = Hash(BigInt, KeyPair).new
      @tokens = Set(Token).new
    end

    def initialize(@keypairs, @tokens)
    end

    def total_balance
      @tokens.sum { |t| t.amount }
    end

    def generate_address
      keypair = KeyPair.new
      address = keypair.public_key.checksum
      raise "woah collision" if @keypairs.has_key?(address)
      @keypairs[address] = keypair
      address
    end

    def add_token(token : Token)
      raise "address not found" unless @keypairs.has_key?(token.address)
      tokens << token
    end

    def make_transaction(amount : UInt64, recipient : BigInt)
      raise "not enough tokens" if amount > total_balance

      tokens_to_spend = Array(Token).new
      tokens.each do |token|
        tokens_to_spend << token
        break if tokens_to_spend.sum { |t| t.amount } >= amount
      end

      tx = Transaction.new

      tokens_to_spend.each do |token|
        tx.inputs << token.to_txin(@keypairs[recipient].public_key)
      end

      total_output = tokens_to_spend.sum { |t| t.amount }
      tx.outputs << TransactionOutput.new(amount, recipient)
      tx.outputs << TransactionOutput.new(total_output - amount, generate_address) if total_output > amount

      tx
    end

    def sent_tokens(transaction : Transaction, blockchain : Blockchain)
      transaction.inputs.map { |txin| Token.from_txin(txin, blockchain) }.select { |token| @tokens.includes?(token) }
    end

    def received_tokens(transaction_index : Int, transaction : Transaction, block : Block, blockchain : Blockchain)
      related_outputs = transaction.outputs.select { |txout| @keypairs.has_key?(txout.recipient) }
      related_outputs.map_with_index { |txout, output_index|
        Token.new(block.checksum, block.header.index, transaction_index, output_index, txout.amount, txout.recipient)
      }
    end

    def process_block(block : Block, blockchain : Blockchain)
      block.transactions.each_with_index do |tx, i|
        sent_tokens(tx, blockchain).each do |token|
          @tokens.delete(token)
        end

        received_tokens(i, tx, block, blockchain).each do |token|
          token.lock_height = tx.lock_height
          @tokens.add(token)
        end
      end
    end
  end
end
