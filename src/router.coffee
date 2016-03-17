MessengerController        = require './controllers/messenger-controller'

class Router
  constructor: ({jobManager, jobToHttp, messengerClientFactory, uuidAliasResolver})->
    @messengerController = new MessengerController {jobManager, jobToHttp, messengerClientFactory, uuidAliasResolver}

  route: (app) =>
    app.get '/subscribe', @messengerController.subscribeSelf
    app.get '/subscribe/:uuid', @messengerController.subscribe
    app.get '/subscribe/:uuid/broadcast', @messengerController.subscribeBroadcast
    app.get '/subscribe/:uuid/sent', @messengerController.subscribeSent
    app.get '/subscribe/:uuid/received', @messengerController.subscribeReceived

module.exports = Router
