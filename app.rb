require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/json'
require 'uri'
require 'net/http'
require 'nokogiri'
#require 'pry'

get '/' do
  'hello world'
end

get "/:name" do
  uri = URI.parse("https://github.com/users/#{params[:name]}/contributions")
  # この garden_svg は String なので、こいつを良い感じに parse したい
  garden_svg = Net::HTTP.get_response(uri).body
  doc = Nokogiri::HTML.parse(garden_svg)
  #binding.pry
  # doc.css("rect").each
  # doc.css("rect").first.attributes["data-date"].value
  # doc.css("rect").first.attributes["data-count"].value

  # p garden_svg
  # return garden_svg
  return garden_svg
end
