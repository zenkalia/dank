require 'dank'
require 'spec_helper'

describe 'Dank' do
  describe 'module functions'

  describe 'mixin' do
    before :all do
      class FuckerUser
        include Dank::Taggable
        tag_name :tag

        def initialize(id)
          @id = id
        end

        def id
          @id
        end
      end
    end

    let(:klass){ FuckerUser }

    describe 'adding tags is cool' do
      let(:user){ klass.new(4) }
      let(:other_user){ klass.new(5) }
      before do
        user.add_tag 'whatever'
        user.add_tag 'cheese'
        other_user.add_tag 'cheese'
      end

      subject{user.tags}

      its(:count){should == 2}
      it do
        Dank.redis.zrange('dank:hate:tag:cheese', 0, -1).should =~ ['4', '5']
      end
    end

  end
end
