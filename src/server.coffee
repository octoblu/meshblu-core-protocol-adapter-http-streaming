_                       = require 'lodash'
colors                  = require 'colors'
morgan                  = require 'morgan'
express                 = require 'express'
bodyParser              = require 'body-parser'
cors                    = require 'cors'
errorHandler            = require 'errorhandler'
meshbluHealthcheck      = require 'express-meshblu-healthcheck'
SendError               = require 'express-send-error'
Redis                   = require 'ioredis'
RedisNS                 = require '@octoblu/redis-ns'
debug                   = require('debug')('meshblu-server-http:server')
Router                  = require './router'
JobToHttp               = require './helpers/job-to-http'
PackageJSON             = require '../package.json'
MessengerManagerFactory = require 'meshblu-core-manager-messenger/factory'
UuidAliasResolver       = require 'meshblu-uuid-alias-resolver'
compression             = require 'compression'
JobLogger               = require 'job-logger'
{ JobManagerRequester } = require 'meshblu-core-job-manager'

class Server
  constructor: (options)->
    {
      @disableLogging
      @port
      @aliasServerUri
      @redisUri
      @cacheRedisUri
      @firehoseRedisUri
      @namespace
      @jobTimeoutSeconds
      @maxConnections
      @jobLogRedisUri
      @jobLogQueue
      @jobLogSampleRate
      @requestQueueName
      @responseQueueName
    } = options
    @panic 'missing @jobLogQueue', 2 unless @jobLogQueue?
    @panic 'missing @jobLogRedisUri', 2 unless @jobLogRedisUri?
    @panic 'missing @redisUri', 2 unless @redisUri?
    @panic 'missing @cacheRedisUri', 2 unless @cacheRedisUri?
    @panic 'missing @firehoseRedisUri', 2 unless @firehoseRedisUri?
    @panic 'missing @requestQueueName', 2 unless @requestQueueName?
    @panic 'missing @responseQueueName', 2 unless @responseQueueName?

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
    app.use compression()
    app.use morgan 'dev', immediate: false unless @disableLogging
    app.use errorHandler()
    app.use cors()
    app.use bodyParser.urlencoded limit: '50mb', extended : true
    app.use bodyParser.json limit : '50mb'

    client = new RedisNS @namespace, new Redis @redisUri, dropBufferSupport: true
    queueClient = new RedisNS @namespace, new Redis @redisUri, dropBufferSupport: true

    jobLogger = new JobLogger
      client: new Redis @jobLogRedisUri, dropBufferSupport: true
      indexPrefix: 'metric:meshblu-core-protocol-adapter-http-streaming'
      type: 'meshblu-core-protocol-adapter-http-streaming:request'
      jobLogQueue: @jobLogQueue

    @jobManager = new JobManagerRequester {
      client
      queueClient
      @jobTimeoutSeconds
      @jobLogSampleRate
      @requestQueueName
      @responseQueueName
      queueTimeoutSeconds: @jobTimeoutSeconds
    }

    @jobManager._do = @jobManager.do
    @jobManager.do = (request, callback) =>
      @jobManager._do request, (error, response) =>
        jobLogger.log { error, request, response }, (jobLoggerError) =>
          return callback jobLoggerError if jobLoggerError?
          callback error, response

    queueClient.on 'ready', =>
      @jobManager.startProcessing()

    jobToHttp = new JobToHttp

    uuidAliasClient = new RedisNS 'uuid-alias', new Redis @cacheRedisUri, dropBufferSupport: true
    uuidAliasResolver = new UuidAliasResolver
      cache: uuidAliasResolver
      aliasServerUri: @aliasServerUri

    messengerManagerFactory = new MessengerManagerFactory {uuidAliasResolver, @namespace, redisUri: @firehoseRedisUri}

    router = new Router {@jobManager, jobToHttp, messengerManagerFactory}

    router.route app

    @server = app.listen @port, callback

  stop: (callback) =>
    @jobManager?.stopProcessing()
    @server.close callback

module.exports = Server
