# frozen_string_literal: true

module Gitlab
  module Backup
    module Cli
      module Shell
        # Abstraction to control shell command execution
        # It provides an easier API to common usages
        class Command < Base
          # @return [Hash<String,String>] a hash containing key=>values to be set as ENV when running the command
          attr_reader :env

          # @return [String|Pathname] A path where a Shell::Command should run from
          attr_reader :chdir

          # Result data structure from running a command
          #
          # @attr [String] stdout
          # @attr [String] stderr
          # @attr [Process::Status] status
          # @attr [Float] duration
          Result = Struct.new(:stdout, :stderr, :status, :duration, keyword_init: true)

          # Result data structure from running a command in single pipeline mode
          #
          # @attr [String] stderr
          # @attr [Process::Status] status
          # @attr [Float] duration
          SinglePipelineResult = Struct.new(:stderr, :status, :duration, keyword_init: true)

          # @example Usage
          #   Shell::Command.new('echo', 'Some amazing output').capture
          # @param [Array<String>] cmd_args a list of command and its arguments to run
          # @param [String|Pathname] chdir a path where Shell::Command should run from
          # @param [Hash<String,String>] env a hash containing key=>values to be set as ENV when running the command
          def initialize(*cmd_args, chdir: Gitlab::Backup::Cli.root, env: {})
            @cmd_args = cmd_args.freeze
            @chdir = chdir
            @env = env.freeze
          end

          # List of command arguments
          #
          # @param [Boolean] with_env whether to include env hash in the returned list
          # @return [Array<Hash|String>]
          def cmd_args(with_env: false)
            if with_env && env.any?
              # When providing cmd_args to `Open3.pipeline`, the env needs to be the first element of the array.
              #
              # While `Open3.capture3` accepts an empty hash as a valid parameter, it doesn't work with
              # `Open3.pipeline`, so we modify the returned array only when the env hash is not empty.
              @cmd_args.dup.prepend(env)
            else
              @cmd_args.dup
            end
          end

          # Execute a process and return its output and status
          #
          # @return [Command::Result] Captured output from executing a process
          def capture
            start = Time.now
            stdout, stderr, status = Open3.capture3(env, *cmd_args, chdir: chdir)
            duration = Time.now - start

            Result.new(stdout: stdout, stderr: stderr, status: status, duration: duration)
          end

          # Execute a process and intercept its captured output line by line
          #
          # @example Usage
          #    Shell::Command.new('echo', 'Some amazing output').capture_each { |stream, output| puts output }
          # @yieldparam [Symbol] stream type (either :stdout or :stderr)
          # @yieldparam [String] output
          # @return [Command::Result] -- Captured output from executing a process
          def capture_each
            start = Time.now

            stdout = +''
            stderr = +''
            status = Open3.popen3(env, *cmd_args, chdir: chdir) do |i, o, e, wait_thread|
              i.close_write

              io_threads = []
              io_threads << Thread.new do
                until o.eof?
                  o.gets.tap do |output|
                    stdout << output
                    yield :stdout, output.chomp
                  end
                end
              end
              io_threads << Thread.new do
                until e.eof?
                  e.gets.tap do |error|
                    stderr << error
                    yield :stderr, error.chomp
                  end
                end
              end

              io_threads.each(&:join)
              wait_thread.value
            end

            duration = Time.now - start
            Result.new(stdout: stdout, stderr: stderr, status: status, duration: duration)
          end

          # Run single command in pipeline mode with optional input or output redirection
          #
          # @param [IO|String|Array] input stdin redirection
          # @param [IO|String|Array] output stdout redirection
          # @return [Command::SinglePipelineResult]
          def run_single_pipeline!(input: nil, output: nil)
            start = Time.now
            input = typecast_input!(input)
            output = typecast_output!(output)

            # Open3 writes on `err_write` and we receive from `err_read`
            err_read, err_write = IO.pipe

            # Pipeline accepts custom {Process.spawn} options
            # stderr capture is always performed, stdin and stdout redirection
            # are performed only when either `input` or `output` are present
            options = { err: err_write } # redirect stderr to IO pipe
            options[:in] = input if input # redirect stdin
            options[:out] = output if output # redirect stdout

            status_list = Open3.pipeline(cmd_args(with_env: true), chdir: chdir, **options)
            duration = Time.now - start

            err_write.close # close the pipe before reading
            stderr = err_read.read
            err_read.close # close after reading to avoid leaking file descriptors

            SinglePipelineResult.new(stderr: stderr, status: status_list[0], duration: duration)
          end
        end
      end
    end
  end
end
