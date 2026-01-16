class BrandingHostMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    Current.branding_host = request.host
    @app.call(env)
  ensure
    Current.branding_host = nil
  end
end
