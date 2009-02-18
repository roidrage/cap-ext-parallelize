module Capistrano
  class Configuration
    # Thread-safe(r) version of the Capistrano default
    # connection handling.
    module Connections
      def initialize_with_connections(*args) #:nodoc:
        initialize_without_connections(*args)
        Thread.current[:sessions] = {}
        Thread.current[:failed_sessions] = []
      end

      # Indicate that the given server could not be connected to.
      def failed!(server)
        Thread.current[:failed_sessions] << server
      end
      
      # A hash of the SSH sessions that are currently open and available.
      # Because sessions are constructed lazily, this will only contain
      # connections to those servers that have been the targets of one or more
      # executed tasks.
      def sessions
        Thread.current[:sessions] ||= {}
      end
      
      # Query whether previous connection attempts to the given server have
      # failed.
      def has_failed?(server)
        Thread.current[:failed_sessions].include?(server)
      end
      
      def teardown_connections_to(servers)
        servers.each do |server|
          sessions[server].close
          sessions.delete(server)
        end
      end
      
      private
      def establish_connection_to(server, failures=nil)
        current_thread = Thread.current
        Thread.new { safely_establish_connection_to(server, current_thread, failures) }
      end

      def safely_establish_connection_to(server, thread, failures=nil)
        thread[:sessions] ||= {}
        thread[:sessions][server] ||= connection_factory.connect_to(server)
      rescue Exception => err
        raise unless failures
        failures << { :server => server, :error => err }
      end
    end
  end
end
