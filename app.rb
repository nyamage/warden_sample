require 'rubygems'
require 'warden'
require 'sinatra'
require 'sinatra/reloader'
require 'cgi'
require_relative 'models/user'

class LoginManager < Sinatra::Base
  Warden::Manager.serialize_into_session{|id| id }
  Warden::Manager.serialize_from_session{|id| User.find_by(:name => id) }
   
  Warden::Strategies.add(:password) do
    def valid?
      puts 'password strategy valid?'
      username = params["username"]
      username and username != ''
    end
   
    def authenticate!
      puts 'password strategy authenticate'
      username = params["username"]
      password = params["password"]
      user = User.find_by(:name => username)     
      if not user.nil? and user.password == password
        success!(username)
      else
        fail!('could not login')
      end
    end
  end

  def login(failure = false)
      @error_style = if failure
                        'style="background: red"'
                    else
                        ''
                    end
      erb :login
  end

  get "/" do
      @login_greeting = if env['warden'].authenticated?
                  "welcome #{env['warden'].user.name}!"
              else
                  "not logged in"
              end
      erb :index
  end
 
  post '/unauthenticated/?' do
    status 401
    login
  end
 
  get '/login/?' do
    login
  end

  get '/protected/?' do
      env['warden'].authenticate!
      user = env['warden'].user
      "this is protected. #{user.name} #{session}"
  end

  get '/signup/?' do
      if env['warden'].authenticated? 
      	redirect '/'
      end
      erb :signup
  end

  post '/signup/?' do
  	User.create(:name => params[:username], :password => params[:password])
   	redirect '/login'
  end
  
  post '/login/?' do
    if env['warden'].authenticate
        redirect "/"
    else
        login(true)
    end
  end
  
  get '/logout/?' do
    env['warden'].logout
    redirect '/'
  end

  get '/error' do
      uri = params['uri']
      %$login error trying to access <a href="#{uri}">#{uri}</a>. Go <a href="/">home</a> instead.$
  end

  #use Rack::Session::Cookie
  use Rack::Session::Redis
  use Warden::Manager do |manager|
    manager.default_strategies :password
    manager.failure_app = FailureApp.new
  end
end

class FailureApp
  def call(env)
      uri = env['REQUEST_URI']
    puts 'failure: ' + env['REQUEST_METHOD'] + ' ' + uri
    [302, {'Location' => '/error?uri=' + CGI::escape(uri)}, '']
  end
end
