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
