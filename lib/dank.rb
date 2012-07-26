require 'dank/version'
require 'redis'

REDIS = Redis.new
WORDS= 'words'

module Dank
  def self.suggest_word(prefix, count = 5)
    results = []
    rangelen = 100
    start = REDIS.zrank(WORDS,prefix)
    return [] if !start

    while results.length != count
      range = REDIS.zrange(WORDS,start,start+rangelen-1)
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

  def self.add_word(word)
    word.strip!
    (1..(word.length)).each do |l|
        prefix = word[0...l]
        REDIS.zadd(WORDS,0,prefix)
    end
    REDIS.zadd(WORDS,0,word+"+")
  end
end
