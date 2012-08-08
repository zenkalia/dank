require 'dank/version'
require 'redis'

module Dank
  class Tags
    def initialize(o)
      @objekt = o
      @taggable_name = Dank.sanitize o.class.to_s
      get_array
    end

    def add(tag)
      return false unless @objekt.id
      tag = Dank.sanitize tag
      Dank.add(tag)
      dank_add @taggable_name, @objekt.id, tag
      dank_add 'tags', tag, @objekt.id
      dank_add_intersections @objekt.id, tag
      get_array
    end

    def remove(tag)
      return false unless @objekt.id
      tag = Dank.sanitize tag
      dank_rem @taggable_name, @objekt.id, tag
      dank_rem 'tags', tag, @objekt.id
      if redis.zrange("dank:#{Dank.app_name}:tags:#{tag}",0,-1).count < 1
        Dank.remove tag
      end
      dank_rem_intersections @objekt.id, tag
      get_array
    end

    def get_array
      return [] unless @objekt.id
      redis.zrange("dank:#{Dank.app_name}:#{@taggable_name}:#{@objekt.id}",0,-1)
    end

    def reorder(tags)
      return false unless @objekt.id
      return false unless tags.sort == get_array.sort
      count = 1
      tags.each do |tag|
        redis.zadd("dank:#{Dank.app_name}:#{@taggable_name}:#{@objekt.id}",count,tag)
        count+=1
      end
      get_array
    end

    def redis
      @redis ||= Dank.redis
    end

    def get_shared(other_id)
      both = [@objekt.id.to_s, other_id.to_s].sort
      one = both.first
      two = both.last
      redis.zrange "dank:#{Dank.app_name}:intersection:#{@taggable_name}:#{one}:#{two}", 0, -1
    end

    private
    def dank_add(receive_type, receive_id, element)
      key = "dank:#{Dank.app_name}:#{receive_type}:#{receive_id}"
      redis.zadd(key, redis.zcard(key)+1, element)
    end

    def dank_rem(receive_type, receive_id, element)
      key = "dank:#{Dank.app_name}:#{receive_type}:#{receive_id}"
      redis.zrem(key, element)
    end

    def dank_add_intersections(taggable, tag)
      tags = redis.zrange("dank:#{Dank.app_name}:#{@taggable_name}:#{taggable}",0,-1)
      taggables = redis.zrange("dank:#{Dank.app_name}:tags:#{tag}",0,-1)

      tags.each do |t|
        both = [tag.to_s, t.to_s].sort
        one = both.first
        two = both.last
        redis.zadd("dank:#{Dank.app_name}:intersection:tags:#{one}:#{two}", 0, taggable) unless one == two
      end

      taggables.each do |t|
        both = [taggable.to_s, t.to_s].sort
        one = both.first
        two = both.last
        redis.zadd("dank:#{Dank.app_name}:intersection:#{@taggable_name}:#{one}:#{two}", 0, tag) unless one == two
      end
    end

    def dank_rem_intersections(taggable, tag)
      tags = redis.zrange("dank:#{Dank.app_name}:#{@taggable_name}:#{taggable}",0,-1)
      taggables = redis.zrange("dank:#{Dank.app_name}:tags:#{tag}",0,-1)

      tags.each do |t|
        both = [tag.to_s, t.to_s].sort
        one = both.first
        two = both.last
        redis.zrem("dank:#{Dank.app_name}:intersection:tags:#{one}:#{two}", taggable) unless one == two
      end

      taggables.each do |t|
        both = [taggable.to_s, t.to_s].sort
        one = both.first
        two = both.last
        redis.zrem("dank:#{Dank.app_name}:intersection:#{@taggable_name}:#{one}:#{two}", tag) unless one == two
      end
    end
  end

  module Taggable
    module ClassMethods
      def tag_name(name)
        @__tag_name_called = true
        # #{name}s
        # add_#{name}
        # remove_#{name}
        # reorder_#{name}s
        # shared_#{name}s
        # suggest_#{name}s
        define_method :"#{name}s" do
          tag_lib.get_array
        end

        define_method :"add_#{name}" do |tag|
          tag_lib.add tag
        end

        define_method :"remove_#{name}" do |tag|
          tag_lib.remove tag
        end

        define_method :"reorder_#{name}s" do |tags|
          tag_lib.reorder(tags)
        end

        define_method :"shared_#{name}s" do |other_id|
          tag_lib.get_shared other_id
        end

        define_singleton_method :"suggest_#{name}s" do |prefix|
          Dank.suggest_tags prefix
          # this is going to change to be specific to the taggable that you're calling this on
        end
      end

    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    def method_missing(meth, *args, &block)
      super if @__tag_name_called
      self.class.tag_name :tag
      if self.respond_to? meth
        self.send meth, *args, &block
      else
        super
      end
    end
    private
    def tag_lib
      @tag_lib ||= Dank::Tags.new(self)
    end
  end

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
end
