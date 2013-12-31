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

  describe 'unpersisted hashes', ->

    it 'should not be flagged as persisted', ->
      assert !@hash.isPersisted()

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
        assert @hash.isDirty('foo')
        assert @hash.isDirty('foobar')

      it 'should not set the dirty flag if the value did not change', (done) ->
        @hash.persist (err) =>
          throw err if err?
          assert !@hash.isDirty('foo')
          @hash.set 'foo', 'bar'
          assert !@hash.isDirty('foo')
          done()

    describe 'hash syntax', ->
      beforeEach ->
        @hash.set foo: 'bar', foobar: 'barfoo'

      it 'should set the appropriate internal properties', ->
        assert.equal @hash.get('foo'), 'bar'
        assert.equal @hash.get('foobar'), 'barfoo'

      it 'should set the dirty flags', ->
        assert @hash.isDirty('foo')
        assert @hash.isDirty('foobar')

      it 'should not set the dirty flag if the value did not change', (done) ->
        @hash.persist (err) =>
          throw err if err?
          assert !@hash.isDirty('foo')
          assert !@hash.isDirty('foobar')
          @hash.set foo: 'bar', foobar: 'barfoo'
          assert !@hash.isDirty('foo')
          assert !@hash.isDirty('foobar')
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
        @hash.persist (err) =>
          throw err if err?
          done()

      it 'should retrieve persisted data', (done) ->
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
          assert !@fetchedHash.isDirty('foo')
          assert !@fetchedHash.isDirty('oof')

        it 'should clear unpersisted data', ->
          assert.equal @fetchedHash.get('foo'), 'bar'
          assert !@fetchedHash.get('oof')?

    describe '#persist', ->

      beforeEach (done) ->
        @hash.set foo: 'bar', foobar: 'foobar'
        @hash.persist (err) =>
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
        assert !@hash.isDirty('foo')
        assert !@hash.isDirty('foobar')

      it 'should not need Redis if the object is not dirty', (done) ->
        @hash.opts.redis = null
        @hash.persist (err) =>
          throw err if err?
          done()

      it 'by default, should delete keys that are undefined', (done) ->
        @hash.set foo: undefined
        @hash.persist (err) =>
          throw err if err?
          redisClient.hget @hash.opts.key, 'foo', (err, v) ->
            throw err if err?
            assert !v?
            done()

      it 'should mark the hash as persisted', ->
        assert @hash.isPersisted()

    describe '#destroy', ->

      beforeEach (done) ->
        @hash.set foo: 'bar', foobar: 'foobar'
        @hash.persist (err) =>
          throw err if err?
          @hash.destroy (err) =>
            throw err if err?
            done()

      it 'should eliminate persisted changes', (done) ->
        @hash.fetch (err) =>
          throw err if err?
          assert.deepEqual @hash.get(), {}
          done()

      it 'should mark the hash as unpersisted', ->
        assert !@hash.isPersisted()

      it 'should mark all properties as dirty, so they will be persisted at the next upload', (done) ->
        @hash.persist (err) =>
          throw err if err?

          otherHash = new RedisDirtyHash
            redis: redisClient
            key: @hash.opts.key

          otherHash.fetch (err) =>
            throw err if err?
            assert.deepEqual @hash.get(), foo: 'bar', foobar: 'foobar'
            done()

    describe 'serialization and deserialization', ->

      it 'by default, should JSON serialize/deserialize all values', (done) ->
        values = foo: 'bar', foobar: [1, 2, 3], barfoo: false, oof: 1, blah: null
        @hash.set values
        @hash.persist (err) =>
          throw err if err?
          otherHash = new RedisDirtyHash
            redis: redisClient
            key: @hash.opts.key
          otherHash.fetch (err) =>
            throw err if err?
            assert.deepEqual otherHash.get(), values
            done()