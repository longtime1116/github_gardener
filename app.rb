require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/json'
require 'uri'
require 'net/http'
require 'nokogiri'
require 'chartkick'

get '/' do
  erb :index
end

post '/redirect_to_garden' do
  redirect "/#{params[:user_name]}"
end

get "/:name" do
  @garden = Garden.new(params[:name])
  redirect "/" if @garden.has_no_owner?

  erb  :garden
end


class Garden
  attr_reader :user_name, :garden_svg

  def initialize(user_name)
    @user_name = user_name
    @garden_svg = fetch_garden_svg
    @rects = Nokogiri::HTML.parse(@garden_svg).css("rect")
  end

  def has_no_owner?
    @garden_svg.nil?
  end

  def consecutive_days
    consecutive_each { |_| 1 }
  end

  def consecutive_total_contribs
    consecutive_each { |rect| contribute_count_of(rect) }
  end

  def consecutive_average_contribs
    return 0.0 if consecutive_days == 0
    (consecutive_total_contribs.to_f / consecutive_days).round(2)
  end

  def contributed_days_last_year
    count = 0
    @rects.each do |rect|
      next if contribute_count_of(rect) == 0
      count += 1
    end
    count
  end

  def total_contribs_last_year
    total = 0

    @rects.each do |rect|
      next if contribute_count_of(rect) == 0
      total += contribute_count_of(rect)
    end
    total
  end

  def average_contribs_last_year
    return 0.0 if contributed_days_last_year == 0
    (total_contribs_last_year / contributed_days_last_year).round(2)
  end

  def contribs_per_week
    data = {}
    @rects.each_slice(7) do |week_rects|
      data[date_of(week_rects.first)] = week_rects.sum { |rect| contribute_count_of(rect) }
    end
    data
  end

  private

  def fetch_garden_svg
    uri = URI.parse("https://github.com/users/#{user_name}/contributions")
    garden_svg = Net::HTTP.get_response(uri).body
    return nil if garden_svg.to_s == "Not Found"
    garden_svg
  end

  def consecutive_each
    rects = @rects.reverse
    count = 0

    rects[1..-1].each do |rect|
      break if contribute_count_of(rect) == 0
      count += yield rect
    end

    count += yield rect if contribute_count_of(rects[0]) != 0
    count
  end

  def date_of(rect)
    rect.attributes["data-date"].value
  end

  def contribute_count_of(rect)
    rect.attributes["data-count"].value.to_i
  end
end
