# Dank

A Redis-backed gem for making a tag cloud thingie!

Autocomplete largely coming from this: <http://antirez.com/post/autocomplete-with-redis.html>

## Benchmarking?  Performance?
```
rake db:test_seed[users,tags,data_points]
rake db:test_reads[users,tags,data_points]
```
Previous benchmarks have proven that moving forward we should just trust Redis until proven otherwise.  Calculating intersections, although running in constant-ish time and taking linear-ish memory, ended up taking way too much memory to be practical (again, until proven otherwise).

## Usage!

```
class User
  attr_accessor :id
  include Dank::Taggable
end

1.9.3p194 :016 > a = User.new
 => #<User:0x007fa0930b8250>
1.9.3p194 :017 > a.id = 4
 => 4
1.9.3p194 :018 > a.add_tag 'sexy'
 => [1.0, true]
1.9.3p194 :019 > a.add_tag 'beast'
 => [1.0, true]
1.9.3p194 :020 > b = User.new
 => #<User:0x007fa09306f0f0>
1.9.3p194 :021 > b.id = 5
 => 5
1.9.3p194 :022 > b.add_tag 'sexy'
 => [1.0, true]
1.9.3p194 :023 > b.tags
 => ["sexy"]
1.9.3p194 :024 > a.tags
 => ["beast", "sexy"]
1.9.3p194 :025 > b.neighbors
 => ["4"]
1.9.3p194 :026 > User.tag_neighbors 'sexy'
 => ["beast"]
```

## TODO list

* ~~option for taggable_name (yo dawg i'll put a module in my module that extends my base class when i include my module in my class <http://www.theirishpenguin.com/2010/02/04/a-ruby-module-that-mixes-in-class-methods-static-and-instance-methods/>)~~ Thanks Derek!
* ~~update intersections between sets in more intelligent ways to save processing~~ O(m+n) time based on how many people have that tag and how many tags that person has
* ~~save intersections in unsorted sets to save space/time~~
* ~~calculate neighbors for each tag and taggble (when it's optional, it'll probably be Dank::Basement)~~ (calculated in real time, trusting redis)
* put usability examples in this readme (probably before the tagging meeting next week)
* figure out some way to persist these tags in case redis blows up (put everything in postgres at the same time as redis or use Redis.save?)
* add function for set_tags (currently everything kind of hinges on small/iterative/incremental data inserts)