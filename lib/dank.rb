require 'dank/version'
require 'redis'

REDIS = Redis.new

module Dank
  def self.suggest(prefix, count = 5)
    results = []
    rangelen = 100
    start = REDIS.zrank(:tags,prefix)
    return [] if !start

    while results.length != count
      range = REDIS.zrange(:tags,start,start+rangelen-1)
      start += rangelen
      break if !range or range.length == 0
      range.each {|entry|
        minlen = [entry.length,prefix.length].min
        if entry[0...minlen] != prefix[0...minlen]
          count = results.count
          break
        end
        if entry[-1..-1] == "+" and results.length != count
          results << entry[0...-1]
        end
      }
    end
    return results
  end

  def self.add(tag)
    tag.strip!
    (1..(tag.length)).each do |l|
        prefix = tag[0...l]
        REDIS.zadd(:tags,0,prefix)
    end
    REDIS.zadd(:tags,0,tag+"+")
  end
end
