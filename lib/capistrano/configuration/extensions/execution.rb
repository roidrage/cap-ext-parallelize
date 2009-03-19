module Capistrano
  class Configuration
    module Extensions
      module Execution
        def task_call_frames
          Thread.current[:task_call_frames] ||= []
        end
  
        def rollback_requests=(rollback_requests)
          Thread.current[:rollback_requests] = rollback_requests
        end
  
        def rollback_requests
          Thread.current[:rollback_requests]
        end

        def current_task
          all_task_call_frames = Thread.main[:task_call_frames] + task_call_frames
          return nil if all_task_call_frames.empty?
          all_task_call_frames.last.task
        end
  
        def transaction?
          !(rollback_requests.nil? && Thread.main[:rollback_requests].nil?)
        end
  
        def transaction(&blk)
          super do
            self.rollback_requests = [] unless transaction?
            blk.call
          end
        end

        def on_rollback(&block)
          self.rollback_requests ||= [] if transaction?
          super
        end

        def rollback!
          return if Thread.current[:rollback_requests].nil?
          Thread.current[:rolled_back] = true
          super
        end
      end
    end
  end
end