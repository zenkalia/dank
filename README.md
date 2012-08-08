# Dank

A Redis-backed gem for making a tag cloud thingie!

Autocomplete largely coming from this: <http://antirez.com/post/autocomplete-with-redis.html>


## TODO list

* ~~option for taggable_name (yo dawg i'll put a module in my module that extends my base class when i include my module in my class <http://www.theirishpenguin.com/2010/02/04/a-ruby-module-that-mixes-in-class-methods-static-and-instance-methods/>)~~ Thanks Derek!
* make calculating intersections optional (Dank::Nugs)
* ~~update intersections between sets in more intelligent ways to save processing~~ O(m+n) time based on how many people have that tag and how many tags that person has
* ~~save intersections in unsorted sets to save space/time~~
* calculate neighbors for each tag and taggble (when it's optional, it'll probably be Dank::Basement)
* put usability examples in this readme (probably before the tagging meeting next week)
* figure out some way to persist these tags in case redis blows up (put everything in postgres at the same time as redis?  asynchronously?)
* add function for set_tags (currently everything kind of hinges on small/iterative/incremental data inserts)
* add function for recalculating all reverse tags, intersections, distances and neighbors from tag sets