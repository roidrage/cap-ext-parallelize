module Capistrano
  class Configuration
    module Extensions
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
      
          def parallelize(thread_count = nil)
            set :parallelize_thread_count, 10 unless respond_to?(:parallelize_thread_count)
        
            proxy = BlockProxy.new
            yield proxy
        
            logger.info "Running #{proxy.blocks.size} threads in chunks of #{thread_count || parallelize_thread_count}"
        
            run_parallelize_loop(proxy, thread_count || parallelize_thread_count)
          end

          def run_parallelize_loop(proxy, thread_count)
            batch = 1
            all_threads = []
            proxy.blocks.each_slice(thread_count) do |chunk|
              logger.info "Running batch number #{batch}"
              threads = run_in_threads(chunk)
              all_threads << threads
              wait_for(threads)
              rollback_all_threads(all_threads.flatten) and return if threads.any? {|t| t[:rolled_back] || t[:exception_raised]}
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
              rescue ThreadError
                thread[:exception_raised] = $!
              end
              thread
            end
          end
      
          def wait_for(threads)
            threads.each do |thread|
              begin
                thread.join
              rescue
                logger.important "Subthread failed: #{$!.message}"
                thread[:exception_raised] = $!
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
end