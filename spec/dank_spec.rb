require 'dank'
require 'spec_helper'

describe 'Dank' do
  describe 'module functions' do
    describe 'we can add tags ' do
      before do
        Dank.add 'turtles'
        Dank.add 'ninjas'
        Dank.add 'traps'
      end

      subject{Dank.redis.zrange 'tags', 0, -1}

      it do
        subject.should == ["n", "ni", "nin", "ninj", "ninja", "ninjas", "ninjas+", "t", "tr", "tra", "trap", "traps", "traps+", "tu", "tur", "turt", "turtl", "turtle", "turtles", "turtles+"]
      end

      describe 'we can also suggest based on a prefix' do
        subject{Dank.suggest_tags 't'}

        it do
          subject.should == ['traps', 'turtles']
        end
      end

      describe 'we can remove tags too' do
        before do
          Dank.remove 'traps'
        end

        subject{Dank.redis.zrange 'tags', 0, -1}
        it do
          subject.should == ["n", "ni", "nin", "ninj", "ninja", "ninjas", "ninjas+", "t", "tu", "tur", "turt", "turtl", "turtle", "turtles", "turtles+"]
        end
      end
    end

  end

  describe 'mixin' do
    describe 'does nothing without a .id' do
      before do
        class Test
          include Dank::Taggable
          def id
            nil
          end
        end
      end

      let(:user){ Test.new }

      describe 'adding tags returns false' do
        subject { user.add_tag 'cheese' }
        it { should == false }
        specify { lambda { subject }.should_not change { Dank.redis.zrange 'tags', 0, -1 } }
      end
      describe 'removing tags returns false' do
        subject { user.remove_tag 'cheese' }
        it { should == false }
        specify { lambda { subject }.should_not change { Dank.redis.zrange 'tags', 0, -1 } }
      end
    end
    describe 'does good things with a .id' do
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

      let(:id){ 'unique' }
      let(:other_id){ 'also_unique' }
      let(:user){ Test.new id }
      let(:other_user){ Test.new other_id }

      describe 'adding tags is cool' do
        before do
          user.add_tag 'whatever'
          user.add_tag 'cheese'
          user.add_tag 'dinosaurs'
          user.add_tag 'dinosaur eggs'
          user.add_tag 'abe lincoln'
        end

        subject{user.tags}

        its(:count){should == 5}
        it { Dank.suggest_tags('che').should == ['cheese'] }

        describe 'repeated tags go nowhere' do
          before do
            user.add_tag 'whatever'
          end
          its(:count){should == 5}
        end

        describe 'with multiple users, we can read who shared a tag' do
          before do
            other_user.add_tag 'cheese'
          end
          it { Dank.redis.zrange('hate:tags:cheese', 0, -1).should =~ [id, other_id] }

          describe 'and it stays in the shared tags if only one user has it removed' do
            before do
              other_user.remove_tag 'cheese'
            end
            it { Dank.suggest_tags('che').should == ['cheese'] }
          end
        end

        describe 'we can remove them too' do
          before do
            user.remove_tag 'cheese'
          end
          its(:count){should == 4}

          describe 'and the global tag set gets cleaned up when no one has a tag' do
            it { Dank.suggest_tags('che').should == [] }
          end

          describe 'with multiple users, we can read who shared a tag' do
            before do
              other_user.add_tag 'cheese'
            end
            it { Dank.redis.zrange('hate:tags:cheese', 0, -1).should =~ [other_id] }
          end
        end
        describe 'we know the intersection of the tag sets on two users' do
          before do
            other_user.add_tag 'cheese'
            other_user.add_tag 'jesus'
          end
          subject{user.get_shared(other_id)}
          it {subject.should =~ ['cheese']}

          describe 'it even gets updated on tag removal' do
            before do
              user.add_tag 'derek'
              other_user.add_tag 'derek'
              other_user.remove_tag 'cheese'
            end
            it {subject.should =~ ['derek']}
          end
        end

        describe 'we can reorder tags too' do
          let(:shuffled_tags) do
            ret = user.tags.shuffle
            while ret == user.tags do
              ret = user.tags.shuffle
            end
            ret
          end
          subject do
            user.reorder_tags(shuffled_tags)
          end

          specify { lambda { subject }.should change { user.tags } }
          specify { lambda { subject }.should_not change { user.tags.count } }

          describe 'but we fail if you forget a tag' do
            let(:shuffled_tags){user.tags[1,user.tags.count-1]}
            specify { lambda { subject }.should_not change { user.tags } }
            #specify { lambda { subject }.should_not change { user.tags.count } }
          end
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

