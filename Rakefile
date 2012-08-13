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
end

