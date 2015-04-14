module Travis
  module Worker
    module Job
      class Runner
        def announce(message)
          puts message
        end
      end
    end
  end

  module CLI
    class Run < RepoCommand
      description "runs a build script described by .travis.yml"

      def setup
        error "run command is not available on #{RUBY_VERSION}" if RUBY_VERSION < '1.9.3'
        $:.unshift File.expand_path('../lib', __FILE__)
        require 'travis/build'
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
          }
        }
        payload['script'] = Travis::Build.script(payload).compile(true)
        name = 'foo'
        vm = Travis::Worker::VirtualMachine.provider.new(name)
        vm.prepare
        vm_opts = {
          language: config['language'],
          job_id: 1,
          custom_image: config['osx_image'], #WUUT
          dist: config['dist'],
          groups: config['group'],
        }
        vm.sandboxed(vm_opts) do
          runner = Job::Runner.new(payload, vm.session, nil, vm.full_name, timeouts, name)
          runner.run
        end
      end
    end
  end
end
