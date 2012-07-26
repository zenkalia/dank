require 'redis'
REDIS = Redis.new
WORDS = 'words'

#redis.del words
count = 0
f = File.open '/usr/share/dict/words', 'r'
#f = File.open 'tagbank.txt', 'r'
f.each_line do |n|
  n.strip!
  (1..(n.length)).each do |l|
      prefix = n[0...l]
      redis.zadd(WORDS,0,prefix)
  end
  redis.zadd(WORDS,0,n+"+")
end
