#specs for Backbone cross origin sync

describe 'cross origin sync', ->

  describe 'global JSONP object', ->

    #preserve original document.createElement
    originalAppendChild = document.head.appendChild
    originalRemoveChild = document.head.removeChild

    beforeEach ->
      JSONP.queue = {}
      delete window._callback1 if window._callback1?
      delete window._callback2 if window._callback2?

      #this will prevent script tags from being created (and actual requests from being made)
      spyOn document.head, 'appendChild'
      spyOn document.head, 'removeChild'

    it 'makes a single request for concurrent requests w/ the same callbackName', ->

      #spy on document.createElemenet and make concurrent JSONP requests w/ the same callback name
      JSONP.request '//test.com', 'GET', {}, (->), '_callback1'
      JSONP.request '//test.com', 'GET', {}, (->), '_callback1'
      expect(document.head.appendChild.calls.length).toBe 1

    it 'calls all registered callbacks when a request returns', ->
      JSONP.request '//test.com', 'GET', {}, (->), '_callback1'
      JSONP.request '//test.com', 'GET', {}, (->), '_callback1'
      expect(JSONP.queue._callback1.length).toBe 2

      spyOn JSONP.queue._callback1, 0
      spyOn JSONP.queue._callback1, 1
      spy1 = JSONP.queue._callback1[0]
      spy2 = JSONP.queue._callback1[1]
      window._callback1()

      expect(spy1).toHaveBeenCalled()
      expect(spy2).toHaveBeenCalled()

    it 'cleans up global callbacks and JSONP.queue when a request returns', ->
      JSONP.request '//test.com', 'GET', {}, (->), '_callback1'

      window._callback1()

      expect(window._callback1).toBe undefined
      expect(JSONP.queue._callback1).toBe undefined

      script = document.head.appendChild.calls[0].args[0]
      expect(document.head.removeChild).toHaveBeenCalledWith script

    it 'handles urls already including get params correctly', ->
      JSONP.request 'http://test.com/?param=1', 'GET', null, (->), '_callback1'
      script = document.head.appendChild.calls[0].args[0]
      expect(script.src).toBe 'http://test.com/?param=1&jsonp=true&method=GET&callback=_callback1'

    it 'handles urls including no get params correctly', ->
      JSONP.request 'http://test.com/', 'GET', null, (->), '_callback1'
      script = document.head.appendChild.calls[0].args[0]
      expect(script.src).toBe 'http://test.com/?jsonp=true&method=GET&callback=_callback1'

    it 'passes data to the server as a urlencoded json string', ->
      data = a: 1, b: 2
      encodedData = encodeURIComponent JSON.stringify data
      JSONP.request 'http://test.com/', 'GET', data, (->), '_callback1'
      script = document.head.appendChild.calls[0].args[0]
      expect(script.src).toBe "http://test.com/?jsonp=true&method=GET&callback=_callback1&data=#{encodedData}"


    #restore document.createElement
    document.head.appendChild = originalAppendChild
    document.head.removeChild = originalRemoveChild


  describe 'same origin sync from backbone models', ->

    originalAjax = $.ajax

    it 'uses the defualt $.ajax function', ->
      spyOn $, 'ajax'
      model = new (Backbone.Model.extend(url:'/model.json'))()
      model.fetch()
      expect($.ajax).toHaveBeenCalled()

    $.ajax = originalAjax

  describe 'cross origin sync from backbone models', ->

    originalReqeust = JSONP.request

    it 'uses a custom JSONP.request function on the global JSONP object', ->
      spyOn JSONP, 'request'
      model = new (Backbone.Model.extend(url:'//someotherdomain.com/model.json'))()
      model.fetch()
      expect(JSONP.request).toHaveBeenCalled()



