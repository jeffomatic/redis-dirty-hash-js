# Returns true for object literals and objects created with `new Object`.
# WARNING: no support for quasi-object browser constructs like window, etc.
isPlainObject = (obj) ->
  return false unless obj?.constructor?
  obj.constructor.name == 'Object'

module.exports = class RedisDirtyHash

  @defaults =
    redis: null
    key: null
    shouldDeleteOnSave: (k, v) -> typeof v == 'undefined'
    serialize: (k, v) -> JSON.stringify(v)
    deserialize: (k, v) -> JSON.parse(v)

  # opts:
  # - redis
  # - key
  # - shouldDeleteOnSave
  # - serialize
  # - deserialize
  constructor: (opts) ->
    @opts = {}
    for k, def of @constructor.defaults
      @opts[k] = if opts[k]? then opts[k] else def

    @properties = {}
    @dirty = {}

  fetch: (done) ->
    @opts.redis.hgetall @opts.key, (err, value) =>
      return done(err) if err?

      if isPlainObject(value)
        @properties = {}
        @dirty = {}
        for k, v of value
          try
            @properties[k] = @opts.deserialize(k, v)
          catch
            err = new Error("Cannot deserialize value for #{k}: #{v}")
            return done(err)
      else
        @properties = {}
        @dirty = {}

      done()

  set: (args...) ->
    switch args.length
      when 1 then @_hashSet(args...)
      when 2 then @_pairSet(args...)
      else throw new Error("Invalid number of arguments: #{args.length}")
    @ # return self for chainability

  _pairSet: (k, v) ->
    if v != @properties[k]
      @properties[k] = v
      @dirty[k] = true

  _hashSet: (attribs) ->
    @_pairSet(k, v) for k, v of attribs

  get: (args) ->
    if !args?
      @_getAll()
    else if Object.prototype.toString.call(args) == '[object Array]'
      @_arrayGet args
    else
      @_keyGet args

  _getAll: ->
    r = {}
    r[k] = v for k, v of @properties
    r

  _arrayGet: (keys) ->
    r = {}
    r[k] = @properties[k] for k in keys
    r

  _keyGet: (k) ->
    @properties[k]

  destroy: (done) ->
    @opts.redis.del @opts.key, done

  # Writes new changes to Redis
  save: (done) ->
    # Build list of arguments to HMSET and HDEL
    hmsetArgs = [ @opts.key ]
    hdelArgs = [ @opts.key ]

    # Add keys and values in series
    for k of @dirty
      v = @properties[k]

      # In some cases, such as undefined or null values, we may just want to
      # delete the key within the hash for that value.
      if @opts.shouldDeleteOnSave(k, v)
        hdelArgs.push k
      else
        hmsetArgs.push k
        hmsetArgs.push @opts.serialize(k, v)

    # Prepare a common callback that clears the dirty flags on success.
    finish = (err) =>
      return done(err) if err?
      @dirty = {}
      done()

    if hmsetArgs.length > 1 && hdelArgs.length > 1
      # Run HMSET, then HDEL
      hmsetArgs.push (err) =>
        return done(err) if err?
        hdelArgs.push finish
        @redis.hdel hdelArgs...

      @opts.redis.hmset hmsetArgs...
    else if hmsetArgs.length > 1
      hmsetArgs.push finish
      @opts.redis.hmset hmsetArgs...
    else if hdelArgs.length > 1
      hdelArgs.push finish
      @opts.redis.hdel hdelArgs...
    else
      process.nextTick finish