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
          
          threads = proxy.blocks.collect do |block|
            t = Thread.new(&block)
            t.run
            t
          end

          threads.each do |t|
            t.join
          end
        end
      end
    end
  end
end