_                      = require 'lodash'
colors                 = require 'colors'
morgan                 = require 'morgan'
express                = require 'express'
bodyParser             = require 'body-parser'
cors                   = require 'cors'
errorHandler           = require 'errorhandler'
meshbluHealthcheck     = require 'express-meshblu-healthcheck'
SendError              = require 'express-send-error'
redis                  = require 'redis'
RedisNS                = require '@octoblu/redis-ns'
debug                  = require('debug')('meshblu-server-http:server')
Router                 = require './router'
{Pool}                 = require 'generic-pool'
PooledJobManager       = require 'meshblu-core-pooled-job-manager'
JobLogger              = require 'job-logger'
JobToHttp              = require './helpers/job-to-http'
PackageJSON            = require '../package.json'
MessengerClientFactory = require './messenger-client-factory'
UuidAliasResolver      = require 'meshblu-uuid-alias-resolver'

class Server
  constructor: (options)->
    {@disableLogging, @port, @aliasServerUri} = options
    {@redisUri, @namespace, @jobTimeoutSeconds, @meshbluPort, @meshbluHost} = options
    {@connectionPoolMaxConnections} = options
    {@jobLogRedisUri, @jobLogQueue} = options
    @panic 'missing @jobLogQueue', 2 unless @jobLogQueue?
    @panic 'missing @jobLogRedisUri', 2 unless @jobLogRedisUri?
    @panic 'missing @meshbluHost', 2 unless @meshbluHost?
    @panic 'missing @meshbluPort', 2 unless @meshbluPort?

  address: =>
    @server.address()

  panic: (message, exitCode, error) =>
    error ?= new Error('generic error')
    console.error colors.red message
    console.error error?.stack
    process.exit exitCode

  run: (callback) =>
    app = express()
    app.use SendError()
    app.use meshbluHealthcheck()
    app.use morgan 'dev', immediate: false unless @disableLogging
    app.use errorHandler()
    app.use cors()
    app.use bodyParser.urlencoded limit: '50mb', extended : true
    app.use bodyParser.json limit : '50mb'

    jobLogger = new JobLogger
      jobLogQueue: @jobLogQueue
      indexPrefix: 'metric:meshblu-server-http'
      type: 'meshblu-server-http:request'
      client: redis.createClient(@jobLogRedisUri)

    jobManagerConnectionPool = @_createConnectionPool(maxConnections: @connectionPoolMaxConnections)

    jobManager = new PooledJobManager
      timeoutSeconds: @jobTimeoutSeconds
      pool: jobManagerConnectionPool
      jobLogger: jobLogger

    messengerClientFactory = new MessengerClientFactory {@namespace, @redisUri}

    jobToHttp = new JobToHttp

    uuidAliasClient = _.bindAll new RedisNS 'uuid-alias', redis.createClient(@redisUri)
    uuidAliasResolver = new UuidAliasResolver
      cache: uuidAliasResolver
      aliasServerUri: @aliasServerUri

    router = new Router {jobManager, jobToHttp, @meshbluHost, @meshbluPort, messengerClientFactory, uuidAliasResolver}

    router.route app

    @server = app.listen @port, callback

  stop: (callback) =>
    @server.close callback

  _createConnectionPool: ({maxConnections}) =>
    connectionPool = new Pool
      max: maxConnections
      min: 0
      returnToHead: true # sets connection pool to stack instead of queue behavior
      create: (callback) =>
        client = _.bindAll new RedisNS @namespace, redis.createClient(@redisUri)

        client.on 'end', ->
          client.hasError = new Error 'ended'

        client.on 'error', (error) ->
          client.hasError = error
          callback error if callback?

        client.once 'ready', ->
          callback null, client
          callback = null

      destroy: (client) => client.end true
      validate: (client) => !client.hasError?

    return connectionPool

module.exports = Server
