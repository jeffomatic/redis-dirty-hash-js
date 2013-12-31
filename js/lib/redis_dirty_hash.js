// Generated by CoffeeScript 1.6.3
(function() {
  var RedisDirtyHash, isPlainObject,
    __slice = [].slice;

  isPlainObject = function(obj) {
    if ((obj != null ? obj.constructor : void 0) == null) {
      return false;
    }
    return obj.constructor.name === 'Object';
  };

  module.exports = RedisDirtyHash = (function() {
    RedisDirtyHash.defaults = {
      redis: null,
      key: null,
      shouldDeleteOnSave: function(k, v) {
        return typeof v === 'undefined';
      },
      serialize: function(k, v) {
        return JSON.stringify(v);
      },
      deserialize: function(k, v) {
        return JSON.parse(v);
      }
    };

    function RedisDirtyHash(opts) {
      var def, k, _ref;
      this.opts = {};
      _ref = this.constructor.defaults;
      for (k in _ref) {
        def = _ref[k];
        this.opts[k] = opts[k] != null ? opts[k] : def;
      }
      this.properties = {};
      this.dirty = {};
      this.persisted = false;
    }

    RedisDirtyHash.prototype.fetch = function(done) {
      var _this = this;
      return this.opts.redis.hgetall(this.opts.key, function(err, value) {
        var k, v;
        if (err != null) {
          return done(err);
        }
        _this.properties = {};
        _this.dirty = {};
        _this.persisted = true;
        if (isPlainObject(value)) {
          for (k in value) {
            v = value[k];
            try {
              _this.properties[k] = _this.opts.deserialize(k, v);
            } catch (_error) {
              err = new Error("Cannot deserialize value for " + k + ": " + v);
              return done(err);
            }
          }
        }
        return done();
      });
    };

    RedisDirtyHash.prototype.set = function() {
      var args;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      switch (args.length) {
        case 1:
          return this._hashSet.apply(this, args);
        case 2:
          return this._pairSet.apply(this, args);
        default:
          throw new Error("Invalid number of arguments: " + args.length);
      }
    };

    RedisDirtyHash.prototype._pairSet = function(k, v) {
      if (v !== this.properties[k]) {
        this.properties[k] = v;
        this.dirty[k] = true;
      }
      return this;
    };

    RedisDirtyHash.prototype._hashSet = function(attribs) {
      var k, v;
      for (k in attribs) {
        v = attribs[k];
        this._pairSet(k, v);
      }
      return this;
    };

    RedisDirtyHash.prototype.get = function(args) {
      if (args == null) {
        return this._getAll();
      } else if (Object.prototype.toString.call(args) === '[object Array]') {
        return this._arrayGet(args);
      } else {
        return this._keyGet(args);
      }
    };

    RedisDirtyHash.prototype._getAll = function() {
      var k, r, v, _ref;
      r = {};
      _ref = this.properties;
      for (k in _ref) {
        v = _ref[k];
        r[k] = v;
      }
      return r;
    };

    RedisDirtyHash.prototype._arrayGet = function(keys) {
      var k, r, _i, _len;
      r = {};
      for (_i = 0, _len = keys.length; _i < _len; _i++) {
        k = keys[_i];
        r[k] = this.properties[k];
      }
      return r;
    };

    RedisDirtyHash.prototype._keyGet = function(k) {
      return this.properties[k];
    };

    RedisDirtyHash.prototype.destroy = function(done) {
      var _this = this;
      return this.opts.redis.del(this.opts.key, function(err) {
        var k;
        if (err != null) {
          return done(err);
        }
        _this.persisted = false;
        _this.dirty = {};
        for (k in _this.properties) {
          _this.dirty[k] = true;
        }
        return done();
      });
    };

    RedisDirtyHash.prototype.persist = function(done) {
      var finish, hdelArgs, hmsetArgs, k, v, _ref, _ref1, _ref2,
        _this = this;
      hmsetArgs = [this.opts.key];
      hdelArgs = [this.opts.key];
      for (k in this.dirty) {
        v = this.properties[k];
        if (this.opts.shouldDeleteOnSave(k, v)) {
          hdelArgs.push(k);
        } else {
          hmsetArgs.push(k);
          hmsetArgs.push(this.opts.serialize(k, v));
        }
      }
      finish = function(err) {
        if (err != null) {
          return done(err);
        }
        _this.dirty = {};
        _this.persisted = true;
        return done();
      };
      if (hmsetArgs.length > 1 && hdelArgs.length > 1) {
        hmsetArgs.push(function(err) {
          var _ref;
          if (err != null) {
            return done(err);
          }
          hdelArgs.push(finish);
          return (_ref = _this.redis).hdel.apply(_ref, hdelArgs);
        });
        return (_ref = this.opts.redis).hmset.apply(_ref, hmsetArgs);
      } else if (hmsetArgs.length > 1) {
        hmsetArgs.push(finish);
        return (_ref1 = this.opts.redis).hmset.apply(_ref1, hmsetArgs);
      } else if (hdelArgs.length > 1) {
        hdelArgs.push(finish);
        return (_ref2 = this.opts.redis).hdel.apply(_ref2, hdelArgs);
      } else {
        return process.nextTick(finish);
      }
    };

    return RedisDirtyHash;

  })();

}).call(this);
