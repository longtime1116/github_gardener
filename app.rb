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
  @user_name = params[:name]
  garden = Garden.new(@user_name)
  @garden_svg = garden.garden_svg
  @consecutive_days = garden.consecutive_days
  @consecutive_total_contribs = garden.consecutive_total_contribs
  @consecutive_average_contribs = garden.consecutive_average_contribs

  #binding.pry
  erb  :index
end


class Garden
  attr_reader :garden_svg, :consecutive_days, :consecutive_total_contribs, :consecutive_average_contribs

  def initialize(user_name)
    uri = URI.parse("https://github.com/users/#{user_name}/contributions")
    @garden_svg = Net::HTTP.get_response(uri).body
    doc = Nokogiri::HTML.parse(@garden_svg)

    consecutive_days = 0
    consecutive_total_contribs = 0

    rects = doc.css("rect").reverse
    rects[1..-1].each do |rect|
      break if rect.attributes["data-count"].value.to_i == 0
      consecutive_days += 1
      consecutive_total_contribs += rect.attributes["data-count"].value.to_i
    end

    if rects[0].attributes["data-count"].value.to_i != 0
      consecutive_days += 1
      consecutive_total_contribs += rects[0].attributes["data-count"].value.to_i
    end

    @consecutive_days = consecutive_days
    @consecutive_total_contribs = consecutive_total_contribs
    @consecutive_average_contribs = (consecutive_total_contribs.to_f / consecutive_days).round(2)
  end


end
