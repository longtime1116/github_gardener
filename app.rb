require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/json'
require 'uri'
require 'net/http'

get '/' do
  'hello world'
end

get "/:name" do
  uri = URI.parse("https://github.com/users/#{params[:name]}/contributions")
  # この garden_svg は String なので、こいつを良い感じに parse したい
  garden_svg = Net::HTTP.get_response(uri).body
  return garden_svg
end
