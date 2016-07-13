_ = require 'lodash'
MeshbluAuthParser = require '../helpers/meshblu-auth-parser'

class JobToHttp
  constructor: () ->
    @authParser = new MeshbluAuthParser

  httpToJob: ({jobType, request, toUuid, data}) ->
    data ?= request.body
    userMetadata = @getMetadataFromHeaders request.headers
    auth = @authParser.parse request
    systemMetadata =
      auth: auth
      fromUuid: request.get('x-meshblu-as') ? auth.uuid
      toUuid: toUuid
      jobType: jobType

    job =
      metadata: _.extend userMetadata, systemMetadata
      data: data

    job

  getMetadataFromHeaders: (headers) =>
    _.transform headers, (newMetadata, value, header) =>
      header = header.toLowerCase()
      return unless _.startsWith header, 'x-meshblu-'
      key = _.camelCase( _.replace(header, "x-meshblu-", '' ))
      newMetadata[key] = value

  metadataToHeaders: (metadata) =>
    headers = {}
    _.each metadata, (value, key) =>
      header = "x-meshblu-#{_.kebabCase(key)}"
      return _.set headers, header, value if _.isString value
      return _.set headers, header, JSON.stringify value
    headers

  sendJobResponse: ({jobResponse, res}) ->
    return res.sendStatus 500  unless jobResponse?

    res.set 'Content-Type', 'application/json'
    res.set @metadataToHeaders jobResponse.metadata
    res.status jobResponse.metadata.code
    res.send jobResponse.rawData

  module.exports = JobToHttp
