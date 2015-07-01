Dependencies
============

Dependency | Version
-----------|---------
tango      | v1.2.1

Migration Instructions
======================

Removed Deprecated Modules
--------------------------
* `ocean.util.container.cache.PriorityCache

  `droppingItem()` method has been replaced with `itemDropped()`. Also the
  notifier is now called after the item has already been removed from the
  cache. The refactored method passes the key as well as a reference to the
  dropped item as parameters. The default implementation of the method is
  to set the item to its init value.

Removed Deprecated Symbols
--------------------------

* `ocean.util.config.ConfigParser`

  `parse` has been taken out of the ConfigParser API. `parse` used to be an
  alias for the `parseFile` method, and has been deprecated since Oct 2014.

Deprecations
============

* `ocean.io.serialize.StructSerializer`

  The binary serialization facilities of this module have been deprecated. Any
  code which is still using this should be adjusted to use the new serializer in
  `ocean.util.serialize`. (The stream and plugin serialization facilities of
  `StructSerializer` remain unchanged.)

New Features
============
