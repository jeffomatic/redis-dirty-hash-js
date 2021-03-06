fs = require('fs')
redis = require('redis')

module.exports =
  getRedisClient: () ->
    redisConfigPath = __dirname + "/../../test/redis.json"
    config = {}
    config = JSON.parse(fs.readFileSync(redisConfigPath)) if fs.existsSync(redisConfigPath)
    redis.createClient config.port, config.host, config.options