Release Notes for Ocean v2.2.0
==============================

Note: If you are upgrading from an older version, you have to upgrade
incrementally, following the instructions in the previous versions' release
notes.

These notes are usually structured in 3 sections: **Migration Instructions**,
which are the mandatory steps a user must do to update to the new version,
**Deprecated**, which contains deprecated functions which are not recommended to
be used (and will be removed in the next major release) but will not break any
old code, and **New Features** which are new features available in the new
version that users might find interesting.

Dependencies
============

Dependency                | Version
--------------------------|---------
makd                      | v1.3.x
tango runtime (for D1)    | v1.5.1

Deprecations
============

* `ocean.core.array.Mutation.remove`

  The function `remove()` is now deprecated due to it causes function clashes
  in the module `ocean.core.Array`. The function `moveToEnd()` should be used
  instead.

New Features
============
