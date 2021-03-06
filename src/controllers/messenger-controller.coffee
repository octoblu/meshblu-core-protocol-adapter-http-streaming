_                 = require 'lodash'
debug             = require('debug')('meshblu-server-http:messenger-controller')
{Readable}        = require 'stream'
MeshbluAuthParser = require '../helpers/meshblu-auth-parser'

class MessengerController
  constructor: ({@jobManager, @jobToHttp, @messengerManagerFactory}) ->
    @authParser = new MeshbluAuthParser

  subscribeSelf: (req, res) =>
    auth = @authParser.parse req
    {types} = _.extend {}, req.query, req.body
    types ?= ['sent', 'received', 'broadcast']
    types.push 'config'
    types.push 'data'
    if _.isString types
      types = [types]
    @_subscribe {req, res, toUuid: auth.uuid, types}

  subscribe: (req, res) =>
    auth = @authParser.parse req
    {types} = _.extend {}, req.query, req.body
    types ?= ['sent', 'received', 'broadcast']
    types.push 'config'
    types.push 'data'
    if _.isString types
      types = [types]
    @_subscribe {req, res, toUuid: req.params.uuid, types}

  subscribeBroadcast: (req, res) =>
    auth = @authParser.parse req
    @_subscribe {req, res, toUuid: req.params.uuid, types: ['broadcast']}

  subscribeSent: (req, res) =>
    auth = @authParser.parse req
    @_subscribe {req, res, toUuid: req.params.uuid, types: ['sent']}

  subscribeReceived: (req, res) =>
    auth = @authParser.parse req
    @_subscribe {req, res, toUuid: req.params.uuid, types: ['received']}

  _subscribe: ({req, res, toUuid, types}) =>
    req.body ?= {}
    req.body.types = types
    {topics} = _.extend {}, req.query, req.body

    job = @jobToHttp.httpToJob jobType: 'GetAuthorizedSubscriptionTypes', request: req, toUuid: toUuid

    @jobManager.do job, (error, jobResponse) =>
      return res.sendError error if error?

      if jobResponse?.metadata?.code != 204
        return @jobToHttp.sendJobResponse {jobResponse, res}

      res.type 'application/json'
      res.set {
        'Connection': 'keep-alive'
      }

      res.set @jobToHttp.metadataToHeaders jobResponse.metadata
      messenger = @messengerManagerFactory.build()
      readStream = new Readable
      readStream._read = _.noop
      readStream.pipe res

      messenger.connect (error) =>
        return res.sendError error if error?
        data = JSON.parse jobResponse.rawData
        {types} = data

        _.each types, (type) =>
          messenger.subscribe {type, topics, uuid: toUuid}
          return # subscribe sometimes returns false

      messenger.on 'message', (channel, message) =>
        debug 'on message', JSON.stringify(message)
        readStream.push JSON.stringify(message) + '\n'

      messenger.on 'config', (channel, message) =>
        debug 'on config', JSON.stringify(message)
        readStream.push JSON.stringify(message) + '\n'

      messenger.on 'data', (channel, message) =>
        debug 'on data', JSON.stringify(message)
        readStream.push JSON.stringify(message) + '\n'

      messenger.on 'error', (error) =>
        messenger.close()

      res.on 'close', ->
        messenger.close()

module.exports = MessengerController
