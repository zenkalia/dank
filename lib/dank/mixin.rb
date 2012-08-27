module Dank
  class Tags
    def initialize(o)
      @objekt = o
      @taggable_name = Dank.sanitize o.class.to_s
      @tag_name = o.class.__dank_tag_name
    end

    def add(tag)
      return false unless @objekt.id
      tag = Dank.sanitize tag
      Dank.add(tag) if Dank.autocomplete_on
      dank_add @taggable_name, @objekt.id, tag
      dank_add @tag_name, tag, @objekt.id
    end

    def remove(tag)
      return false unless @objekt.id
      tag = Dank.sanitize tag
      dank_rem @taggable_name, @objekt.id, tag
      dank_rem @tag_name, tag, @objekt.id
      if Dank.autocomplete_on and redis.zrange("dank:#{Dank.app_name}:#{@tag_name}:#{tag}",0,-1).count < 1
        Dank.remove tag
      end
    end

    def decrement(tag)
      return false unless @objekt.id
      tag = Dank.sanitize tag
      dank_decrement @taggable_name, @objekt.id, tag
      dank_decrement @tag_name, tag, @objekt.id
      if Dank.autocomplete_on and redis.zrange("dank:#{Dank.app_name}:#{@tag_name}:#{tag}",0,-1).count < 1
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
      redis.sinter ["dank:sets:#{Dank.app_name}:#{@taggable_name}:#{@objekt.id}",
                    "dank:sets:#{Dank.app_name}:#{@taggable_name}:#{other_id}"]
    end

    def get_distance(other_id)
      Dank.distance "dank:sets:#{Dank.app_name}:#{@taggable_name}:#{@objekt.id}",
                    "dank:sets:#{Dank.app_name}:#{@taggable_name}:#{other_id}"
    end

    def self.tag_distance(tag_name, tag1, tag2)
      Dank.distance "dank:sets:#{Dank.app_name}:#{tag_name}:#{tag1}",
                    "dank:sets:#{Dank.app_name}:#{tag_name}:#{tag2}"
    end

    def neighbors
      weights = neighbors_hash
      weights.keys.sort do |a,b|
        self.class.sort_weights weights[a], weights[b]
      end
    end

    def neighbors_hash
      my_tags = get_array.map do |tag|
        "dank:sets:#{Dank.app_name}:#{@tag_name}:#{tag}"
      end
      return {} if my_tags == []
      users = redis.sunion my_tags
      users.delete @objekt.id.to_s
      weights = {}
      users.each do |user|
        weights[user] = get_distance user
      end
      weights
    end

    def self.tag_neighbors taggable_name, tag_name, tag
      weights = self.tag_neighbors_hash taggable_name, tag_name, tag
      weights.keys.sort do |a,b|
        sort_weights weights[a], weights[b]
      end
    end

    def self.tag_neighbors_hash taggable_name, tag_name, tag
      users = Dank.redis.smembers "dank:sets:#{Dank.app_name}:#{tag_name}:#{tag}"
      my_user_keys = users.map do |user|
        "dank:sets:#{Dank.app_name}:#{taggable_name}:#{user}"
      end
      return {} if my_user_keys == []
      tags = Dank.redis.sunion my_user_keys
      tags.delete tag
      weights = {}
      tags.each do |t|
        weights[t] = tag_distance tag_name, tag, t
      end
      weights
    end

    def self.sort_weights(a,b)
      if a < b
        1
      elsif a == b
        0
      else
        -1
      end
    end

    private
    def dank_add(receive_type, receive_id, element)
      key = "dank:#{Dank.app_name}:#{receive_type}:#{receive_id}"
      skey = "dank:sets:#{Dank.app_name}:#{receive_type}:#{receive_id}"

      redis.multi do
        redis.zincrby(key, 1, element)
        redis.sadd(skey, element)
      end
    end

    def dank_decrement(receive_type, receive_id, element)
      key = "dank:#{Dank.app_name}:#{receive_type}:#{receive_id}"
      skey = "dank:sets:#{Dank.app_name}:#{receive_type}:#{receive_id}"
      rank = redis.zscore(key, element).to_i
      redis.multi do
        redis.zincrby(key, -1, element)
        redis.zremrangebyscore(key, 0, 0)
        redis.srem(skey, element) if rank == 1
      end
    end

    def dank_rem(receive_type, receive_id, element)
      key = "dank:#{Dank.app_name}:#{receive_type}:#{receive_id}"
      skey = "dank:sets:#{Dank.app_name}:#{receive_type}:#{receive_id}"
      rank = redis.zscore(key, element).to_i
      redis.multi do
        redis.zrem(key, element)
        redis.srem(skey, element) if rank == 1
      end
    end
  end

  module Taggable
    module ClassMethods
      def tag_name(name)
        return if @__tag_name_called
        @__tag_name_called = true
        @__tag_name = name

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

        define_method :"decrement_#{name}" do |tag|
          tag_lib.decrement tag
        end

        define_method :"reorder_#{name}s" do |tags|
          tag_lib.reorder(tags)
        end

        define_method :"shared_#{name}s" do |other|
          other_id = other.respond_to?(:id) ? other.id : other
          tag_lib.get_shared other_id
        end

        define_method :get_distance do |other|
          other_id = other.respond_to?(:id) ? other.id : other
          tag_lib.get_distance other_id
        end

        define_method :neighbors do
          tag_lib.neighbors
        end

        define_method :neighbors_hash do
          tag_lib.neighbors_hash
        end

        define_singleton_method :"#{name}_neighbors" do |genre|
          Dank::Tags.tag_neighbors Dank.sanitize(self.name), @__tag_name, genre
        end

        define_singleton_method :"#{name}_neighbors_hash" do |genre|
          Dank::Tags.tag_neighbors_hash Dank.sanitize(self.name), @__tag_name, genre
        end

        define_singleton_method :"#{name}_distance" do |tag1, tag2|
          tag_lib.tag_distance tag1, tag2
        end

        define_singleton_method :"__dank_tag_name" do
          @__tag_name
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
