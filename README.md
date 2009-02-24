cap-ext-parallelize - A Capistrano extension for parallel task execution
=============

Imagine you want to restart several processes, either on one or on different
servers, but that flingin flangin Capistrano just doesn't want to run all the
restart tasks in parallel.

I know what you're saying, Capistrano already has a command called `parallel`.
That should do right? Not exactly, we wanted to be able to run complete tasks,
no arbitrary blocks in parallel. The command `parallel` is only able to run
specific shell commands, and it looks weird when you want to run several of
them on only one host.

We were inspired by the syntax though, so when you want to run arbitrary blocks
in your Capistrano tasks, you can do it like this:

    parallelize do |session|
      session.run {deploy.restart} 
      session.run {queue.restart}
      session.run {daemon.restart}
    end

Every task will be run in its own thread, opening a new connection to the server.
Because of this you should be aware of potential resource exhaustion. You can
limit the number of threads in two ways, either set a variable (it defaults
to 10):

    set :parallelize_thread_count, 10

Or specify it with a parameter:

    parallelize(5) do
      ...
    end

If one of your tasks ran in a transaction block and issued a rollback, 
parallelize will rollback all other threads, if they have rollback statements
defined.

Installation
============

1. Install the gem

    gem install -s http://gems.github.com mattmatt-cap-ext-parallelize

2. Add the following line to your Capfile

    require 'cap\_ext\_parallelize'

3. There is no step 3

License
=======

(c) 2009 Mathias Meyer, Jonathan Weiss

MIT-License