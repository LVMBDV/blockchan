require "./payload"

module Blockchan
  struct Message
    getter command : Command
    getter payload : Payload

    def initialize(@payload)
      @command = @payload.command
    end

    def initialize(pull : JSON::PullParser)
      pull.read_begin_object
      expect_key "command", from: pull
      @command = Command.parse(pull.read_string)
      expect_key "arguments", from: pull
      @payload = payload_type.new(pull)
      pull.read_end_object
    end

    def to_json(json : JSON::Builder)
      json.start_object
      json.field("command", @command.to_s.downcase)
      json.field("arguments", @payload)
      json.end_object
    end

    def to_io(io : IO, format : IO::ByteFormat = IO::ByteFormat::SystemEndian)
      self.to_json(io)
      io.write_byte(0x0A_u8)
    end

    def self.from_io(io : IO, format : IO::ByteFormat = IO::ByteFormat::SystemEndian)
      self.from_json(io.read_line)
    end

    def payload_type
      Payload.lookup(@command)
    end

    private def expect_key(key : String, from : JSON::PullParser)
      raise "expected key #{key}" if from.read_object_key != key
    end

    {% for payload in Command.constants %}
      {% if (::Blockchan::Payload.all_subclasses.map { |t| t.name.split("::")[-1] }.includes? payload.stringify) %}
        def self.{{payload.downcase}}(*args)
          Message.new(Payloads::{{payload}}.new(*args))
        end
      {% end %}
    {% end %}
  end
end
