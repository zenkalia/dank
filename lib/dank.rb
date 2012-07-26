require 'dank/version'
require 'redis'

module Dank
  class Tags
    include Enumerable

    def initialize(o)
      @setkey ||= "user#{o.id}"
      @tags_array = redis.zrange(@setkey,0,-1)
    end

    def add(tag)
      Dank.add(tag)
      redis.zadd(@setkey,redis.zcard(@setkey),tag)
      @tags_array = redis.zrange(@setkey,0,-1)
    end

    def get_array
      @tags_array
    end

    def redis
      @redis ||= Dank.redis
    end
  end

  module Taggable
    def tags
      @tags ||= Dank::Tags.new(self)
      @tags.get_array
    end

    def add_tag(tag)
      @tags.add tag
    end
  end

  def self.redis
    @redis ||= Redis.new
  end

  def self.suggest(prefix, count = 5)
    results = []
    rangelen = 100
    start = redis.zrank(:tags,prefix)
    return [] if !start

    while results.length != count
      range = redis.zrange(:tags,start,start+rangelen-1)
      start += rangelen
      break if !range or range.length == 0
      range.each {|entry|
        minlen = [entry.length,prefix.length].min
        if entry[0...minlen] != prefix[0...minlen]
          count = results.count
          break
        end
        if entry[-1] == "+" and results.length != count
          results << entry[0...-1]
        end
      }
    end
    return results
  end

  def self.add(tag)
    tag.strip!
    tag.length.downto(1).each do |l|
      prefix = tag[0...l]
      break unless redis.zadd(:tags,0,prefix)
    end
    redis.zadd(:tags,0,tag+"+")
  end
end
