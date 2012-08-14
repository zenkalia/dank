#!/usr/bin/env rake
require 'bundler/gem_tasks'
require 'dank'

def user num
  "user#{num}"
end

def tag num
  "tag#{num}"
end

class User
  include Dank::Taggable

  def initialize id
    @id = id
  end

  def id
    @id
  end
end

namespace :db do
  desc "Drop and create a random database"
  task :test_seed, :users, :tags, :tag_items do |t, args|
    Dank.redis.flushdb
    users = (args[:users] || 500).to_i
    tags = (args[:tags] || 100).to_i
    tag_items = (args[:tag_items] || 2000).to_i

    tag_items.times do
      u = User.new Random.rand(users)
      u.add_tag "#{Random.rand(tags)}_TAG"
    end
  end

  task :test_reads, :users, :tags, :reads do |t, args|
    users = (args[:users] || 500).to_i
    tags = (args[:tags] || 100).to_i
    reads = (args[:reads] || 2000).to_i

    reads.times do
      a = Dank.redis.multi do
        key = "danktemp:#{Random.rand(500)}"
        Dank.redis.zinterstore key, ["dank:hate:user:#{Random.rand(users)}", "dank:hate:user:#{Random.rand(users)}"]
        Dank.redis.zrange key, 0, -1
        Dank.redis.del key
      end
      #puts a.inspect unless a[0] == 0
    end
  end
end

