require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/json'
require 'uri'
require 'net/http'
require 'nokogiri'
require 'chartkick'
require 'active_support'
require 'active_support/core_ext'
require 'date'

get '/' do
  erb :index
end

post '/redirect_to_garden' do
  redirect "/#{params[:user_name]}"
end

get "/:name" do
  @garden = Garden.new(params[:name])
  redirect "/" if @garden.has_no_owner?

  erb :garden, layout: :garden_layout
end

get "/:name/by_year" do
  @garden = Garden.new(params[:name])
  redirect "/" if @garden.has_no_owner?

  erb :gardens_by_year, layout: :gardens_by_year_layout
end


class Garden
  attr_reader :user_name, :garden_svg

  def initialize(user_name)
    @user_name = user_name
    @garden_svg = fetch_garden_svg
    @entire_period_garden_svg = garden_svg_by_year.inject("") {|svg, each_year| svg += each_year[1]}
    @rects = Nokogiri::HTML.parse(@garden_svg).css("rect")
    @entire_period_rects = Nokogiri::HTML.parse(@entire_period_garden_svg).css("rect")
  end

  def has_no_owner?
    @garden_svg.nil?
  end

  def consecutive_days
    consecutive_each(@entire_period_rects.reverse) { |_| 1 }
  end

  def best_consecutive_days
    max_count = 0
    count = 0

    @entire_period_rects[0..-1].each do |rect|
      if contribute_count_of(rect) == 0
        max_count = [max_count, count].max
        count = 0
        next
      end
      count += 1
    end

    [max_count, count].max
  end

  def consecutive_total_contribs
    consecutive_each(@entire_period_rects.reverse) { |rect| contribute_count_of(rect) }
  end

  def consecutive_average_contribs
    return 0.0 if consecutive_days == 0
    (consecutive_total_contribs.to_f / consecutive_days).round(2)
  end

  def contributed_days_last_year
    @rects.count { |rect| contribute_count_of(rect) != 0 }
  end

  def total_contribs_last_year
    total_contribute_count_of(@rects)
  end

  def average_contribs_last_year
    return 0.0 if contributed_days_last_year == 0
    (total_contribs_last_year.to_f / contributed_days_last_year).round(2)
  end

  def contribs_per_day_for_chart
    @rects.reverse[0..60].reverse.reduce({}) do |data, rect|
      data[date_of(rect)] = contribute_count_of(rect)
      data
    end
  end

  def contribs_per_week_for_chart
    data = {}
    @rects.each_slice(7) do |week_rects|
      data[date_of(week_rects.first)] = total_contribute_count_of(week_rects)
    end
    data
  end

  def garden_svg_by_year
    (user_created_year || 2015..Date.today.year).reduce({}) do |hash, year|
      hash[year.to_s] = fetch_garden_svg({from: "#{year}-01-01"})
      hash
    end
  end

  private

  def fetch_garden_svg(query_params = nil)
    uri = URI.parse("https://github.com/users/#{user_name}/contributions" +
                    query_string(query_params))
    response = Net::HTTP.get_response(uri)
    garden_svg = Nokogiri::HTML.parse(response.body).search("svg").css(".js-calendar-graph-svg").to_s
    return nil if garden_svg.to_s == "Not Found"
    garden_svg
  end

  def github_user_info
    Net::HTTP.get_response(URI.parse("https://api.github.com/users/#{user_name}")).body
  end

  def user_created_year
    JSON.parse(github_user_info)["created_at"]&.to_date&.year
  end

  def query_string(params)
    return "" if params == nil
    "?#{params.to_query}"
  end

  def consecutive_each(rects)
    count = 0
    rects[1..-1].each do |rect|
      next if Date.parse(rect.attributes["data-date"].value) > Date.today
      break if contribute_count_of(rect) == 0
      count += yield rect
    end

    count += yield rects[0] if contribute_count_of(rects[0]) != 0
    count
  end

  def date_of(rect)
    rect.attributes["data-date"].value
  end

  def contribute_count_of(rect)
    rect.attributes["data-count"].value.to_i
  end

  def total_contribute_count_of(rects)
    rects.sum { |rect| contribute_count_of(rect) }
  end
end
