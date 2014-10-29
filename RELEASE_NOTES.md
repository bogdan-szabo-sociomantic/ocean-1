Dependencies
============

Dependency | Version
-----------|---------
tango      | v1.0.4
dmd1       | v1.076.s2

Migration Instructions
======================

* `ocean.io.serialize.StructDumper`

  Most struct parameters have been changed to ref to optimize the stack usage.
  This means that lvalues are no longer possible.

* Makd

  Now the `test/` directory is expected to have some particular structure.
  Please refer to the *New Features* section for details on how this new
  expected structure is.

  If you were specifying flags to the unittest program, you need to add a `%`
  to the rule before `unittest`. For example: `$O/%unittest: override LDFLAGS
  += -lm`.

* Command-line config overrides / `ocean.util.app.ext.ConfigExt`

  This is really a user-visible change, not an API change.  The format of how
  configuration overrides can be passed to a program through the command-line
  has changed. The new format is simpler: category.key=value.  The old format is
  still supported, but a warning is printed when the old format is used.

* `ocean.util.config.ConfigParser`

  Now the `[category]` in config files will be trimmed, so `[ category ]` and
  `[category]` will be parsed both as `category`. This is done to match the
  behaviour of keys and values, which are trimmed too. For now a warning is
  printed if the trimming of the string yielded a different result, so updating
  configuration files should be easy, but please **pay attention to these
  warnings!**

  ConfigParser used to earlier expose public functions `resetParser` and
  `parseLine`, both of which have now been made private. Applications using the
  ConfigParser do not need to call these functions.

* `ocean.util.serialize.contiguous.Deserializer.copy`

  `copy` was moved from `Deserializer` module to new `Util` module. Update your
  imports unless you use `package_.d`

* `ocean.core.Exception`

    `enforce` now takes file/line as template arguments instead of runtime ones.
    If your code passes file/line explicitly, switch to `enforceImpl` instead which
    matches old signature.

* `ocean.io.console.AppStatus`

  The method `num_static_lines` earlier returned the 'new' number of static
  lines, but now doesn't return anything. A separate getter method - also called
  `num_static_lines` can be used instead to get the current number of static
  lines.

* `ocean.util.contaner.cache.CachingStructLoader`

  `add_empty_values` field is not used in CachingStructLoader anymore.
  If your child class did set `this.add_empty_values = true`, ensure you call
  callback delegate even when data is empty. If your child class did set
  `this.add_empty_values = false`, ensure you DON'T call delegate when 
  data is empty.

Deprecations
============

* `ocean.util.config.ConfigParser`

  The function `parse` used for parsing config files is now deprecated.
  Applications should henceforth use the `parseFile` function for this. The
  function signature remains unchanged.

New Features
============

* Makd

  Makd learned how to automatically build and run integration tests. If the
  `test/` directory exists, it is expected to be populated by subdirectories,
  each holding individual tests programs that provide a top-level `main.d`
  file, used to compile the test program.

  The *unittest* target was also split to be able to run fast and slow unit
  tests separately. To run just the fast unit tests use the *fastunittest*
  target. The plain *unittest* target is now an alias for the more specific
  *allunittest* target, which run both fast and slow tests. All tests are
  assumed to be fast unless they are separated to another file with the pattern
  `<MODULE>_slowtest.d`. These modules should live in the `src/` directory and
  are not built or run by the *fastunittest* target.

  Also, the shorter *fasttest* target is now provided, which is just an alias
  for *fastunittest*, but can be expanded by adding targets to the special
  `$(fasttest)` variable.

  Please take a look at the [Makd README](https://github.com/sociomantic/ocean/blob/master/script/Makd.README.rst#testing)
  and the [Projects Directory Structure](https://github.com/sociomantic/backend/wiki/Projects-Directory-Structure#test)
  documents for details.

* `ocean.util.config.ConfigParser`

  The ConfigParser is now capable of repeatedly parsing an unchanged
  configuration without any additional memory allocation, and a different
  configuration with only minimal extra allocation as needed. This enhancement
  does not require any changes to applications using the ConfigParser module.

  The ConfigParser has a new method `remove` which can be used to remove
  properties from a parsed configuration.

* `ocean.util.app.ext.ConfigExt`

  Previously, the `override-config` option of the ConfigExt module could be used
  only to change the value of a property or add a new property to a
  configuration. But now, it can also be used to remove properties from a parsed
  configuration. This is achieved by not specifying any 'value' in the parameter
  of the `override-config` option as follows:
      $> ./application --override-config Section.key=
  (when this is done, the value associated with `Section.key` will be removed)

* `ocean.io.device.DirectIO`

  `BufferedDirectReadFile` has a new protected method, `newFile()`, just like
  `BufferedDirectWriteFile`, so subclasses can change what `File` subclass to use.

* `ocean.util.serialize.contiguous.Util`

  New module that contains utilities built on top of (de)serializer. New `copy`
  overload was added here that can copy any "normal" structure `S` to
  `Contiguous!(S)`

* `ocean.io.console.AppStatus`

  Previously, attempting to redirect the output of an application using
  `AppStatus` to a file from the command line (using `>` or `>>`) resulted in
  strange binary characters to be saved in the file. This is no longer the case.
  The output of the application can now be redirected to a file, but only the
  contents of the top streaming portion would be saved to the file, whereas the
  contents of the bottom static portion would simply be ignored.

