#!/usr/bin/env ruby

require "rubygems"
require "bundler/setup"

require "sinatra/base"

class CodeReviewServer < Sinatra::Base
  # We compile our css using LESS. When in development, only compile it when it has changed.
  $css_cache = {}
  configure :development do
    enable :logging
    set :show_exceptions, false
    set :dump_errors, false

    error do
      # Show a more developer-friendly error page and stack traces.
      content_type "text/plain"
      error = request.env["sinatra.error"]
      message = error.message + "\n" + cleanup_backtrace(error.backtrace).join("\n")
      puts message
      message
    end
  end

  configure :test do
    set :show_exceptions, false
    set :dump_errors, false
  end

  configure :production do
    enable :logging
  end

  get "/" do
    erb :"index.html"
  end

  # Serve CSS written in the "Less" DSL by first compiling it. We cache the output of the compilation and only
  # recompile it the source CSS file has changed.
  get "/css/:filename.css" do
    next if params[:filename].include?(".")
    asset_path = "public/#{params[:filename]}.less"
    # TODO(philc): We should not check the file's md5 more than once when we're running in production mode.
    md5 = Digest::MD5.hexdigest(File.read(asset_path))
    cached_asset = $css_cache[asset_path] ||= {}
    if md5 != cached_asset[:md5]
      cached_asset[:contents] = compile_less_css(asset_path)
      cached_asset[:md5] = md5
    end
    content_type "text/css", :charset => "utf-8"
    last_modified File.mtime(asset_path)
    cached_asset[:contents]
  end

  def compile_less_css(filename) `lessc #{filename}`.chomp end

  def cleanup_backtrace(backtrace_lines)
    # Don't include the portion of the stacktrace which covers the sinatra intenals. Exclude lines like
    # /opt/local/lib/ruby/gems/1.8/gems/sinatra-1.2.0/lib/sinatra/base.rb:1125:in `call'
    stop_at = backtrace_lines.index { |line| line.include?("sinatra") }
    backtrace_lines[0...stop_at]
  end
end
