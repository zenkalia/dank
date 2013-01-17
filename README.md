# Dank

[![Build Status](https://travis-ci.org/zenkalia/dank.png)](https://travis-ci.org/zenkalia/dank)


A Redis-backed gem for tagging objects, using those tag relations and autocompleting on those tags.  These are kind of two problems, but related enough that I put them in one gem (because with autocomplete you'll have fewer repeated tags with different spellings, for example).

Autocomplete largely coming from this: <http://antirez.com/post/autocomplete-with-redis.html>

## Benchmarking?  Performance?
```
rake db:test_seed[users,tags,data_points]
rake db:test_reads[users,tags,data_points]
```
Previous benchmarks have proven that we should just trust Redis until proven otherwise.  Calculating intersections, although running in constant-ish time and taking linear-ish memory, ended up taking way too much memory to be practical (until proven otherwise! though I have a lot of unimplemented ideas for performance increases).

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

Tags all have internal counters.  Calling `a.add_tag 'sexy'` will either set the counter to 1 or (if it's already set) increase it by 1.

If you want to remove a tag entirely, use `a.remove_tag 'sexy'`, as opposed to `a.decrement_tag 'sexy'` which will decrement it by 1 and remove it entirely if it hits 0.

If you want to get these counters along with your tags, use `a.tags_hash`.  `a.tags` will only give you an array (sorted by the tags, but without the actual values).

`a.shared_tags b` will give you the set of shared tags between taggable a and the taggable b.  Alternately, `a.shared_tags b.id`

If you'd like to compare yourself to someone else by a distance rather than an array, try `a.get_distance b`.  You could also do `a.get_distance b.id` and get the same result.

To get the distance between two tags, try `User.tag_distance 'sexy', 'beast'`.

If you want tag suggestions for a taggable based on what tags is already has, use `a.tag_suggestions` or `a.tag_suggestions_hash`.

## Config!

`Dank.config` takes a hash.  Options currently are:

* `app_name` for namespacing your redis keys, not actually that important (`Dank.app_name { app_name: hater_dater}`)
* `autocomplete` this option is on by default, if turned off Dank will not keep a dictionary of tags / words / whatevers (accessible through `Dank.autocomplete prefix`) (`Dank.config {autocomplete: false}`)

If you want to change your tag name, use the `tag_name` function.

```
class Band
  attr_accessor :id
  include Dank::Taggable
  tag_name :genre
end
```

**In the future, this functionality will allow multiple tag types on one taggable, but that's not the case now.**

## TODO list

* namespace the redis with RACK_ENV
* ~~option for taggable_name (yo dawg i'll put a module in my module that extends my base class when i include my module in my class <http://www.theirishpenguin.com/2010/02/04/a-ruby-module-that-mixes-in-class-methods-static-and-instance-methods/>)~~ Thanks Derek!
* ~~update intersections between sets in more intelligent ways to save processing~~ O(m+n) time based on how many people have that tag and how many tags that person has
* ~~save intersections in unsorted sets to save space/time~~
* ~~calculate neighbors for each tag and taggble (when it's optional, it'll probably be Dank::Basement)~~ (calculated in real time, trusting redis)
* figure out some way to persist these tags in case redis blows up (put everything in postgres at the same time as redis or use Redis.save?)
* add function for set_tags (currently everything kind of hinges on small/iterative/incremental data inserts)