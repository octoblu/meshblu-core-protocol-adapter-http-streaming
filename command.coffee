_      = require 'lodash'
Server = require './src/server'
UUID   = require 'uuid'

class Command
  constructor: ->
    @serverOptions =
      port:                         parseInt process.env.PORT || 80
      aliasServerUri:               process.env.ALIAS_SERVER_URI
      redisUri:                     process.env.REDIS_URI
      cacheRedisUri:                process.env.CACHE_REDIS_URI
      firehoseRedisUri:             process.env.FIREHOSE_REDIS_URI
      namespace:                    process.env.NAMESPACE || 'meshblu'
      jobTimeoutSeconds:            parseInt process.env.JOB_TIMEOUT_SECONDS || 30
      maxConnections:               parseInt process.env.CONNECTION_POOL_MAX_CONNECTIONS || 100
      disableLogging:               process.env.DISABLE_LOGGING == "true"
      jobLogRedisUri:               process.env.JOB_LOG_REDIS_URI
      jobLogQueue:                  process.env.JOB_LOG_QUEUE
      jobLogSampleRate:             parseFloat process.env.JOB_LOG_SAMPLE_RATE
      requestQueueName:             process.env.REQUEST_QUEUE_NAME
      responseQueueBaseName:        process.env.RESPONSE_QUEUE_BASE_NAME

  panic: (error) =>
    console.error error.stack
    process.exit 1

  run: =>
    @panic new Error('Missing required environment variable: ALIAS_SERVER_URI') unless @serverOptions.aliasServerUri? # allowed to be empty
    @panic new Error('Missing required environment variable: REDIS_URI') if _.isEmpty @serverOptions.redisUri
    @panic new Error('Missing required environment variable: FIREHOSE_REDIS_URI') if _.isEmpty @serverOptions.firehoseRedisUri
    @panic new Error('Missing required environment variable: JOB_LOG_REDIS_URI') if _.isEmpty @serverOptions.jobLogRedisUri
    @panic new Error('Missing required environment variable: JOB_LOG_SAMPLE_RATE') unless @serverOptions.jobLogSampleRate?
    @panic new Error('Missing required environment variable: JOB_LOG_QUEUE') if _.isEmpty @serverOptions.jobLogQueue
    @panic new Error('Missing environment variable: REQUEST_QUEUE_NAME') if _.isEmpty @serverOptions.requestQueueName
    @panic new Error('Missing environment variable: RESPONSE_QUEUE_BASE_NAME') if _.isEmpty @serverOptions.responseQueueBaseName

    responseQueueId = UUID.v4()
    @serverOptions.responseQueueName = "#{@serverOptions.responseQueueBaseName}:#{responseQueueId}"

    server = new Server @serverOptions
    server.run (error) =>
      return @panic error if error?

      {address,port} = server.address()
      console.log "Server listening on #{address}:#{port}"

    process.on 'SIGTERM', =>
      console.log 'SIGTERM caught, exiting'
      server.stop =>
        process.exit 0

command = new Command()
command.run()
