#overload Backbone.sync to handle cross origin requests
#this requires use of the cross origin Rack Middleware

methodMap =
 'create': 'POST'
 'read':   'GET'
 'update': 'PUT'
 'delete': 'DELETE'


#jQuery jsonp fails when making concurrent requests using the same callback name
#this replacement can handle these requests properly
window.JSONP =
  #an object where arrays of registered callbacks are stored
  queue: {}

  #make a jsonp request
  request: (url, method, data, callback, callbackName) ->
    callbackName ||= '_' + Math.floor(Math.random() * 9999999999999999)
    concurrent = window[callbackName]?

    if data?
      data = JSON.stringify data
      data = encodeURIComponent data

    #store passed callback in queue
    JSONP.queue[callbackName] ||= []
    JSONP.queue[callbackName].push callback

    #set a callback middleman function on window
    window[callbackName] ||= (data) ->
      for f,i in JSONP.queue[callbackName]
        f(data)

      #remove the script tag and clean global variables
      document.head.removeChild(script) unless concurrent
      delete JSONP.queue[callbackName]
      delete window[callbackName]

    #create a tag only if there isn't already a request using the same callbackName
    unless concurrent
      script = document.createElement('script')
      document.head.appendChild(script)
      src = "#{url}#{if url.indexOf('?') is -1 then '?' else '&'}jsonp=true&method=#{method}&callback=#{callbackName}"
      src += "&data=#{data}" if data?
      script.src = src


#we use this to fallback to JSONP in ie for improved caching because IE will not support wildcard allowed-origin headers
corsSupported = 'withCredentials' of new XMLHttpRequest()

#store a referance to the original Backbone.sync function
originalSync = Backbone.sync

#overload Backbone.sync to handle cross origin urls
#also allow it accept a url object with keys for each method
Backbone.sync = (method, model, options) ->

  #set url
  if options.url?
    url = options.url
  else
    url = if typeof model.url is 'object' then model.url[method] else model.url
    url = url.call(model) if typeof url is 'function'

  #default to original backbone for non cross origin requests
  if not url.match(/\/\//) or url.match(/\/\/([a-z0-9\.]+)\//)[1] == window.location.host
    originalSync.call this, method, model, _.extend(options, {url})

  #otherwise make a cross origin request using CORS or JSONP
  else
    params =
      url: url

    #set request type
    type = methodMap[method]
    if Backbone.emulateHTTP and (type is 'PUT' or type is 'DELETE')
      params.type = 'POST'
      params.beforeSend = (xhr) ->
        xhr.setRequestHeader('X-HTTP-Method-Override', type);
    else
      params.type = type

    #set request data
    if !options.data and model and (method == 'create' or method == 'update')
      params.contentType = 'application/json'
      params.data = JSON.stringify model.toJSON()

    _.extend params, options

    if corsSupported
      #set json datatype and origin header for cross domain ajax request
      params.dataType = 'json'
      params.xhrFields = withCredentials: false
      params.processData = false

      $.ajax params

    else
      #instead of using jquery, use our hand rolled JSONP object
      JSONP.request params.url, params.type, params.data, params.success, params.jsonpCallback