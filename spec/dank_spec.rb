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

      subject{Dank.redis.zrange 'dank:tags', 0, -1}

      it do
        subject.should == ["n", "ni", "nin", "ninj", "ninja", "ninjas", "ninjas+", "t", "tr", "tra", "trap", "traps", "traps+", "tu", "tur", "turt", "turtl", "turtle", "turtles", "turtles+"]
      end

      describe 'we can also suggest based on a prefix' do
        subject{Dank.autocomplete 't'}

        it do
          subject.should == ['traps', 'turtles']
        end
      end

      describe 'we can remove tags too' do
        before do
          Dank.remove 'traps'
        end

        subject{Dank.redis.zrange 'dank:tags', 0, -1}
        it do
          subject.should == ["n", "ni", "nin", "ninj", "ninja", "ninjas", "ninjas+", "t", "tu", "tur", "turt", "turtl", "turtle", "turtles", "turtles+"]
        end
      end
    end

  end

  describe 'mixin' do
    describe 'config' do
      before :all do
        class ConfigUser
          include Dank::Taggable

          def initialize (id)
            @id = id
          end

          def id
            @id
          end
        end
      end
      before do
        Dank.config autocomplete: false
        a = ConfigUser.new 8
        a.add_tag 'boners'
      end
      subject{ Dank.autocomplete 'b' }
      its(:count){should == 0}
      after do
        Dank.config autocomplete: true
      end
    end
    describe 'tag_name' do
      before :all do
        class Band
          include Dank::Taggable
          tag_name :genre

          def initialize (id)
            @id = id
          end

          def id
            @id
          end
        end
      end
      let(:klass){ Band }

      describe 'method names' do
        let(:user) { klass.new 1 }
        let(:other_user) { klass.new 2 }
        let(:third_user) { klass.new 3 }
        it "works properly" do
          user.add_genre 'pop'
          user.add_genre 'rock'
          user.genres.should =~ ['pop', 'rock']
          user.remove_genre 'pop'
          user.genres.should =~ ['rock']
          user.add_genre 'rap'
          user.add_genre 'rnb'
          user.add_genre 'country'
          Dank.autocomplete('r').should =~ ['rock','rap','rnb']

          other_user = klass.new 2
          other_user.add_genre 'rap'
          user.shared_genres(other_user.id).should =~ ['rap']
          new_order = user.genres.shuffle
          user.reorder_genres(new_order).should == new_order
          lambda { user.add_tag 'sexy' }.should raise_error
          lambda { user.add_leg 'long' }.should raise_error
          Dank.redis.zrange('dank:hate:genre:rnb', 0, -1).should =~ ['1']
          third_user.add_genre 'rap'
          third_user.add_genre 'rnb'
          third_user.add_genre 'country'
          user.neighbors.should == [third_user.id.to_s, other_user.id.to_s]
          user.neighbors_hash.keys.should =~ [other_user.id.to_s, third_user.id.to_s] # i should be sorting this and comparing it...  nope
          klass.genre_neighbors('rap').should == ['country', 'rnb', 'rock']
          klass.genre_neighbors_hash('rap').keys.should =~ ['country', 'rnb', 'rock']
          other_user.add_genre 'pop'
          other_user.remove_genre 'rap'
          klass.genre_neighbors('pop').should == []
          user.remove_genre 'rap'
          user.genre_suggestions.should == ['rap']
          user.remove_genre 'country'
          user.genre_suggestions.should =~ ['rap', 'country']
          user.set_genres(['rock', 'rap', 'instrumental_metal', 'screamo'])
          user.genres.should == ['rock', 'rap', 'instrumental_metal', 'screamo']
        end
      end
    end
    describe 'does nothing without a .id' do
      before :all do
        class User
          include Dank::Taggable
          def id
            nil
          end
        end
      end
      let(:klass){ User }

      let(:user){ klass.new }

      describe 'adding tags returns false' do
        subject { user.add_tag 'cheese' }
        it { should == false }
        specify { lambda { subject }.should_not change { Dank.redis.zrange 'dank:tags', 0, -1 } }
      end
      describe 'removing tags returns false' do
        subject { user.remove_tag 'cheese' }
        it { should == false }
        specify { lambda { subject }.should_not change { Dank.redis.zrange 'dank:tags', 0, -1 } }
      end
    end
    describe 'does good things with a .id' do
      before :all do
        class User
          include Dank::Taggable

          def initialize (id)
            @id = id
          end

          def id
            @id
          end
        end
      end
      let(:klass){ User }

      let(:id){ 'unique' }
      let(:other_id){ 'also_unique' }
      let(:user){ klass.new id }
      let(:other_user){ klass.new other_id }

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
        it { Dank.autocomplete('che').should == ['cheese'] }

        describe 'repeated tags go nowhere' do
          before do
            user.add_tag 'whatever'
          end
          its(:count){should == 5}

          describe 'but they do get reflected by score' do
            subject{user.tags_hash}
            its(['whatever']){should == 2}

            describe 'and you can decrement the tag without it disappearing' do
              before do
                user.add_tag 'whatever'
                user.decrement_tag 'whatever'
              end
              its(['whatever']){should == 2}
              describe 'decrement it again and it will disappear' do
                before do
                  user.decrement_tag 'whatever'
                  user.decrement_tag 'whatever'
                end
                its(['whatever']){should be_nil}
              end
            end
          end
        end

        describe 'with multiple users, we can read who shared a tag' do
          before do
            other_user.add_tag 'cheese'
          end
          it { Dank.redis.zrange('dank:hate:tag:cheese', 0, -1).should =~ [id, other_id] }

          describe 'and it stays in the shared tags if only one user has it removed' do
            before do
              other_user.remove_tag 'cheese'
            end
            it { Dank.autocomplete('che').should == ['cheese'] }
          end
        end

        describe 'we can remove them too' do
          before do
            user.remove_tag 'cheese'
          end
          its(:count){should == 4}

          describe 'and the global tag set gets cleaned up when no one has a tag' do
            it { Dank.autocomplete('che').should == [] }
          end

          describe 'with multiple users, we can read who shared a tag' do
            before do
              other_user.add_tag 'cheese'
            end
            it { Dank.redis.zrange('dank:hate:tag:cheese', 0, -1).should =~ [other_id] }
          end
        end
        describe 'we know the intersection of the tag sets on two users' do
          before do
            other_user.add_tag 'cheese'
            other_user.add_tag 'jesus'
          end
          subject{user.shared_tags(other_id)}
          it do
            subject.should =~ ['cheese']
            subject.should == user.shared_tags(other_user)
          end

          describe 'it even gets updated on tag removal' do
            before do
              user.add_tag 'derek'
              other_user.add_tag 'derek'
              other_user.remove_tag 'cheese'
            end
            it {subject.should =~ ['derek']}

            describe 'and the intersection does not freak out with an empty set' do
              before do
                other_user.remove_tag 'derek'
              end
              subject{user.get_distance(other_id)}
              it do
                subject.should == 0
                subject.should == user.get_distance(other_user)
              end
            end
          end

          describe 'and we can calculate a distance based between users' do
            subject{user.get_distance(other_id)}
            it do
              subject.should > 0.284
              subject.should < 0.286
            end
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
          it do
            subject
            user.tags.should == shuffled_tags
          end

          describe 'but we fail if you forget a tag' do
            let(:lose_a_tag){shuffled_tags[1,shuffled_tags.count-1]}

            subject do
              user.reorder_tags(lose_a_tag)
            end

            specify { lambda { subject }.should_not change { user.tags } }
            specify { lambda { subject }.should_not change { user.tags.count } }
            it do
              subject
              user.tags.should_not == lose_a_tag
            end
          end
        end
      end
    end
    describe 'has cool class methods' do
      before :all do
        class ClassUser
          include Dank::Taggable

          def initialize (id)
            @id = id
          end

          def id
            @id
          end
        end
      end
      let(:klass){ ClassUser }

      let(:user){ klass.new('4') }
      let(:other_user){ klass.new('5') }

      describe 'find_by_tag_name' do
        before do
          user.add_tag 'life'
          other_user.add_tag 'death'
        end
        subject { ClassUser.find_by_tag_name 'life' }
        it do
          subject.should == [user.id]
        end
      end

    end
  end
end

