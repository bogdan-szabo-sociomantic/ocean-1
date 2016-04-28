Dependencies
============

Dependency | Version
-----------|---------
makd       | v1.3.x
tango      | v1.3.x

Migration Instructions
======================

Deprecations
============

* `ocean.time.Ctime`

  This is a very simple module. The reason for deprecation is it comes from
  Tango but it lacks any copyright / licensing information, so to be safe it
  will be removed in v2.0.0.

  There is no inmediate replacement for it (as it was mostly unused), so you'll
  probably have to implement the functionality yourself (or look for similar
  functionality in other `ocean.time` modules).

* `ocean.util.VariadicArg`

  This module is only used by one team and has been moved to Thrusterproto.


New Features
============
