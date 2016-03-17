_       = require 'lodash'
redis   = require 'redis'
RedisNS = require '@octoblu/redis-ns'

class MessengerClientFactory
  constructor: ({@namespace, @redisUri}) ->

  build: =>
    _.bindAll new RedisNS @namespace, redis.createClient(@redisUri)

module.exports = MessengerClientFactory
