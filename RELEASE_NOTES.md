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

* `tango.core.Enforce`
 
  Moved to `ocean.core.Enforce`, old module is deprecated. To quickly adjust
  majority of imports run this shell command:
  `find ./src -type f -name *.d | xargs sed -i 's|/<tango\.core\.Enforce/>|ocean.core.Enforce|g'`

* `ocean.core.Exception`

  Using `ocean.core.Exception` as a way to access symbols from
  `ocean.core.Enforce` is deprecated to avoid cyclic dependencies. Please
  import `ocean.core.Enforce` directly.

New Features
============
