Dependencies
============

Dependency | Version
-----------|---------
tango      | v1.3.x

Migration Instructions
======================

`ocean.*`

  All modules have been stripped of any mentions of mutexes and
  `synchronized`. This shouldn't affect any of our projects as those
  are exclusively single-threaded and any synchronization is thus
  wasted time.

Deprecations
============

New Features
============
