require "json"
require "big"

module Blockchan
  class PostFile
    JSON.mapping(
      name: String,
      data: String
    )

    def initialize(@name, @data)
    end
  end

  class Post
    SUBJECT_MAX_LEN = 80
    POSTER_MAX_LEN  = 80
    BOARD_MAX_LEN   = 80

    JSON.mapping(
      parent: BigInt?,
      board: String?,
      poster: String?,
      subject: String?,
      body: String,
      files: Array(PostFile)?
    )

    def initialize(@body, @parent = nil, @poster = nil, @subject = nil, @files = nil)
    end
  end
end
