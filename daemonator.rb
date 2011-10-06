#!/usr/bin/env ruby
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'config', 'environment'))
require 'daemons'

class Daemonator
  def initialize(name, interval, user_opts={})
    @name = name
    @interval = interval
    @opts = {
      :multiple => false,
      :ontop => true,
      :backtrace => true,
      :monitor => false,
      :dir_mode => :normal,
      :dir => File.join(Rails.root, "tmp", "pids"),
      :log_dir => File.join(Rails.root, "log"),
      :log_output => true
      }
      @opts.merge!(user_opts)
      
      self.init_logger!
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

  def logger
    return @logger
  end
  protected

  def do_daemonize(&block)
    Daemons.run_proc(@name, @opts) do
      require File.expand_path(File.join(File.dirname(__FILE__), '..', 'config', 'environment'))
      self.init_logger!
      
      $running = true
      Signal.trap("TERM") do 
        $running = false
      end

      while($running) do
  
        Rails.logger.auto_flushing = true
        Rails.logger.info "#{@name} is still running at #{Time.now}.\n"

        do_yield(&block)

        sleep 3
      end

    end
  end
  
  def do_yield(&block)
    begin
      block.call
    rescue IOError => e
      init_logger!
      retry
    rescue Exception => e
      raise e
    end
  end
  
  def init_logger!
    @logger = ActiveSupport::BufferedLogger.new(File.join(Rails.root, "log", "#{@name.underscore}.log"))
    Rails.logger.close rescue nil
    ActiveRecord::Base.logger.close rescue nil
    Rails.logger = @logger
    ActiveRecord::Base.logger = @logger
    
  end
end