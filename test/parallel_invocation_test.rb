require "utils"
require "capistrano/task_definition"
require "capistrano/configuration"
require "#{File.join(File.dirname(__FILE__), '..', 'lib')}/cap_ext_parallelize"

class ConfigurationActionsParallelInvocationTest < Test::Unit::TestCase
  class MockConfig
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
  end

  def setup
    @config = MockConfig.new(:logger => stub(:debug => nil, :info => nil, :important => nil))
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

  def test_should_not_rollback_threads_twice

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
    aaa = new_task(@config, :aaa) do
      parallelize do |session|
        session.run {execute_task(bbb)}
        session.run {execute_task(ddd)}
      end
    end
  end
  
  private
  def new_task(namespace, name, options={}, &block)
    block ||= stack_inspector
    namespace.tasks[name] = Capistrano::TaskDefinition.new(name, namespace, &block)
  end
  
end