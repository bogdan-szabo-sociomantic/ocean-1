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
