require "./transaction"
require "../utility/scrypt"
require "../utility/sha256d"

module Blockchan
  class BlockHeader
    include SHA256D

    TIMESTAMP_ACCURACY = 1.5.hours

    JSON.mapping(
      index: UInt64,
      previous: BigInt,
      timestamp: Time,
      difficulty: Int32?,
      merkle_root: BigInt,
      nonce: UInt32?
    )

    def initialize(@index, @previous, @timestamp, @difficulty, @merkle_root, @nonce)
    end

    def self.build(blockchain : Blockchain, timestamp = Time.now, nonce = 0_u32)
      self.new(blockchain.current_height, blockchain.last_block.checksum, timestamp, blockchain.current_difficulty, BigInt.zero, nonce)
    end

    def checksum
      nonce_saved = @nonce
      difficulty_saved = @difficulty
      @nonce = @difficulty = nil
      checksum = sha256d(self.to_json)
      @nonce = nonce_saved
      @difficulty = difficulty_saved
      checksum
    end

    def valid!(blockchain : Blockchain, time : Time = Time.now)
      return if (@index == 0) && (checksum == Block.genesis.header.checksum)
      raise "invalid backlink" if blockchain.get_block(@index - 1).checksum != @previous
      raise "expired timestamp" if (@timestamp - time).abs > TIMESTAMP_ACCURACY
      raise "wrong difficulty" if @difficulty != blockchain.difficulty_at(@index, time)
    end
  end

  class Block
    include SHA256D
    include Scrypt

    GENESIS_BLOCK = Block.new(0_64, BigInt.zero, 8, [Transaction.new(outputs: [TransactionOutput.new(100_u64, BigInt.new("79557399618875183764637239225983144318342880118552058958253932613948925863573"))], post: Post.new("hello"))], BigInt.new("79557399618875183764637239225983144318342880118552058958253932613948925863573"), Time.new(2018, 4, 20))

    JSON.mapping(
      header: BlockHeader,
      transactions: Array(Transaction)
    )

    property checksum = BigInt.zero

    def initialize(@header, @transactions)
    end

    def initialize(index : Int, previous : BigInt, difficulty : Int32, transactions : Array(Transaction), solver : BigInt, timestamp = Time.now, nonce = 0_u32)
      @header = BlockHeader.new(index.to_u64, previous, timestamp, difficulty, BigInt.zero, nonce)
      @transactions = transactions
      update_merkle_root
      update_checksum
    end

    def self.build(blockchain : Blockchain, solver : BigInt, transactions = [] of Transaction, timestamp = Time.now, nonce = 0_u32)
      block = self.new(BlockHeader.build(blockchain, timestamp, nonce), transactions)
      block.make_coinbase(solver, blockchain)
      block.update_merkle_root
      block
    end

    def self.genesis
      GENESIS_BLOCK
    end

    def make_coinbase(solver : BigInt, blockchain : Blockchain)
      @transactions.unshift(Transaction.coinbase(profit(blockchain), solver))
    end

    def update_solver(solver : BigInt)
      coinbase.outputs[0].recipient = solver
    end

    def coinbase
      @transactions[0]
    end

    def forks?(blockchain : Blockchain)
      block = blockchain.get_block?(blockchain)
      block && (block.checksum != self.checksum)
    end

    def valid!(blockchain : Blockchain)
      @header.valid!(blockchain)
      raise "wrong merkle" if @header.merkle_root != self.calculate_merkle_root
      raise "too many transactions" if @transactions.size > Int32::MAX
      @transactions.each { |tx| tx.valid!(blockchain, self) }
    end

    def valid?(blockchain : Blockchain)
      begin
        self.valid!(blockchain)
        true
      rescue
        false
      end
    end

    def reward(blockchain : Blockchain)
      blockchain.reward_at @header.index
    end

    def total_fees(blockchain : Blockchain)
      @transactions.each.skip(1).sum { |tx| tx.fee(blockchain) }
    end

    def profit(blockchain : Blockchain)
      reward(blockchain) + total_fees(blockchain)
    end

    def solve!
      until solved?
        @header.nonce = (@header.nonce || 0_u32).succ
        update_checksum
      end
      checksum
    end

    def solved?
      raise "negative difficulty" if header.difficulty.not_nil! < 0
      leading_bits > header.difficulty.not_nil!
    end

    def leading_bits
      bits = (SCRYPT_K * 8) - checksum.to_s(base: 2).size
    end

    def checksum
      update_checksum if @checksum.zero?
      @checksum
    end

    def update_checksum
      data = @header.checksum.to_bytes
      salt = @header.nonce.unsafe_as(StaticArray(UInt8, 4)).to_slice
      @checksum = scrypt_hash(data, salt)
    end

    def calculate_merkle_root
      return BigInt.zero if @transactions.size == 0
      current_hashes = @transactions.map { |tx| tx.checksum.to_bytes }
      buffer = Bytes.new(SHA256D_OUTPUT_SIZE * 2)
      until current_hashes.size == 1
        next_hashes = [] of Bytes
        current_hashes.in_groups_of(2, filled_up_with: current_hashes[-1]) do |pair|
          pair[0].copy_to(buffer)
          pair[1].copy_to(buffer + SHA256D_OUTPUT_SIZE)
          next_hashes.push(buffer.dup)
        end
        current_hashes = next_hashes
      end
      BigInt.new(current_hashes.pop.hexstring, base: 16)
    end

    def update_merkle_root
      @header.merkle_root = self.calculate_merkle_root
    end
  end
end
