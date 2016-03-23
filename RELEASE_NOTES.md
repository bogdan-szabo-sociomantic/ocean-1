Dependencies
============

Based on v1.27.1

Dependency | Version
-----------|---------
makd       | v1.3.x
tango      | v1.3.x

Migration Instructions
======================

* `ocean.*`

  All modules have been stripped of any mentions of mutexes and
  `synchronized`. This shouldn't affect any of our projects as those
  are exclusively single-threaded and any synchronization is thus
  wasted time.

* `tango.*`

  Completely removed, use modules from ocean package.

Deprecations
============

New Features
============
