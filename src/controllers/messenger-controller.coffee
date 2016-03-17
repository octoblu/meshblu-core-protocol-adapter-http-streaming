_                 = require 'lodash'
debug             = require('debug')('meshblu-server-http:messenger-controller')
{Readable}        = require 'stream'
MeshbluAuthParser = require '../helpers/meshblu-auth-parser'
MessengerManager  = require 'meshblu-core-manager-messenger'

class MessengerController
  constructor: ({@jobManager, @jobToHttp, @messengerClientFactory, @uuidAliasResolver}) ->
    @authParser = new MeshbluAuthParser

  subscribeSelf: (req, res) =>
    auth = @authParser.parse req
    {types} = _.extend {}, req.query, req.body
    types ?= ['sent', 'received', 'broadcast']
    if _.isString types
      types = [types]
    @_subscribe {req, res, toUuid: auth.uuid, types}

  subscribe: (req, res) =>
    auth = @authParser.parse req
    {types} = _.extend {}, req.query, req.body
    types ?= ['sent', 'received', 'broadcast']
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

    job = @jobToHttp.httpToJob jobType: 'GetAuthorizedSubscriptionTypes', request: req, toUuid: toUuid

    @jobManager.do 'request', 'response', job, (error, jobResponse) =>
      return res.sendError error if error?

      if jobResponse?.metadata?.code != 204
        return @jobToHttp.sendJobResponse {jobResponse, res}

      res.type 'application/json'
      res.set {
        'Connection': 'keep-alive'
      }

      res.set @jobToHttp.metadataToHeaders jobResponse.metadata
      client = @messengerClientFactory.build()
      readStream = new Readable
      readStream._read = _.noop
      readStream.pipe res

      messenger = new MessengerManager {client, @uuidAliasResolver}
      data = JSON.parse jobResponse.rawData
      {types} = data

      _.each types, (type) =>
        messenger.subscribe type, toUuid
        return # subscribe sometimes returns false

      messenger.on 'message', (channel, message) =>
        debug 'on message', JSON.stringify(message)
        readStream.push JSON.stringify(message) + '\n'

      res.on 'close', ->
        messenger.close()

module.exports = MessengerController
