module Dank
  class Tags
    def initialize(o)
      @objekt = o
      @taggable_name = Dank.sanitize o.class.to_s
    end

    def add(tag)
      return false unless @objekt.id
      tag = Dank.sanitize tag
      Dank.add(tag)
      dank_add @taggable_name, @objekt.id, tag
      dank_add 'tags', tag, @objekt.id
    end

    def remove(tag)
      return false unless @objekt.id
      tag = Dank.sanitize tag
      dank_rem @taggable_name, @objekt.id, tag
      dank_rem 'tags', tag, @objekt.id
      if redis.zrange("dank:#{Dank.app_name}:tags:#{tag}",0,-1).count < 1
        Dank.remove tag
      end
    end

    def get_array
      return [] unless @objekt.id
      redis.zrange("dank:#{Dank.app_name}:#{@taggable_name}:#{@objekt.id}",0,-1)
    end

    def get_hash
      return {} unless @objekt.id
      Hash[redis.zrange("dank:#{Dank.app_name}:#{@taggable_name}:#{@objekt.id}",0,-1,{withscores:true})]
    end

    def reorder(tags)
      return false unless @objekt.id
      return false unless tags.sort == get_array.sort # for making sure that we don't allow a reorder without every tag present
      count = 1
      tags.each do |tag|
        redis.zadd("dank:#{Dank.app_name}:#{@taggable_name}:#{@objekt.id}",count,tag)
        count+=1
      end
    end

    def redis
      @redis ||= Dank.redis
    end

    def get_shared(other_id)
      intersection = redis.multi do
        key = "danktemp:#{Random.rand(500)}"
        redis.zinterstore key, ["dank:#{Dank.app_name}:#{@taggable_name}:#{@objekt.id}",
                                "dank:#{Dank.app_name}:#{@taggable_name}:#{other_id}"]
        redis.zrange key, 0, -1
        redis.del key
      end
      intersection[1] # real value is [count, [items], somethingelse]
    end

    def get_distance(other_id)
      Dank.distance "dank:#{Dank.app_name}:#{@taggable_name}:#{@objekt.id}",
                    "dank:#{Dank.app_name}:#{@taggable_name}:#{other_id}"
    end

    private
    def dank_add(receive_type, receive_id, element)
      key = "dank:#{Dank.app_name}:#{receive_type}:#{receive_id}"
      redis.zincrby(key, 1, element)
    end

    def dank_rem(receive_type, receive_id, element)
      key = "dank:#{Dank.app_name}:#{receive_type}:#{receive_id}"
      redis.zincrby(key, -1, element)
      redis.zremrangebyrank(key, 0, 0)
    end
  end

  module Taggable
    module ClassMethods
      def tag_name(name)
        return if @__tag_name_called
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

        define_method :"#{name}s_hash" do
          tag_lib.get_hash
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

        define_method :get_distance do |other_id|
          tag_lib.get_distance other_id
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
end
