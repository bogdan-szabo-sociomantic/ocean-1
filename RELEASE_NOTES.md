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

* `tango.*`

  All tango modules are now marked deprecated. Their ocean replacements have
  been introduced in ocean release v1.28, check its migration notes for details
  on how to update code.

* `ocean.util.log.Stats : StatsLog`

  The `StatsLog` constructors which do not require a `Config` instance have been
  deprecated. Usage can trivially be replaced by constructing a `Config`
  instance, as follows:

  ```D
    new StatsLog(file_count, max_file_size, file_name, name);
    // -->
    new StatsLog(new StatsLog.Config(file_name, max_file_size, file_count), name);

    new StatsLog(file_name, name);
    // -->
    new StatsLog(new StatsLog.Config(file_name), name);
  ```

* `ocean.util.log.Stats : IStatsLog`

  This class has been deprecated. All usage should be replaced by directly using
  `Statslog` instead.

* `ocean.io.selector`

  This whole package has been deprecated. It is unused.

New Features
============

* `ocean.util.container.cache.PriorityCache`

  Added `getHighestPriorityItem()` and `getLowestPriorityItem()` to retrieve
  the items with the highest and the lowest priorities.

* `ocean.util.container.cache.PriorityCache`

  Added a an opApplyReverse() method.

* `ocean.sys.Process`

  D2 only. Now can use pre-existing `istring[] arguments` array directly without
  having developer to re-create it as `cstring[] arguments` array manually. 

* `ocean.util.container.queue.LinkedListQueue`

  Added a new optional `gc_tracking_policy` template parameter which allows
  defining the gc scanning policy for the items allocated in the queue.

* `ocean.util.container.queue.LinkedListQueue`

  Added a new `isRootedValues()` method which returns whether the queue
  allocated items are added to the gc scan range.

* `ocean.text.xml.c.LibXslt`

  Add low-level functions to set the LibXslt maximum recursion depth.

* `ocean.util.app.ext.StatsExt`

  A new method, `newStatsLog()` has been added. This method allows the user to
  create `StatsLog` instances in addition to the one which is created
  automatically by the `StatsExt` and stored in its `stats_log` member. The new
  stats logger is configured according to the default settings and will be
  registered with the application's `ReopenableFilesExt`, if present, for log
  rotation. (The ability to create multiple stats loggers is desired by some
  applications, so this method has been added to enable them to easily create
  properly configured instances.)

* `ocean.net.http.HttpException`

  Custom enforce method for using multiple strings combined with a status code.
