module Capistrano
  class Configuration
    module Actions
      module Invocation

        class BlockProxy
          attr_accessor :blocks
          
          def initialize
            @blocks = []
          end
          
          def run(&block)
            blocks << block
          end
        end
        
        def parallelize
          proxy = BlockProxy.new
          yield proxy
          
          threads = run_in_threads(proxy)
          wait_for(threads)
          rollback_all_threads(threads) if threads.any? {|t| t[:rolled_back]}
        end
        
        def run_in_threads(proxy)
          proxy.blocks.collect do |blk|
            thread = Thread.new do
              logger.info "Running block in background thread"
              blk.call
            end
            begin
              thread.run
            rescue ThreadError; end
            thread
          end
        end
        
        def wait_for(threads)
          threads.each do |thread|
            begin
              thread.join
            rescue
              logger.important "Subthread failed: #{$!.message}"
            end
          end
        end
   
        def rollback_all_threads(threads)
          Thread.new do
            threads.select {|t| !t[:rolled_back]}.each do |thread|
              Thread.current[:rollback_requests] = thread[:rollback_requests]
              rollback!
            end
          end.join
          rollback! # Rolling back main thread too
        end
        
      end
    end
  end
end