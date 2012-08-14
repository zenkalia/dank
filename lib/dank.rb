require 'dank/version'
require 'dank/mixin'
require 'redis'

module Dank
  def self.config config
    @app_name = config[:app_name]
  end

  def self.app_name
    @app_name || 'hate'
  end

  def self.redis
    @redis ||= Redis.current
  end

  def self.sanitize(s)
    s.squeeze('  ').strip.downcase
  end

  def self.suggest_tags(prefix, count = 5)
    prefix = sanitize prefix
    results = []
    rangelen = 100
    start = redis.zrank('dank:tags',prefix)
    return [] if !start

    while results.length != count
      range = redis.zrange('dank:tags',start,start+rangelen-1)
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
    tag = sanitize tag
    tag.length.downto(1).each do |l|
      prefix = tag[0...l]
      break unless redis.zadd('dank:tags',0,prefix)
    end
    redis.zadd('dank:tags',0,tag+"+")
  end

  def self.remove(tag)
    tag = sanitize tag
    redis.zrem 'dank:tags', "#{tag}+"
    tag.length.downto(1).each do |l|
      prefix = tag[0...l]
      break if suggest_tags(prefix).count > 0
      redis.zrem 'dank:tags', prefix
    end
  end

  def self.distance(key1, key2)
    intersection = redis.multi do
      key = "danktemp:#{Random.rand(500)}"
      redis.zinterstore key, [key1,
                              key2]
      redis.zrange key, 0, -1
      redis.del key
    end
    return 0 if intersection[0] == 0
    intersection[0] / (redis.zcard(key1).to_f +
                       redis.zcard(key2) ) * 2
  end
end
