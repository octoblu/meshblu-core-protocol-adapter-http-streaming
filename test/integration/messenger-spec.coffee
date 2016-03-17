_ = require 'lodash'
request = require 'request'
Server = require '../../src/server'
async      = require 'async'
moment     = require 'moment'
redis      = require 'redis'
RedisNS    = require '@octoblu/redis-ns'
JobManager = require 'meshblu-core-job-manager'

describe 'GET /subscribe', ->
  beforeEach (done) ->
    @port = 0xd00d
    @sut = new Server
      port: @port
      disableLogging: true
      jobTimeoutSeconds: 1
      namespace: 'meshblu:server:http:test'
      jobLogQueue: 'meshblu:job-log'
      jobLogRedisUri: 'redis://localhost:6379'
      meshbluHost: 'localhost'
      meshbluPort: 3000

    @sut.run done

  afterEach (done) ->
    @sut.stop => done()

  beforeEach ->
    @nonce = Date.now()
    @redis = _.bindAll new RedisNS 'meshblu:server:http:test', redis.createClient()
    @jobManager = new JobManager client: @redis, timeoutSeconds: 1

  beforeEach (done) ->
    @jobLogClient = redis.createClient()
    @jobLogClient.del 'meshblu:job-log', done

  context 'when the request is successful', ->
    beforeEach ->
      async.forever (next) =>
        @jobManager.getRequest ['request'], (error, @jobRequest) =>
          next @jobRequest
          return unless @jobRequest?

          response =
            metadata:
              code: 204
              responseId: @jobRequest.metadata.responseId
            data:
              types: ['received']

          @jobManager.createResponse 'response', response, (error) =>
            throw error if error?
            setTimeout =>
              @redis.publish 'received:irritable-captian', @nonce
            , 1000

    beforeEach (done) ->
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

    it 'should log the message', (done) ->
      @jobLogClient.llen 'meshblu:job-log', (error, count) =>
        return done error if error?
        expect(count).to.equal 1
        done()

    it 'should log the attempt and success of the message', (done) ->
      @jobLogClient.lindex 'meshblu:job-log', 0, (error, jobStr) =>
        return done error if error?
        todaySuffix = moment.utc().format('YYYY-MM-DD')
        index = "metric:meshblu-server-http-#{todaySuffix}"
        expect(JSON.parse jobStr).to.containSubset {
          "index": index
          "type": "meshblu-server-http:request"
          "body": {
            "request": {
              "metadata": {
                "auth": {
                  "uuid": "irritable-captian"
                }
                "fromUuid": "irritable-captian"
                "jobType": "GetAuthorizedSubscriptionTypes"
                "toUuid": "irritable-captian"
              }
            }
            "response": {
              "metadata": {
                "code": 204
                "success": true
              }
            }
          }
        }
        done()
