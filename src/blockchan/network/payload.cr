require "json"

require "./command"

module Blockchan
  abstract class Payload
    @@subclasses = Hash(Command, Payload.class).new

    abstract def initialize(pull : JSON::PullParser)
    abstract def to_json(json : JSON::Builder)

    def command
      Command.parse(self.class.name.split("::")[-1])
    end

    def self.bind(command : Command, subclass : Payload.class)
      @@subclasses[command] = subclass
    end

    def self.lookup(command : Command)
      @@subclasses[command]
    end

    def self.subclasses
      @@subclasses
    end

    macro inherited
      command = Command.parse?({{@type.name.stringify.split("::")[-1]}})
      Blockchan::Payload.bind(command, {{@type}}) if !command.nil?
    end
  end

  abstract class EmptyPayload < Payload
    def initialize
    end

    def initialize(pull : JSON::PullParser)
      pull.read_null
    end

    def to_json(json : JSON::Builder)
      json.null
    end
  end
end

require "./payload/*"
