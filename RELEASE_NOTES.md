Dependencies
============

Dependency | Version
-----------|---------
tango      | v1.3.x

Migration Instructions
======================

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

* `ocean.text.util.StringReplace`

  This unmaintained and untested module was only used by nautica. It can
  be replaced by functionality from other array/text util modules which
  are more up to date.

* `ocean.io.select.client.IntervalClock`

  This module was created long time ago under a false assumption it is
  more efficient than plain `time()` calls and results in less amount of
  syscalls. Eventually it was proven to be wrong and recommended action
  is to get rid of all mentions of `IntervalClock` in favor of plain `time()`.

* `ocean.text.utf.UtfConvert`

  Completely unused and unmaintained module.

New Features
============
