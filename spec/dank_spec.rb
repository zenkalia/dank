require 'dank'
require 'spec_helper'

describe 'Dank' do
  describe 'module functions'

  describe 'mixin' do
    before do
      class Test
        include Dank::Taggable

        def initialize (id)
          @id = id
        end

        def id
          @id
        end
      end
    end

    describe 'adding tags is cool' do
      let(:id){ 'unique' }
      let(:other_id){ 'also_unique' }
      let(:user){ Test.new id }
      let(:other_user){ Test.new other_id }
      before do
        user.add_tag 'whatever'
        user.add_tag 'cheese'
      end

      subject{user.tags}

      its(:count){should == 2}

      describe 'repeated tags go nowhere' do
        before do
          user.add_tag 'whatever'
        end
        its(:count){should == 2}
      end

      describe 'with multiple users, we can read who shared a tag' do
        before do
          other_user.add_tag 'cheese'
        end
        it { Dank.redis.zrange('hate:tags:cheese', 0, -1).should =~ [id, other_id] }
      end

      describe 'we can remove them too' do
        before do
          user.remove_tag 'cheese'
        end
        its(:count){should == 1}

        describe 'with multiple users, we can read who shared a tag' do
          before do
            other_user.add_tag 'cheese'
          end
          it { Dank.redis.zrange('hate:tags:cheese', 0, -1).should =~ [other_id] }
        end
      end
    end

  end
end

#def distance(my_tags,other_tags)
  #intersection = my_tags & other_tags

  #best_case = [my_tags.count, other_tags.count].min

  #intersection.count.to_f / best_case.count * 100
#end

