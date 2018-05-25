require "./block"

module Blockchan
  class Blockchain
    getter blocks
    @parent : Blockchain?
    @offset : UInt64

    def initialize(@blocks = [] of Block, @parent = nil, @offset = 0_u64)
    end

    def is_fork?
      !@parent.nil?
    end

    def forked_at?
      (is_fork?) ? @offset : 0_u64
    end

    def forked_from?
      @parent && @parent[0]
    end

    def fork(cutoff : UInt64)
      Blockchain.new(@blocks[0, cutoff], self, current_height)
    end

    def current_height
      forked_at? + @blocks.size.to_u64
    end

    def get_block?(index : Int)
      if index < 0
        nil
      elsif is_fork? && (index < @offset)
        @parent.not_nil!.get_block?(index)
      else
        @blocks[index]?
      end
    end

    def get_block(index : Int)
      if index < 0
        raise "negative index"
      elsif is_fork? && (index < @offset)
        @parent.not_nil!.get_block(index)
      else
        @blocks[index]
      end
    end

    def last_block
      @blocks[-1]
    end

    def current_difficulty
      difficulty_at(current_height)
    end

    def difficulty_at(height : UInt64, time = Time.now)
      12
    end

    def reward_at(height : UInt64)
      100
    end
  end
end
