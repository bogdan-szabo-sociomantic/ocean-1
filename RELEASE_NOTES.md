Dependencies
============

Dependency | Version
-----------|---------
tango      | v1.2.1
dmd1       | v1.077.s14

Migration Instructions
======================

Removed Deprecated Modules
--------------------------

Deprecations
============

* `ocean.io.serialize.StructSerializer`

  The binary serialization facilities of this module have been deprecated. Any
  code which is still using this should be adjusted to use the new serializer in
  `ocean.util.serialize`. (The stream and plugin serialization facilities of
  `StructSerializer` remain unchanged.)

New Features
============
