require 'dank/version'
require 'redis'

APP_NAME = 'hate'
GETS_TAGS = 'user'

module Dank
  class Tags
    include Enumerable

    def initialize(o)
      @id ||= o.id
      @setkey ||= "#{APP_NAME}:#{GETS_TAGS}:#{@id}"
      @tags_array = redis.zrange(@setkey,0,-1)
    end

    def add(tag)
      tag = Dank.sanitize tag
      Dank.add(tag)
      redis.zadd(@setkey,redis.zcard(@setkey)+1,tag)
      @tags_array = redis.zrange(@setkey,0,-1)
      Dank.update_intersections(@id)
    end

    def remove(tag)
      tag = Dank.sanitize tag
      redis.zrem(@setkey,tag)
      @tags_array = redis.zrange(@setkey,0,-1)
      Dank.update_intersections(@id)
    end

    def get_array
      @tags_array
    end

    def reorder(tags)
      count = 1
      tags.each do |tag|
        redis.zadd(@setkey,count,tag)
        count+=1
      end
      @tags_array = redis.zrange(@setkey,0,-1)
      Dank.update_intersections(@id)
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

    def remove_tag(tag)
      @tags.remove tag
    end

    def reorder(tags)
      @tags.reorder(tags)
    end
  end

  def self.redis
    @redis ||= Redis.new
  end

  def self.sanitize(s)
    s.squeeze('  ').strip.downcase
  end

  def self.suggest(prefix, count = 5)
    prefix = sanitize prefix
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

  def self.update_intersections(id)
    keys = redis.keys "#{APP_NAME}:#{GETS_TAGS}:*"
    keys.each do |key|
      other_id = key.split(':').last
      both = [id.to_s, other_id.to_s].sort
      one = both.first
      two = both.last
      redis.zinterstore "#{APP_NAME}:distance:#{GETS_TAGS}:#{one}:#{two}", ["#{APP_NAME}:#{GETS_TAGS}:#{one}", "#{APP_NAME}:#{GETS_TAGS}:#{two}"]
    end
  end

  def self.add(tag)
    tag = sanitize tag
    tag.strip!
    tag.length.downto(1).each do |l|
      prefix = tag[0...l]
      break unless redis.zadd(:tags,0,prefix)
    end
    redis.zadd(:tags,0,tag+"+")
  end
end
