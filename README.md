# redis-dirty-hash-js

A wrapper class for Redis hashes that performs dirty tracking. Not quite an ORM, but caches data locally, and only persists new changes.

## Examples

```
RedisDirtyHash = require('redis_dirty_hash');
hash = new RedisDirtyHash({redis: redisClient, key: 'myHash'});

// Javascript POD will be serialized and deserialized using JSON
hash.set({name: 'John', occupation: 'baker', age: 30, hobbies: ['stamps', 'golf']});

hash.save(function(err) {
  hash.set({name: 'John', occupation: 'hatter'});

  // This will only persist the change to the `occupation` property.
  hash.save();
});
```

## API

### constructor(options)

Creates a new `RedisDirtyHash` object. Options include:

- `redis` (**required**)
  A Redis client.
- `key` (**required**)
  The key of the Redis hash.
- `shouldDeleteOnSave(key, value)`
  A callback that determines whether a dirty value should be deleted from the hash via `HDEL`. By default, keys whose values are set to `undefined` will be deleted from Redis.
- `serialize(key, value)`
  A callback that converts values to strings that will be persisted to Redis. By default, values will be JSON-serialized.
- `deserialize(key, value)`
  A callback the converts string values from Redis into JavaScript runtime values. By default, strings will be JSON-parsed.

### `#get(key)`

Retrieve the value of a specific key in the hash.

### `#get([key1, key2, ...])`

Retrieve values for a list of keys in the hash. Returns a JavaScript object that maps the specified keys to their respective values.

### `#set(key, value)`

Sets the value of a specified key. Does not persist to Redis, but marks the key as dirty if the value changed, so it will be persisted the next time `#persist` is called.

If you want to clear a key from Redis, set its value to `undefined`.

### `#set({key1: value1, key2: value2, ...})`

Sets the values of the specified keys. Does not persist to Redis, but marks any changed key as dirty, so it will be persisted the next time `#persist` is called.

If you want to clear a key from Redis, set its value to `undefined`.

### `#persist(callback)`

Writes changes to Redis.

### `#fetch(callback)`

Retrieves all keys from Redis. This will clobber any local changes to the keys.

### `#destroy(callback)`

Destroys the entire hash in Redis. This will not clear internal properties, but it will set them as dirty, so they will be persisted the next time `#persist` is called.