# frozen_string_literal: true

if Rails.env.development? && ENV['DISABLE_MINI_PROFILER'].blank?
  # rack-mini-profiler expects Rack::File, but Rack 3 exposes Rack::Files.
  Rack::File = Rack::Files if defined?(Rack::Files) && !defined?(Rack::File)

  require 'rack-mini-profiler'

  # initialization is skipped so trigger it
  Rack::MiniProfilerRails.initialize!(Rails.application)
end
