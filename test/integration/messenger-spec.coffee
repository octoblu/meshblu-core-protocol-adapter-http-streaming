_       = require 'lodash'
request = require 'request'
Server  = require '../../src/server'
async   = require 'async'
moment  = require 'moment'
Redis   = require 'ioredis'
RedisNS = require '@octoblu/redis-ns'
UUID    = require 'uuid'
{ JobManagerResponder } = require 'meshblu-core-job-manager'

describe 'GET /subscribe', ->
  beforeEach (done) ->
    @nonce = Date.now()
    @port = 0xd00d
    @namespace = 'meshblu:server:http-streaming:test'
    queueId = UUID.v4()
    @requestQueueName = "test:request:queue:#{queueId}"
    @responseQueueName = "test:response:queue:#{queueId}"
    @sut = new Server {
      port: @port
      disableLogging: true
      jobTimeoutSeconds: 10
      queueTimeoutSeconds: 10
      jobLogSampleRate: 0
      redisUri: 'redis://localhost'
      cacheRedisUri: 'redis://localhost'
      firehoseRedisUri: 'redis://localhost'
      jobLogQueue: 'meshblu:job-log'
      jobLogRedisUri: 'redis://localhost:6379'
      @namespace
      @requestQueueName
      @responseQueueName
    }

    @sut.run done

  afterEach (done) ->
    @sut.stop => done()

  beforeEach (done) ->
    client = new RedisNS @namespace, new Redis 'localhost', dropBufferSupport: true
    client.on 'ready', =>
      queueClient = new RedisNS @namespace, new Redis 'localhost', dropBufferSupport: true
      queueClient.on 'ready', =>
        @jobManager = new JobManagerResponder {
          client
          queueClient
          jobTimeoutSeconds: 10
          queueTimeoutSeconds: 10
          jobLogSampleRate: 0
          @requestQueueName
          @responseQueueName
        }
        done()

  beforeEach (done) ->
    @jobLogClient = new Redis 'localhost', dropBufferSupport: true
    @jobLogClient.del 'meshblu:job-log', done
    return # avoid returning redis

  context 'when the request is successful', ->
    beforeEach (done) ->
      @jobManager.do (@jobRequest, callback) =>
        response =
          metadata:
            code: 204
            responseId: @jobRequest.metadata.responseId
          data:
            types: ['received']

        callback null, response
        setTimeout =>
          client = new RedisNS 'meshblu:server:http-streaming:test', new Redis 'localhost', dropBufferSupport: true
          client.on 'ready', =>
            client.publish 'received:irritable-captian', @nonce
        , 1000

      options =
        auth:
          username: 'irritable-captian'
          password: 'poop-deck'
        json:
          types: ['received']

      response = request.get("http://localhost:#{@port}/subscribe", options)

      response.on 'data', (@message) =>
        response.abort()
        done()

      response.on 'response', (@response) =>

      response.on 'error', (error) =>
        done error

    it 'should get a 200', ->
      expect(@response.statusCode).to.equal 200

    it 'should submit the correct job type', ->
      expect(@jobRequest.metadata.jobType).to.equal 'GetAuthorizedSubscriptionTypes'

    it 'should set the correct auth data', ->
      expect(@jobRequest.metadata.auth).to.deep.equal uuid: 'irritable-captian', token: 'poop-deck'

    it 'should receive a message', ->
      expect(@message.toString().trim()).to.deep.equal String(@nonce)
