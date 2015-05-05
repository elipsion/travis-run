module Travis
  class FakeReporter
    # Such ashamed :(
    def send_log(job_id, message, last_message = false)
      puts message
    end

    def method_missing(method_sym, *arguments, &block)
      # the first argument is a Symbol, so you need to_s it if you want to pattern match
      if method_sym.to_s =~ /^notify_job_(.*)$/
        send_log(arguments.first, "Job #{$1}")
      else
        send_log(0, "Stub method: #{method_sym.to_s}")
      end
    end
  end

  module CLI
    class Run < RepoCommand
      description "runs a build script described by .travis.yml"

      def setup
        error "run command is not available on #{RUBY_VERSION}" if RUBY_VERSION < '1.9.3'
        $:.unshift File.expand_path('../../travis-build/lib', __FILE__)
        $:.unshift File.expand_path('../../travis-worker/lib', __FILE__)
        $:.unshift File.expand_path('../lib', __FILE__)
        require 'travis/build'
        require 'travis/worker'
        require 'travis/support/logging'
        require 'travis/support/retryable'
        require 'travis/worker/job/script'
        require 'travis/worker/job/runner'
        require 'travis/worker/virtual_machine'
      end

      def run(*arg)
        @slug = find_slug
        config = travis_config

        payload = {
          'config' => config,
          :config  => config,
          :repository => {
            :slug => @slug
          },
          'job' => {
            'id' => 1
          }
        }
        payload['script'] = Travis::Build.script(payload).compile(true)
        name = 'localhost-1'
        vm = Travis::Worker::VirtualMachine.provider.new(name)
        vm.prepare
        vm_opts = {
          language: config['language'],
          job_id: 1,
          custom_image: config['osx_image'], #WUUT
          dist: config['dist'],
          groups: config['group'],
        }
        timeouts = {
          hard_limit: 3600,
          log_silence: 600,
        }
        vm.sandboxed(vm_opts) do
          runner = Travis::Worker::Job::Runner.new(payload, vm.session, FakeReporter.new, vm.full_name, timeouts, name)
          runner.run
        end
      end
    end
  end
end
