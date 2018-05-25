require "socket"

require "../version"
require "./message"

module Blockchan
  class Peer
    RECV_MSG_BUFFER_SIZE = 20
    SEND_MSG_BUFFER_SIZE = 20

    PING_INTERVAL = 3 * 60

    getter socket : TCPSocket
    @address = Atomic(String).new("")
    @last_seen = Atomic(Int64).new(Time.now.epoch)
    @version = Atomic(String).new("")
    @block_height = Atomic(UInt64).new(0_u64)
    @awaiting_ping = Atomic(UInt64).new(0_u64)
    @received_messages = Channel::Buffered(Message).new(RECV_MSG_BUFFER_SIZE)
    @messages_to_send = Channel::Buffered(Message).new(SEND_MSG_BUFFER_SIZE)

    def initialize(@socket, addr : String? = nil, @slow : Bool = false)
      @address.set(addr) if addr
      _receive if addr.nil?

      spawn do
        until @socket.closed?
          _receive
        end
      end

      spawn do
        until @socket.closed?
          _send
        end
      end

      spawn do
        until @socket.closed?
          if (Time.now.epoch - @last_seen.get) > PING_INTERVAL
            if @awaiting_ping.get != 0
              disconnect
              break
            end
            message = Message.ping
            @awaiting_ping.set(message.payload.as(Payloads::Ping).nonce)
            send(message)
          end
          sleep (Time.now.epoch - @last_seen.get).seconds
        end
      end
    end

    def address
      addr = @address.get
      raise "first message was not version" if addr.empty?
      addr
    end

    def receive
      @received_messages.receive
    end

    def send(message : Message)
      @messages_to_send.send(message)
    end

    def disconnect
      @socket.close
    end

    private def _receive
      message = process(Message.from_io(@socket))
      @last_seen.set(Time.now.epoch)
      @received_messages.send(message) if message
    end

    private def _send
      message = @messages_to_send.receive
      message.to_io @socket
    end

    private def process(message : Message)
      unhandled = false
      sleep 500.milliseconds if @slow

      case message.command
      when Command::Ping
        send(Message.pong(message.payload.as(Payloads::Ping).nonce))
      when Command::Pong
        raise "ping nonce mismatch" if (message.payload.as(Payloads::Pong).nonce != @awaiting_ping.get)
        @awaiting_ping.set 0_u64
      when Command::Version
        @version.set message.payload.as(Payloads::Version).version.to_s
        @block_height.set message.payload.as(Payloads::Version).block_height
        @address.set message.payload.as(Payloads::Version).address
        send(Message.versionack)
      when Command::VersionAck
      else
        unhandled = true
      end

      unhandled ? message : nil
    end
  end
end
