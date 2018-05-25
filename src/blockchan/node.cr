require "./network/peer"
require "./blockchain/blockchain"
require "./blockchain/wallet"

module Blockchan
  class Node
    DEFAULT_PORT       = 9000
    LONELY_TIME        = 1.seconds
    TARGET_PEERS       = 5
    ASK_AGAIN          = 1.hours
    CONNECT_TIMEOUT    = 5.seconds
    PEER_QUALITY       = 0.7
    MAX_TRANSACTIONS   = 100
    BLOCK_BUFFER_SIZE  =   5
    MAX_BLOCK_REQUESTS =   5

    getter peers = Hash(String, Peer).new
    getter socket : TCPServer
    getter asked_for_peers = Hash(Peer, Time).new
    getter banned_peers = Set(String).new
    getter forks : Hash(UInt64, Set(Blockchain)) = {0_u64 => Set(Blockchain).new([Blockchan::Blockchain.new([Blockchan::Block.genesis])])}
    getter wallet : Wallet
    @new_transactions = Channel::Buffered(Transaction).new(MAX_TRANSACTIONS)
    @new_blocks = Channel::Buffered(Block).new(BLOCK_BUFFER_SIZE)

    def initialize(@port = DEFAULT_PORT, bootstrap_peers = [] of String, @wallet = Wallet.new, @miner = false, @slow = false)
      @socket = TCPServer.new(@port)

      bootstrap_peers.each do |addr|
        connect_to_peer addr
      end

      spawn do # accept connections
        while client = @socket.accept?
          address = client.remote_address.port.to_s
          spawn handle_peer(Peer.new(client, slow: @slow))
        end
      end

      spawn do
        until @socket.closed?
          if @peers.size < TARGET_PEERS
            ask_for_peers
          end
          sleep LONELY_TIME * (Math.max(@peers.size, TARGET_PEERS + 1) - TARGET_PEERS)
        end
      end

      spawn do
        until @socket.closed?
          transactions = Set(Transaction).new
          until (@new_transactions.empty?)
            transactions.add(@new_transactions.receive)
          end

          sleep (5 + Random.rand(5)).seconds
          if @miner
            block = Blockchan::Block.build(longest_fork, @wallet.generate_address, transactions.to_a, Time.now)
            until (@new_blocks.full?) || block.solved?
              block.header.nonce = (block.header.nonce || 0_u32).succ
              block.update_checksum
            end
            if block.solved?
              puts "Mined block #{block.checksum.to_s(base: 16)[0, 8]}..."
              process_block(block)
              @peers.values.each { |peer| peer.send(Message.block(block)) }
            end
          end

          until @new_blocks.empty?
            process_block(@new_blocks.receive)
          end
        end
      end
    end

    def process_block(block : Block)
      return if !block.solved?

      chain = latest_forks.find { |fork|
        previous_block = fork.get_block?(block.header.index - 1)
        previous_block && (previous_block.checksum == block.header.previous)
      }

      fork_block = chain && chain.get_block?(block.header.index)
      return if fork_block && (fork_block.checksum == block.checksum)

      if chain
        if block.header.index == (chain.current_height)
          chain.blocks.push(block)
          @wallet.process_block(block, chain)
        elsif block.header.index < (chain.current_height)
          new_fork = chain.fork(block.header.index - 1)
          new_fork.blocks.push(block)
          @wallet.process_block(block, new_fork)
          @forks[block.header.index] = (@forks[block.header.index]? || Set(Blockchain).new).add(new_fork)
        end
      end
    end

    def find_fork?(block : Block)
      offset = forks.keys.min { |offset| block.header.index - offset }
      forks[offset].find { |fork| fork.blocks.size }
    end

    def address
      socket.local_address.port.to_s
    end

    private def add_peer(socket : TCPSocket, address : String)
      spawn handle_peer(Peer.new(socket, address, slow: @slow))
    end

    def connect_to_peer(addr : String)
      begin
        unless (@peers.includes? addr) || (addr == self.address)
          socket = TCPSocket.new("localhost", port: addr.to_i32, connect_timeout: CONNECT_TIMEOUT)
          add_peer(socket, addr)
        end
        true
      rescue error
        false
      end
    end

    def find_block?(id : BigInt, index : UInt64)
      fork = latest_forks.find { |fork|
        block = fork.get_block?(index)
        block && (block.checksum == id)
      }
      fork && fork.get_block(index)
    end

    def ban(peer : Peer)
      # puts "Banned peer #{peer.address}"
      # @banned_peers.add(peer.address[0])
      # peer.disconnect
    end

    # ------------------E
    def longest_fork
      latest_forks.max_by { |bc| bc.current_height }
    end

    def latest_forks
      @forks[@forks.keys.max]
    end

    private def handle_peer(peer : Peer)
      peer.send(Message.version(::Blockchan::VERSION, longest_fork.current_height, self.address))
      @peers[peer.address] = peer
      until peer.socket.closed?
        message = peer.receive
        case message.command
        when Command::GetAddr
          friends = @peers.values.sample(Math.min(@peers.size, Payloads::Addr::MAX_ADDRS)).map { |friend| friend.address }
          peer.send(Message.addr(friends))
          # puts "Sent #{friends.size} peers to #{peer.address}"
        when Command::Addr
          if @asked_for_peers.keys.includes? peer
            addresses = message.payload.as(Payloads::Addr).addresses.first(Math.max(0, TARGET_PEERS - @peers.size))
            # puts "Received #{addresses.size} peers from #{peer.address}"
            quality = addresses.count { |addr| connect_to_peer(addr) }.to_f / addresses.size
            @asked_for_peers.delete(peer)
            ban peer if quality < PEER_QUALITY
          else
            ban peer
          end
        when Command::Transaction
          tx = message.payload.as(Payloads::Transaction).transaction
          puts "Received transaction #{tx.checksum.to_s(base: 16)[0, 8]}... from #{peer.address}"
          if latest_forks.any? { |fork| tx.valid?(fork) }
            @new_transactions.send(tx)
            @peers.values.each { |p| p.send(Message.transaction(tx)) if p != peer }
          else
            ban peer
          end
        when Command::GetBlock
          block_requests = message.payload.as(Payloads::GetBlock).blocks
          block_requests.map { |rt| find_block?(rt[:id], rt[:index]) }.each do |block|
            peer.send(Message.block(block)) unless block.nil?
            puts "Sent block #{block.checksum.to_s(base: 16)[0, 8]} from #{peer.address}" unless block.nil?
          end
        when Command::Block
          block = message.payload.as(Payloads::Block).block
          puts "Received block #{block.checksum.to_s(base: 16)[0, 8]} from #{peer.address}"
          if find_block?(block.checksum, block.header.index)
            puts "Block #{block.checksum.to_s(base: 16)[0, 8]} was already in the chain."
          else
            latest_forks.each do |fork|
              begin
                block.valid!(fork)
                puts "Block #{block.checksum.to_s(base: 16)[0, 8]} was valid."
                @new_blocks.send(block)
                @peers.values.each { |p| p.send(Message.block(block)) if p != peer }
              rescue error
                puts "Block #{block.checksum.to_s(base: 16)[0, 8]} was invalid because '#{error}'."
              end
            end
          end
        end
      end
    ensure
      @peers.delete(peer.address)
    end

    private def ask_for_peers
      now = Time.now
      @peers.each_value do |peer|
        last_asked = @asked_for_peers[peer]?
        if last_asked.nil? || ((now - last_asked) >= ASK_AGAIN)
          peer.send(Message.getaddr)
          # puts "Asked #{peer.address} for peers"
          @asked_for_peers[peer] = now
          break
        end
      end
    end
  end
end
