require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/json'
require 'uri'
require 'net/http'
require 'nokogiri'
require 'chartkick'
#require 'pry'

get '/' do
  erb :index
end

post '/redirect_to_garden' do
  p params
  redirect "/#{params[:user_name]}"
end

get "/:name" do
  @user_name = params[:name]
  garden = Garden.new(@user_name)
  @garden_svg = garden.garden_svg
  redirect "/" if @garden_svg.nil?

  @consecutive_days = garden.consecutive_days
  @consecutive_total_contribs = garden.consecutive_total_contribs
  @consecutive_average_contribs = garden.consecutive_average_contribs
  @contributed_days_last_year = garden.contributed_days_last_year
  @total_contribs_last_year = garden.total_contribs_last_year
  @average_contribs_last_year = garden.average_contribs_last_year

  #binding.pry
  @graph_data = [["A", 1000], ["B", 2000], ["C", 7000]]
  erb  :garden
end


class Garden
  attr_reader :garden_svg,
              :consecutive_days,
              :consecutive_total_contribs,
              :consecutive_average_contribs,
              :contributed_days_last_year,
              :total_contribs_last_year,
              :average_contribs_last_year

  def initialize(user_name)
    uri = URI.parse("https://github.com/users/#{user_name}/contributions")
    @garden_svg = Net::HTTP.get_response(uri).body
    if @garden_svg.to_s == "Not Found"
      @garden_svg = nil
      return
    end

    doc = Nokogiri::HTML.parse(@garden_svg)
    rects = doc.css("rect").reverse

    @consecutive_days, @consecutive_total_contribs, @consecutive_average_contribs = consecutive_stats(rects)
    @contributed_days_last_year, @total_contribs_last_year, @average_contribs_last_year = last_year_stats(rects)
  end

  private

  def consecutive_stats(rects)
    consecutive_days = 0
    consecutive_total_contribs = 0

    rects[1..-1].each do |rect|
      break if rect.attributes["data-count"].value.to_i == 0
      consecutive_days += 1
      consecutive_total_contribs += rect.attributes["data-count"].value.to_i
    end
    if rects[0].attributes["data-count"].value.to_i != 0
      consecutive_days += 1
      consecutive_total_contribs += rects[0].attributes["data-count"].value.to_i
    end
    return [consecutive_days, consecutive_total_contribs, 0.0] if consecutive_days == 0
    [consecutive_days, consecutive_total_contribs, (consecutive_total_contribs.to_f / consecutive_days).round(2)]
  end

  def last_year_stats(rects)
    contributed_days_last_year = 0
    total_contribs_last_year = 0

    rects.each do |rect|
      next if rect.attributes["data-count"].value.to_i == 0
      contributed_days_last_year += 1
      total_contribs_last_year += rect.attributes["data-count"].value.to_i
    end
    return [contributed_days_last_year, total_contribs_last_year, 0.0] if contributed_days_last_year == 0
    [contributed_days_last_year, total_contribs_last_year, (total_contribs_last_year / contributed_days_last_year).round(2)]
  end
end
