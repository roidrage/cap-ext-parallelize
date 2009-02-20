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
          set :parallelize_thread_count, 10 unless respond_to?(:parallelize_thread_count)
          
          proxy = BlockProxy.new
          yield proxy
          
          batch = 1
          logger.info "Running #{proxy.blocks.size} blocks in chunks of #{parallelize_thread_count}"
          
          proxy.blocks.each_slice(parallelize_thread_count) do |chunk|
            logger.info "Running batch number #{batch}"
            threads = run_in_threads(chunk)
            wait_for(threads)
            rollback_all_threads(threads) and return if threads.any? {|t| t[:rolled_back]}
            batch += 1
          end
        end
        
        def run_in_threads(blocks)
          blocks.collect do |blk|
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
          true
        end
        
      end
    end
  end
end