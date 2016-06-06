MessengerController        = require './controllers/messenger-controller'

class Router
  constructor: ({jobManager, jobToHttp, messengerManagerFactory})->
    @messengerController = new MessengerController {jobManager, jobToHttp, messengerManagerFactory}

  route: (app) =>
    app.get '/subscribe', @messengerController.subscribeSelf
    app.get '/subscribe/:uuid', @messengerController.subscribe
    app.get '/subscribe/:uuid/broadcast', @messengerController.subscribeBroadcast
    app.get '/subscribe/:uuid/sent', @messengerController.subscribeSent
    app.get '/subscribe/:uuid/received', @messengerController.subscribeReceived

module.exports = Router
