#!/usr/bin/env ruby
require 'rubygems'
require 'gattica'
require 'erb'

# silence https warnings...
class Net::HTTP
  alias_method :old_initialize, :initialize
  def initialize(*args)
    old_initialize(*args)
    @ssl_context = OpenSSL::SSL::SSLContext.new
    @ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
end

# oooh, fancy
class String
    def colorize(text, color_code)  "#{color_code}#{text}\e[0m" end
    def bold; colorize(self, "\e[1m\e[1m"); end
    def reverse; colorize(self, "\e[1m\e[7m"); end
    def red; colorize(self, "\e[1m\e[31m"); end
    def green; colorize(self, "\e[1m\e[32m"); end
    def dark_green; colorize(self, "\e[32m"); end
    def yellow; colorize(self, "\e[1m\e[33m"); end
    def blue; colorize(self, "\e[1m\e[34m"); end
end

module Todata
  DEFAULT_TEMPLATE = <<-END
----------------------------------------------------------------------  
<%= "Todata".bold %> [<%= @today %>]
----------------------------------------------------------------------  
Visits:     <%= @metrics[:visits].to_s.red.bold %>
Pageviews:  <%= @metrics[:pageviews].to_s.red.bold %>
----------------------------------------------------------------------
Top Referrers:
  <% @metrics[:referrers].each_with_index do |r,i| %>
  <%= (String(i+1)<<".").rjust(3) %> <%= (r[:source]+r[:referralPath]).green.bold %> (<%= r[:pageviews].to_s.blue %>)<% end %>
----------------------------------------------------------------------
END
  class DataBinding
    def initialize(today, metrics)
      @today = today
      @metrics = metrics
    end  

    def get_binding; binding; end
  end

  def self.run(path)
    begin
      @config = YAML.load_file(path) 
    rescue
      puts "Could not read ~/.todatarc"
      exit 1
    end
    
    %w(password email profile_id).each do |f|
      raise "Make sure your .todatarc file contains a #{f}." unless @config.include?(f)
    end

    g = Gattica.new({:email => @config['email'], :password => @config['password'], :profile_id => @config['profile_id']})
    today = Time.now.strftime("%Y-%m-%d")
    metrics = {}
    metric_fields = %w(pageviews visits)
    today_opts = {:start_date => today, :end_date => today }
    stat_query= g.get(today_opts.merge(:metrics => metric_fields, :sort => ['-pageviews']))
    ref_query = g.get(today_opts.merge(:metrics => ['pageviews'], :dimensions => ['referralPath', 'source'], :sort => ['-pageviews']))

    metric_fields.each_with_index do |m,i|
      metrics[m.to_sym] = stat_query.points.first.metrics[i][m.to_sym]
    end
    metrics[:referrers] = ref_query.points[0...15].collect{|r| r.dimensions.first.merge(r.dimensions.last.merge(:pageviews => r.metrics.first[:pageviews]))}
    puts ERB.new(@config.include?('template') ? @config['template'] : DEFAULT_TEMPLATE).result(DataBinding.new(today, metrics).get_binding)
  end
end

Todata.run(File.join(ENV['HOME'], '.todatarc'))
