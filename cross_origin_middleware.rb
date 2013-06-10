# This middleware allows cross origin remote API requests, using either JSONP or CORS.
#
# JSONP requests are modified before being passed on to the wrapped application in order
# to allow responses to have a unified format.  JSONP is served when a jsonp=true get
# parameter is included in a http GET request.  The middleware will update the method of
# these requests based on a 'method' parameter before passing them on.  For POST and PUT
# requests, the request content will be updated based on the 'data' get parameter.  For all
# JSONP requests, get parameters used by the middleware will be removed before the request
# is passed on.  The response recieved from the wrapped application will then be wrapped
# in a callback function named with the 'callback' parameter from the original request, and
# with a 'Content-Type: application/javascript' header.
#
# Cors requests are passed through to the wrapped application without modification.  The
# response has 'Content-Type: application/json' and access control headers set. In order
# to handle complex CORS requests, the middleware intercepts preflight OPTIONS requests
# and repies to them with the appropriate access control information.  The wrapped application
# will never see these requests.

class CrossOriginMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    #handle CORS preflight request
    if env['REQUEST_METHOD'] == 'OPTIONS'
      return self.handleCorsPreflightRequest(env)
    end

    #handle CORS request
    if env['HTTP_ORIGIN']
      return self.handleCorsRequest(env)
    end

    #handle JSONP request
    get_params = Rack::Utils.parse_query(env['QUERY_STRING'], '&')
    if env['REQUEST_METHOD'] == 'GET' and get_params['jsonp'] == 'true'
      return self.handleJsonpRequest(env)
    end

    #pass request through
    @app.call(env)
  end

  def handleCorsPreflightRequest(env)
    #use wildcard origin to allow improved caching
    #origin = env['HTTP_ORIGIN']
    origin = '*'

    allow_headers = env['HTTP_ACCESS_CONTROL_REQUEST_HEADERS']
    headers = {
      'Access-Control-Allow-Origin' => origin,
      'Access-Control-Allow-Methods' => 'GET, POST, PUT, DELETE',
      'Access-Control-Allow-Credentials' => 'false',
      'Access-Control-Allow-Headers' => allow_headers,
      'Access-Control-Max-Age' => '60',
      'Content-Type' => 'text/html; charset=utf-8'
    }

    [200, headers, ['']]
  end

  def handleCorsRequest(env)
    #pass requset through to app
    status, headers, response = @app.call(env)

    #set CORS headers

    #use wildcard origin to allow improved caching
    #origin = env['HTTP_ORIGIN']
    origin = '*'

    headers['Content-Type'] = 'application/json'
    headers['Access-Control-Allow-Origin'] = origin
    headers['Access-Control-Allow-Credentials'] = 'false'

    [status, headers, response]
  end

  def handleJsonpRequest(env)
    get_params = Rack::Utils.parse_query(env['QUERY_STRING'], '&')
    callback_name = get_params['callback'] || 'callback'

    #update request method based on 'method' parameter
    env['REQUEST_METHOD'] = get_params['method']
    env['rack.input'] = StringIO.new(get_params['data']) if get_params['data']

    #TODO: NEEDS WORK e.g. nested hashes set data based on 'data' parameter
    # if get_params['data']
    #   #for GET requests add data to the query string
    #   if get_params['method'] == 'GET'
    #     get_params.merge! JSON.parse(URI.decode(get_params['data']))
    #   #for other requests set data as rack.input
    #   else
    #     env['rack.input'] = StringIO.new(URI.decode(get_params['data']))
    #   end
    # end

    #remove jsonp related get parameters from request
    keys = ['jsonp', 'method', 'callback', '_', 'data']
    keys.each {|key| get_params.delete key}
    query_string = get_params.reduce(""){|memo,kv| memo + "#{kv[0]}=#{kv[1]}&"}[0...-1] #rebuild query string from get params hash
    env['QUERY_STRING'] = query_string
    env['REQUEST_URI'] = "http://#{env['HTTP_HOST']}#{env['PATH_INFO']}?#{query_string}"

    #pass request through to app
    status, headers, response = @app.call(env)

    #wrap response in a jsonp callback
    response_text = response.reduce("") {|text, part| text + part}
    response = ["#{callback_name}(#{response_text});"]
    headers['Content-Type'] = 'application/javascript'
    headers['Content-Length'] = response[0].length.to_s

    [status, headers, response]
  end
end