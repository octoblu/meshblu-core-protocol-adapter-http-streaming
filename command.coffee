_             = require 'lodash'
Server        = require './src/server'

class Command
  constructor: ->
    @serverOptions =
      port:                         process.env.PORT || 80
      aliasServerUri:               process.env.ALIAS_SERVER_URI
      redisUri:                     process.env.REDIS_URI
      namespace:                    process.env.NAMESPACE || 'meshblu'
      jobTimeoutSeconds:            process.env.JOB_TIMEOUT_SECONDS || 30
      connectionPoolMaxConnections: process.env.CONNECTION_POOL_MAX_CONNECTIONS || 100
      disableLogging:               process.env.DISABLE_LOGGING == "true"
      jobLogRedisUri:               process.env.JOB_LOG_REDIS_URI
      jobLogQueue:                  process.env.JOB_LOG_QUEUE
      meshbluHost:                  process.env.MESHBLU_HOST
      meshbluPort:                  process.env.MESHBLU_PORT

  panic: (error) =>
    console.error error.stack
    process.exit 1

  run: =>
    @panic new Error('Missing required environment variable: ALIAS_SERVER_URI') unless @serverOptions.aliasServerUri? # allowed to be empty
    @panic new Error('Missing required environment variable: REDIS_URI') if _.isEmpty @serverOptions.redisUri
    @panic new Error('Missing required environment variable: JOB_LOG_REDIS_URI') if _.isEmpty @serverOptions.jobLogRedisUri
    @panic new Error('Missing required environment variable: JOB_LOG_QUEUE') if _.isEmpty @serverOptions.jobLogQueue
    @panic new Error('Missing required environment variable: MESHBLU_HOST') if _.isEmpty @serverOptions.meshbluHost
    @panic new Error('Missing required environment variable: MESHBLU_PORT') if _.isEmpty @serverOptions.meshbluPort

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
