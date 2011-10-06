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
      :log_output => true
      }
      @opts.merge!(user_opts)
  end
  
  def daemonize!
    Daemons.run_proc(@name, @opts) do
      daemon_logger = ActiveSupport::BufferedLogger.new(File.join(Rails.root, "log", "#{@name.underscore}.log"))
      Rails.logger = daemon_logger
      ActiveRecord::Base.logger = daemon_logger

      $running = true
      Signal.trap("TERM") do 
        $running = false
      end

      unless block_given?
        error_msg = "Must give block to daemonize! exiting..."
        Rails.logger.error error_msg
        puts error_msg
        $running = false
      end


      while($running) do
  
        # Replace this with your code
        Rails.logger.auto_flushing = true
        Rails.logger.info "#{@name} is still running at #{Time.now}.\n"
  
        yield
        
        sleep 3
      end

    end
  end
end