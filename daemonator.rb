#!/usr/bin/env ruby
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
      $running = false
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
  
  def init_rails!
    log_level = ("ActiveSupport::BufferedLogger::Severity::"+Brandid::Application.config.log_level.to_s.upcase).constantize
    @logger = ActiveSupport::BufferedLogger.new(File.join(Rails.root, "log", "#{@name.underscore}.log"), log_level)
    Rails.logger.close rescue nil
    ActiveRecord::Base.logger.close rescue nil
    Rails.logger = @logger
    ActiveRecord::Base.logger = @logger
    ActiveRecord::Base.establish_connection
  end
  
  def cleanup!
    @logger.close
  end
end