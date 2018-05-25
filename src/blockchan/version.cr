module Blockchan
  struct VersionTuple
    getter major : Int32
    getter minor : Int32
    getter patch : Int32

    def initialize(@major, @minor, @patch)
    end

    def initialize(pull : JSON::PullParser)
      @major, @minor, @patch = pull.read_string.split(".").map { |s| s.to_i }
    end

    def to_json(json : JSON::Builder)
      json.string(self.to_s)
    end

    def to_s
      "#{@major}.#{@minor}.#{@patch}"
    end
  end

  VERSION = VersionTuple.new(0, 1, 0)
end
