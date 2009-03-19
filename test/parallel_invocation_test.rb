require "utils"
require "capistrano/task_definition"
require "capistrano/configuration"
require "#{File.join(File.dirname(__FILE__), '..', 'lib')}/cap_ext_parallelize"

class ConfigurationActionsParallelInvocationTest < Test::Unit::TestCase
  class MockConfig
    attr_reader :roles
    attr_reader :options
    attr_accessor :debug
    attr_accessor :dry_run
    attr_reader :tasks, :namespaces, :fully_qualified_name, :parent
    attr_reader :state, :original_initialize_called
    attr_accessor :logger, :default_task
    attr_accessor :parallelize_thread_count
    
    def initialize(options)
      @original_initialize_called = true
      @tasks = {}
      @namespaces = {}
      @state = {}
      @fully_qualified_name = options[:fqn]
      @parent = options[:parent]
      @logger = options.delete(:logger)
      @options = {}
      @parallelize_thread_count = 10
      @roles = {}
    end

    def [](*args)
      @options[*args]
    end

    def set(name, value)
      @options[name] = value
    end

    def fetch(*args)
      @options.fetch(*args)
    end

    include Capistrano::Configuration::Execution
    include Capistrano::Configuration::Actions::Invocation
    include Capistrano::Configuration::Extensions::Execution
    include Capistrano::Configuration::Extensions::Actions::Invocation
    include Capistrano::Configuration::Servers
    include Capistrano::Configuration::Connections
  end

  def setup
    @config = MockConfig.new(:logger => stub(:debug => nil, :info => nil, :important => nil, :trace => nil))
    @original_io_proc = MockConfig.default_io_proc
  end
  
  def test_parallelize_should_run_all_collected_tasks
    aaa = new_task(@config, :aaa) do
      parallelize do |session|
        session.run {(state[:has_been_run] ||= []) << :first}
        session.run {(state[:has_been_run] ||= []) << :second}
      end
    end
    @config.execute_task(aaa)
    assert @config.state[:has_been_run].include?(:first)
    assert @config.state[:has_been_run].include?(:second)
  end
  
  def test_parallelize_should_rollback_all_threads_when_one_thread_raises_error
    ccc = new_task(@config, :ccc) do
      on_rollback {(state[:rollback] ||= []) << :first}
      raise "boom"
    end

    eee = new_task(@config, :eee) do
      on_rollback {(state[:rollback] ||= []) << :second}
    end
    
    ddd = new_task(@config, :ddd) do
      transaction {execute_task(eee)}
    end

    bbb = new_task(@config, :bbb) {transaction {execute_task(ccc)}}
    
    aaa = new_task(@config, :aaa) do
      on_rollback {puts 'rolled back'}
      parallelize do |session|
        session.run {execute_task(bbb)}
        session.run {execute_task(ddd)}
      end
    end
    
    @config.execute_task(aaa)
    assert @config.state[:rollback].include?(:first)
    assert @config.state[:rollback].include?(:second)
  end
  
  def test_parallelize_should_rollback_only_run_threads_when_one_thread_raises_error
    ccc = new_task(@config, :ccc) do
      on_rollback {(state[:rollback] ||= []) << :first}
      raise "boom"
    end

    eee = new_task(@config, :eee) do
      on_rollback {(state[:rollback] ||= []) << :second}
    end
    
    ddd = new_task(@config, :ddd) do
      transaction {execute_task(eee)}
    end

    bbb = new_task(@config, :bbb) {transaction {execute_task(ccc)}}
    
    aaa = new_task(@config, :aaa) do
      on_rollback {puts 'rolled back'}
      parallelize do |session|
        session.run {execute_task(bbb)}
        session.run {execute_task(ddd)}
      end
    end
    @config.parallelize_thread_count = 1
    @config.execute_task(aaa)
    assert @config.state[:rollback].include?(:first)
    assert !@config.state[:rollback].include?(:second)
  end
  
  def test_parallelize_should_rollback_all_threads_when_one_thread_raises_error
    ccc = new_task(@config, :ccc) do
      on_rollback {(state[:rollback] ||= []) << :first}
      sleep 0.1
      raise "boom"
    end

    eee = new_task(@config, :eee) do
      on_rollback {(state[:rollback] ||= []) << :second}
    end
    
    ddd = new_task(@config, :ddd) do
      transaction {execute_task(eee)}
    end

    bbb = new_task(@config, :bbb) {transaction {execute_task(ccc)}}
    
    aaa = new_task(@config, :aaa) do
      on_rollback {puts 'rolled back'}
      parallelize do |session|
        session.run {execute_task(bbb)}
        session.run {execute_task(ddd)}
      end
    end
    
    @config.execute_task(aaa)
    assert @config.state[:rollback].include?(:first)
    assert @config.state[:rollback].include?(:second)
  end
  
  def test_should_not_rollback_threads_twice
    ccc = new_task(@config, :ccc) do
      on_rollback {(state[:rollback] ||= []) << :first}
      raise "boom"
    end

    eee = new_task(@config, :eee) do
      on_rollback {(state[:rollback] ||= []) << :second}
    end
    
    ddd = new_task(@config, :ddd) do
      transaction {execute_task(eee)}
    end

    bbb = new_task(@config, :bbb) {transaction {execute_task(ccc)}}
    
    aaa = new_task(@config, :aaa) do
      on_rollback {puts 'rolled back'}
      parallelize do |session|
        session.run {execute_task(bbb)}
        session.run {execute_task(ddd)}
      end
    end
    
    @config.execute_task(aaa)
    assert_equal 2, @config.state[:rollback].size
    assert @config.state[:rollback].include?(:first)
    assert @config.state[:rollback].include?(:second)
  end

  def test_should_rollback_main_thread_too

    eee = new_task(@config, :eee) do
      on_rollback {(state[:rollback] ||= []) << :second}
    end
    
    ddd = new_task(@config, :ddd) do
      transaction {execute_task(eee)}
    end

    aaa = new_task(@config, :aaa) do
      on_rollback {(state[:rollback] ||= []) << :main}
      parallelize do |session|
        session.run {execute_task(bbb)}
        session.run {execute_task(ddd)}
      end
    end
    
    bbb = new_task(@config, :bbb) do
      transaction do
        execute_task(aaa)
      end
    end
    
    @config.execute_task(bbb)
    assert_equal 2, @config.state[:rollback].size
    assert @config.state[:rollback].include?(:main)
    assert @config.state[:rollback].include?(:second)
  end
  
  def test_should_run_each_run_block_in_separate_thread
    bbb = new_task(@config, :bbb) do
      # noop
    end
    
    ccc = new_task(@config, :ccc) do
      # noop
    end
    
    @threads = []
    aaa = new_task(@config, :aaa) do
      return parallelize do |session|
        session.run {execute_task(bbb)}
        session.run {execute_task(ccc)}
      end
    end
    @config.execute_task(aaa)
    assert_equal 2, @threads.size
    assert @threads.first.is_a?(Thread)
    assert @threads.second.is_a?(Thread)
  end
  
  def test_should_respect_roles_configured_in_the_calling_task
    web_server = role(@config, :web, "my.host")
    bgrnd_server = role(@config, :daemons, "my.other.host")

    main = new_task(@config, :aaa, :roles => :web) do
      parallelize do |session|
        session.run {run 'echo hello'}
      end
    end
    
    @config.stubs(:connection_factory)
    @config.expects(:establish_connection_to).with(web_server.first, []).returns(Thread.new {})
    @config.execute_task(main)
  end
  
  def test_should_rollback_when_main_thread_has_transaction_and_subthread_has_error
    bbb = new_task(@config, :bbb) do
      on_rollback {(state[:rollback] ||= []) << :second}
      raise
    end

    aaa = new_task(@config, :aaa) do
      transaction do
        parallelize do |session|
          session.run {execute_task(bbb)}
        end
      end
    end
    
    @config.execute_task(aaa)
    assert_equal 1, @config.state[:rollback].size
    assert @config.state[:rollback].include?(:second)
  end
  
  private
  def new_task(namespace, name, options={}, &block)
    block ||= stack_inspector
    namespace.tasks[name] = Capistrano::TaskDefinition.new(name, namespace, options, &block)
  end
  
end