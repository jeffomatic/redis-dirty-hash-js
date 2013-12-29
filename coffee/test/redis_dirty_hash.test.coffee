assert = require('assert')

testHelper = require('./test_helper')
RedisDirtyHash = require('../lib/redis_dirty_hash')

redisClient = testHelper.getRedisClient()

describe 'RedisDirtyHash', () ->

  beforeEach (done) ->
    @hash = new RedisDirtyHash
      redis: redisClient
      key: 'test'

    redisClient.flushdb (err, result) =>
      throw err if err?
      done()

  describe '#get', ->

    beforeEach ->
      @hash.set 'foo', 'bar'
      @hash.set 'foobar', 'barfoo'

    describe 'single-key param', ->

      it 'should return values set with #set', ->
        assert.equal @hash.get('foo'), 'bar'
        assert.equal @hash.get('foobar'), 'barfoo'

      it 'should return undefined for values that were not set', ->
        assert !@hash.get('foobarfoo')?

    describe 'array param', ->

      it 'should return values as a hash', ->
        assert.deepEqual @hash.get(['foo']), foo: 'bar'
        assert.deepEqual @hash.get(['foobar', 'foo']), foobar: 'barfoo', foo: 'bar'

      it 'should return undefined for values that were not set', ->
        assert.deepEqual @hash.get(['foobar', 'foobarfoo']), foobar: 'barfoo', foobarfoo: undefined

    describe 'empty param', ->

      it 'should return everything as a hash', ->
        assert.deepEqual @hash.get(), foobar: 'barfoo', foo: 'bar'

  describe '#set', ->

    describe 'key/value pair syntax', ->

      beforeEach ->
        @hash.set 'foo', 'bar'
        @hash.set 'foobar', 'barfoo'

      it 'should set the appropriate internal properties', ->
        assert.equal @hash.get('foo'), 'bar'
        assert.equal @hash.get('foobar'), 'barfoo'

      it 'should set the dirty flags', ->
        assert @hash.dirty.foo
        assert @hash.dirty.foobar

      it 'should not set the dirty flag if the value did not change', (done) ->
        @hash.save (err) =>
          throw err if err?
          assert !@hash.dirty.foo
          @hash.set 'foo', 'bar'
          assert !@hash.dirty.foo
          done()

    describe 'hash syntax', ->
      beforeEach ->
        @hash.set foo: 'bar', foobar: 'barfoo'

      it 'should set the appropriate internal properties', ->
        assert.equal @hash.get('foo'), 'bar'
        assert.equal @hash.get('foobar'), 'barfoo'

      it 'should set the dirty flags', ->
        assert @hash.dirty.foo
        assert @hash.dirty.foobar

      it 'should not set the dirty flag if the value did not change', (done) ->
        @hash.save (err) =>
          throw err if err?
          assert !@hash.dirty.foo
          assert !@hash.dirty.foobar
          @hash.set foo: 'bar', foobar: 'barfoo'
          assert !@hash.dirty.foo
          assert !@hash.dirty.foobar
          done()

  describe '#fetch', ->

    describe 'with no pre-existing data in Redis', =>

      it 'should be okay if the key does not exist in Redis', (done) ->
        @hash.fetch (err) ->
          throw err if err?
          done()

      it 'should have empty properties', (done) ->
        @hash.fetch (err) =>
          throw err if err?
          assert !@hash.get('foo')?
          done()

      describe 'with pre-existing unpersisted data', ->

        it 'should clear unpersisted data', (done) ->
          @hash.set foo: 'bar'
          @hash.fetch (err) =>
            throw err if err?
            assert !@hash.get('foo')?
            done()

    describe 'with pre-existing data in Redis', ->

      beforeEach (done) ->
        @hash.set foo: 'bar', foobar: 'barfoo'
        @hash.save (err) =>
          throw err if err?
          done()

      it 'should retrieve saved data', (done) ->
        @fetchedHash = new RedisDirtyHash
          redis: redisClient
          key: @hash.opts.key

        @fetchedHash.fetch (err) =>
          throw err if err?
          assert.deepEqual @fetchedHash.get(), foo: 'bar', foobar: 'barfoo'
          done()

      describe 'with pre-existing unpersisted data', ->

        beforeEach (done) ->
          @fetchedHash = new RedisDirtyHash
            redis: redisClient
            key: @hash.opts.key

          @fetchedHash.set 'foo', 'changed!'
          @fetchedHash.set 'oof', 'rab'

          @fetchedHash.fetch (err) =>
            throw err if err?
            done()

        it 'should clear the dirty state', ->
          assert.deepEqual @fetchedHash.dirty, {}

        it 'should clear unpersisted data', ->
          assert.equal @fetchedHash.get('foo'), 'bar'
          assert !@fetchedHash.get('oof')?

    describe '#save', ->

      beforeEach (done) ->
        @hash.set foo: 'bar', foobar: 'foobar'
        @hash.save (err) =>
          throw err if err?
          done()

      it 'should persist fetchable changes', (done) ->
        newHash = new RedisDirtyHash
          redis: redisClient
          key: @hash.opts.key

        newHash.fetch (err) =>
          throw err if err?
          assert.deepEqual newHash.get(), foo: 'bar', foobar: 'foobar'
          done()

      it 'should clear the dirty state', ->
        assert.deepEqual @hash.dirty, {}

      it 'should not need Redis if the object is not dirty', (done) ->
        @hash.opts.redis = null
        @hash.save (err) =>
          throw err if err?
          done()

      it 'by default, should delete keys that are undefined', (done) ->
        @hash.set foo: undefined
        @hash.save (err) =>
          throw err if err?
          redisClient.hget @hash.opts.key, 'foo', (err, v) ->
            throw err if err?
            assert !v?
            done()

    describe '#destroy', ->

      it 'should eliminate persisted changes', (done) ->
        @hash.set foo: 'bar', foobar: 'foobar'
        @hash.save (err) =>
          throw err if err?
          @hash.destroy (err) =>
            throw err if err?
            @hash.fetch (err) =>
              throw err if err?
              assert.deepEqual @hash.get(), {}
              done()

    describe 'serialization and deserialization', ->

      it 'by default, should JSON serialize/deserialize all values', (done) ->
        values = foo: 'bar', foobar: [1, 2, 3], barfoo: false, oof: 1, blah: null
        @hash.set values
        @hash.save (err) =>
          throw err if err?
          otherHash = new RedisDirtyHash
            redis: redisClient
            key: @hash.opts.key
          otherHash.fetch (err) =>
            throw err if err?
            assert.deepEqual otherHash.get(), values
            done()