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

New Features
============

 * `ocean.util.container.queue.LinkedListQueue`

 Added a new optional `gc_tracking_policy` template parameter which allows
 defining the gc scanning policy for the items allocated in the queue.

 * `ocean.util.container.queue.LinkedListQueue`

 Added a new `isRootedValues()` method which returns whether the queue
 allocated items are added to the gc scan range.

 * `ocean.text.xml.c.LibXslt`

 Add low-level functions to set the LibXslt maximum recursion depth.

