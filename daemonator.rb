#!/usr/bin/env ruby
#
# Copyright 2011 - Peter Philips
#
# This program is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 3 of the License, or
#     (at your option) any later version.
# 
#     This program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
# 
#     You should have received a copy of the GNU General Public License
#     along with this program.  If not, see <http://www.gnu.org/licenses/>.

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'config', 'environment'))
require 'daemons'

class Daemonator
  def initialize(name, interval, user_opts={})
    @name = name
    @interval = interval
    @opts = {
      :multiple => false,
      :ontop => false,
      :backtrace => true,
      :monitor => false,
      :dir_mode => :normal,
      :dir => File.join(Rails.root, "tmp", "pids"),
      :log_dir => File.join(Rails.root, "log"),
      :log_output => true,
      :stop_proc => lambda {puts "stopped proc";self.cleanup!}
      }
      @opts.merge!(user_opts)
      
      self.init_rails!
  end
  
  def daemonize!(&block)
    unless block_given?
      error_msg = "Must give block to daemonize! exiting..."
      puts error_msg
      Rails.logger.error error_msg
    end
      
    self.do_daemonize(&block)
    
  end

  protected

  def do_daemonize(&block)
    Daemons.run_proc(@name, @opts) do
      
      #require rails environment
      require File.expand_path(File.join(File.dirname(__FILE__), '..', 'config', 'environment'))
      
      #setup logger and db handles that are lost after forking
      self.init_rails!
      
      #The main loop
      while(true) do
  
        #some basic logging
        Rails.logger.auto_flushing = true
        Rails.logger.info "#{@name} is running at #{Time.now}.\n"

        #yield to actual daemon
        do_yield(&block)

        #take a break
        sleep @interval
      end
    end
  end
  
  #wrap the yield call so we can cleanly handle errors
  def do_yield(&block)
    begin
      block.call
    rescue Exception => e
      puts "Exception! #{e.to_s}"
      Rails.logger.error "Caught exception: #{e.to_s}"
      raise e
    end
  end
  
  #When the process is forked or whatever is done, screwy things happen
  #1. the file handles to all the loggers are lost
  #2. the active record database connection is lost
  #
  # - So we need to reinitialize them...
  #
  # yuck...
  def init_rails!
    log_level = ("ActiveSupport::BufferedLogger::Severity::"+Rails::Application.config.log_level.to_s.upcase).constantize
    @logger = ActiveSupport::BufferedLogger.new(File.join(Rails.root, "log", "#{@name.underscore}.log"), log_level)

    #NOTE/TODO: I noticed in the Rails docs, they will eventually make ActionView use a seperate logger
    #           than ActionController, so this will eventually need to be added in here
    [Rails, ActiveRecord::Base, ActionController::Base, ActionMailer::Base].each do |logged_module|
      #just in case there is a logger there, close it
      logged_module.logger.close rescue nil
      logged_module.logger = @logger
    end

    #reestablish db connection
    ActiveRecord::Base.establish_connection
  end
  
  def cleanup!
    @logger.close
  end
end