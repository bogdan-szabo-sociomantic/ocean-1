Dependencies
============

Dependency | Version
-----------|---------
tango      | v1.1
dmd1       | v1.076.s2

Migration Instructions
======================

* `ocean.util.config.ConfigParser`

  The return value of the `getList` method has been fixed. It used to
  incorrectly return true/false, but now returns a dynamic array.


Deprecations
============


New Features
============
