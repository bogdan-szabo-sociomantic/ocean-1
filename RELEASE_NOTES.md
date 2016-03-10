Dependencies
============

Dependency | Version
-----------|---------
tango      | v1.3.x

Migration Instructions
======================

* `tango.util.log.AppendSyslog`

  **WARNING:** This module is currently used by all applications which write log
  files (including stats logs). It handles the automatic rotation of log files.
  It is, however, buggy and scheduled to be replaced by the system `logrotate`
  facility. Introducing a workable deprecation path has proven troublesome, so
  this module is going to be **completely removed** in the upcoming ocean v2.0.0
  release.

  This appender is used internally in ocean in the `StatsExt` and `LogExt`,
  which will be adapted to no longer perform any log rotation. These extensions
  are used by all applications (as far as is known). This means that, if you do
  nothing before updating to ocean v2.0.0, your log files **will no longer be
  rotated**.

  All applications which rely on the log rotation facility provided by
  `AppendSyslog` should be adapted to rely on the system `logrotate` facility to
  rotate their log files, instead. The most convenient way of doing this is to
  use the facilities present in `DaemonApp`. See the
  [v1.26.0 release notes](https://github.com/sociomantic/ocean/releases/tag/v1.26.0)
  for full instructions on how to use these facilities.

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
