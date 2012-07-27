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
      let(:user){ Test.new 4 }
      let(:other_user){ Test.new 5 }
      before do
        user.add_tag 'whatever'
        user.add_tag 'cheese'
        other_user.add_tag 'cheese'
      end

      subject{user.tags}

      its(:count){should == 2}
      it do
        Dank.redis.zrange('hate:tags:cheese', 0, -1).should =~ ['4', '5']
      end
    end

  end
end
