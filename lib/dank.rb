require 'dank/version'
require 'dank/mixin'
require 'redis'

module Dank
  def self.config config
    @app_name = config[:app_name]
    @autocomplete_on = config[:autocomplete]
  end

  def self.app_name
    @app_name || 'hate'
  end

  def self.autocomplete_on
    return @autocomplete_on unless @autocomplete_on == nil
    true
  end

  def self.redis
    @redis ||= Redis.current
  end

  def self.sanitize(s)
    s.to_s.squeeze('  ').strip.downcase
  end

  def self.autocomplete(prefix, count = 5)
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

  def self.tags
    count = redis.zcount('dank:tags', '-inf', '+inf')
    redis.zrange('dank:tags', 0, count).reduce([]) do |memo, tag|
      memo << tag[0..-2] if tag[-1] === '+'
      memo
    end
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
      break if autocomplete(prefix).count > 0
      redis.zrem 'dank:tags', prefix
    end
  end

  def self.distance(key1, key2)
    intersection = redis.sinter([key1, key2]).count
    return 0 if intersection == 0
    intersection / (redis.scard(key1).to_f +
                    redis.scard(key2) ) * 2
  end
end
