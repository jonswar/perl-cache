#sharing some old work on Cache::Wrapper

I (Perrin) started a project a few years back to provide a wrapper over the modern cache module, like Cache::Memcached and Cache::FastMmap.  It never got off the ground, but the API that I started might be interesting to share.  Here's the man page.  I have some minimal code too if there's interest, but it's really just at a proof-of-concept stage.

```
NAME
    Cache::Wrapper - A unified API for caching modules

VERSION
    Version 0.1_1

SYNOPSIS
        use Cache::Wrapper;

        my $cache = Cache::Wrapper->new(
            cache_class     => 'Cache::FastMmap',
            namespace       => 'my_namespace',
            default_expires => 60 * 60, # seconds, i.e. 1 hour
        );
        my $value;
        $value = $cache->get('key');
        if (!$value) {
            # no result cached. do slow query to fetch it.
            $value = some_slow_function('key');
            # store it for future use
            $cache->set('key' => $value);
        }

        $cache->clear('key');
        $cache->Clear(); # clear the whole cache

DESCRIPTION
    Cache::Wrapper provides a common API for using various caching modules
    from CPAN. It attempts to provide a baseline set of functionality,
    including:

    hash-like get/set semantics
        The API for fetching and storing is as simple as basic hash access.

    namespaces
        Multiple caches can be declared with separate namespaces.

    per-cache and per-item expiration times
        Time-to-live can be set for individual items or for everything in a
        particular cache.

    storage of scalar or complex values
        Anything that the Storable module can serialize can be stored in the
        cache. Some cache modules are able to optimize storage of simple
        scalars, and this ability will be used when Cache::Wrapper is given
        the appropriate hints about your data.

    safe atomic updates
        Although explicit locking is not currently provided, updates are
        atomic in all cache classes.

    When the underlying cache module does not provide these features as
    built-ins, Cache::Wrapper attempts to compensate. In some cases this
    results in a loss of performance, although that is minimized as much as
    possible. It should be obvious though that the performance of the
    underyling cache modules is at least slightly reduced by being used
    through Cache::Wrapper -- you are trading a little speed for
    flexibility.

METHODS
  "new"
        my $cache = Cache::Wrapper->new(
                                        cache_class    => 'BerkelyDB'
                                        namespace      => 'my_cache',
                                        default_ttl    => 60 * 60, # seconds
                                        [ class-specific options ]
                                       );

    The "new" method instantiates a cache handle. The primary parameter is
    "cache_class", which tells "Cache::Wrapper" which storage module to use.
    The options for this parameter are listed in detail under "CACHE_CLASS
    OPTIONS".

    The "namespace" parameter is a string identifying a namespace that all
    cache entries for this handle will be in. This allows separation of
    multiple caches with different data but conflicting keys. For
    compatibility across cache modules, this string must be valid as a file
    name.

    The "default_ttl" parameter is just what it sounds like -- a default
    time-to-live setting for all items placed in the cache.

  "get"
  "set"
  "clear"
CACHE_CLASS OPTIONS
    These are the bundled options for this version of "Cache::Wrapper". More
    may be provided later, or through separate CPAN downloads. In each case,
    you will need to install the actual cache module yourself -- the code
    bundled here is just the wrapper. See the manual pages for the
    individual wrappers for details on options and requirements.

  Cache::FastMmap
    This module uses mmap and a core written in C to achieve high speeds.
    Local disk only.

  Cache::Memcached
    This is the Perl client for memcached, a cache daemon that can hash
    entries across multiple machines to form one giant in-memory cache. It
    is suitable for clusters of machines.

  BerkeleyDB
    This is an interface to modern versions of Berkeley DB from Sleepycat
    Software. It is far beyond the old DB_File module in performance, using
    a shared memory cache and internal locking to achieve high-speed access.
    Local disk only.

  DBD::SQLite
    This is the self-contained SQL database SQLite. It does not need a
    separate server. Local disk only.

  DBD::MySQL
    This is the client for the MySQL database server. It uses the MyISAM
    table type for storing data. This is suitable for use with a cluster,
    although performance is better when the server is local.

  Cache::FileBackend
    This is the file-based storage from "Cache::FileCache" in the
    "Cache::Cache" distribution. Local disk only.

  Cache::SharedMemoryBackend
    This is the shared memory backend from "Cache::SharedMemoryCache". It
    uses "IPC::ShareLite" for the memory manipulation. Local use only.

USE WITH MOD_PERL AND OTHER PERSISTENT ENVIRONMENTS
    Although creating a new instance

AUTHOR
    Perrin Harkins, "<perrin@elem.com>"
```