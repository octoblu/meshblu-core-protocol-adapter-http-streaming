_ = require 'lodash'

class MeshbluAuthParser
  parse: (request) =>
    authPair  = @parseAuthorizationHeader request
    authPair ?= @parseMeshbluAuthHeaders request
    authPair ?= @parseSkynetAuthHeaders request
    authPair ?= @parseExtraHeaders request
    authPair ?= {uuid: undefined, token: undefined}
    authPair.as = request.header('x-meshblu-as')
    return authPair

  parseAuthorizationHeader: (request) =>
    return unless request.header 'authorization'
    [scheme,encodedToken] = request.header('authorization').split(' ')
    [uuid,token] = new Buffer(encodedToken, 'base64').toString().split(':')
    return unless uuid? && token?

    return {
      uuid:  _.trim uuid
      token: _.trim token
    }

  parseMeshbluAuthHeaders: (request) =>
    return @parseHeader request, 'meshblu_auth_uuid', 'meshblu_auth_token'

  parseSkynetAuthHeaders: (request) =>
    return @parseHeader request, 'skynet_auth_uuid', 'skynet_auth_token'

  parseExtraHeaders: (request) =>
    return @parseHeader request, 'X-Meshblu-UUID', 'X-Meshblu-Token'

  parseHeader: (request, uuidHeader, tokenHeader) =>
    return unless request.header(uuidHeader) and request.header(tokenHeader)
    uuid  = _.trim request.header(uuidHeader)
    token = _.trim request.header(tokenHeader)
    return unless uuid? && token?
    return {uuid, token}

module.exports = MeshbluAuthParser
