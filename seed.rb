require 'redis'

REDIS = Redis.new

REDIS.del 'dank:tags'
count = 0
#f = File.open '/usr/share/dict/words', 'r'
f = File.open 'tagbank.txt', 'r'
f.each_line do |n|
  n.strip!
  (1..(n.length)).each do |l|
      prefix = n[0...l]
      REDIS.zadd('dank:tags',0,prefix)
  end
  REDIS.zadd('dank:tags',0,n+"+")
end
