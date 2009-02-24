module Capistrano
  class Configuration
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
      
      alias :transaction_without_thread_local :transaction
      def transaction
        transaction_without_thread_local do
          self.rollback_requests = [] unless transaction?
          yield
        end
      end

      alias :rollback_without_thread_local :rollback!
      def rollback!
        return if Thread.current[:rollback_requests].nil?
        
        Thread.current[:rolled_back] = true
        rollback_without_thread_local
      end
    end
  end
end
