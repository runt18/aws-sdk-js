AWS = require('../../lib/core')
require('../../lib/query_service')

describe 'AWS.QueryService', ->

  MockQueryService = AWS.util.inherit AWS.QueryService,
    constructor: (config) -> 
      this.serviceName = 'mockservice'
      AWS.QueryService.call(this, config)

  MockQueryService.prototype.api =
    apiVersion: '2012-01-01'
    operations:
      operationName:
        n: 'OperationName'
        i: {Input:{}}
        o: {Data:{t:'o',m:{Name:{t:'s'},Count:{t:'i'}}}}

  AWS.Service.defineMethods(MockQueryService)

  svc = new MockQueryService()

  it 'defines a method for each api operation', ->
    expect(typeof svc.operationName).toEqual('function')

  describe 'buildRequest', ->

    req = svc.buildRequest('operationName', { Input:'foo+bar: yuck/baz=~' })

    it 'should use POST method requests', ->
      expect(req.method).toEqual('POST')

    it 'should perform all operations on root (/)', ->
      expect(req.uri).toEqual('/')

    it 'should set Content-Type header', ->
      expect(req.headers['Content-Type']).
        toEqual('application/x-www-form-urlencoded; charset=utf-8')

    it 'should add the api version param', ->
      expect(req.params.toString()).toMatch(/Version=2012-01-01/)

    it 'should add the operation name as Action', ->
      expect(req.params.toString()).toMatch(/Action=OperationName/)

    it 'should uri encode params properly', ->
      expect(req.params.toString()).toMatch(/foo%2Bbar%3A%20yuck%2Fbaz%3D~/);

  describe 'parseResponse', ->

    parse = (callback) ->
      svc.parseResponse resp, 'operationName', (error,data) ->
        callback.call(this, error, data)

    resp = new AWS.HttpResponse()
    resp.headers = {}


    describe 'with data', ->

      beforeEach ->
        resp.statusCode = 200
        resp.body = """
          <xml>
            <Data>
              <Name>abc</Name>
              <Count>123</Count>
            </Data>
          </xml>
        """

      it 'parses the response using the operation output rules', ->
        parse (error, data) ->
          expect(error).toEqual(null)
          expect(data).toEqual({Data:{Name:'abc',Count:123}})

    describe 'with error', ->

      beforeEach ->
        resp.statusCode = 400
        resp.body = """
        <Response>
          <Errors>
            <Error>
              <Code>InvalidInstanceID.Malformed</Code>
              <Message>Invalid id: "i-12345678"</Message>
            </Error>
          </Errors>
          <RequestID>ab123mno-6432-dceb-asdf-123mno543123</RequestID>
        </Response>
        """

      it 'extracts the error code', ->
        parse (error, data) ->
          expect(error.code).toEqual('InvalidInstanceID.Malformed')
          expect(data).toEqual(null)

      it 'extracts the error message', ->
        parse (error, data) ->
          expect(error.message).toEqual('Invalid id: "i-12345678"')
          expect(data).toEqual(null)

      it 'returns an empty error when the body is blank', ->
        resp.body = ''
        parse (error, data) ->
          expect(error.code).toEqual(400)
          expect(error.message).toEqual(null)
          expect(data).toEqual(null)

