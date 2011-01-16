require 'autotest'

class RSpecCommandError < StandardError; end

class Autotest::Rspec2 < Autotest

  SPEC_PROGRAM = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'bin', 'rspec'))

  def initialize
    super
    clear_mappings
    setup_rspec_project_mappings

    # Example for Ruby 1.8: http://rubular.com/r/AOXNVDrZpx
    # Example for Ruby 1.9: http://rubular.com/r/85ag5AZ2jP
    self.failed_results_re = /^\s*\d+\).*\n\s+Failure.*(\n\s+#\s(.*)?:\d+(?::.*)?)+$/m
    self.completed_re = /\n(?:\e\[\d*m)?\d* examples?/m
  end

  def setup_rspec_project_mappings
    add_mapping(%r%^spec/.*_spec\.rb$%) { |filename, _|
      filename
    }
    add_mapping(%r%^lib/(.*)\.rb$%) { |_, m|
      ["spec/#{m[1]}_spec.rb"]
    }
    add_mapping(%r%^spec/(spec_helper|shared/.*)\.rb$%) {
      files_matching %r%^spec/.*_spec\.rb$%
    }
  end

  def consolidate_failures(failed)
    filters = new_hash_of_arrays
    failed.each do |spec, trace|
      if trace =~ /(.*spec\.rb)/
        filters[$1] << spec
      end
    end
    return filters
  end

  def make_test_cmd(files_to_test)
    rspec_options, bundle = remove_rspec_options!

    files_to_test.empty? ? '' :
    "#{rspec_command(bundle)} #{rspec_options_string(rspec_options)} --tty #{normalize(files_to_test).keys.flatten.map { |f| "'#{f}'"}.join(' ')}"
  end

  def bundle_exec
    using_bundler? ? "bundle exec " : ""
  end

  def require_rubygems
    using_bundler? ? "" : defined?(:Gem) ? "-rrubygems " : " "
  end

  def normalize(files_to_test)
    files_to_test.keys.inject({}) do |result, filename|
      result[File.expand_path(filename)] = []
      result
    end
  end

  def using_bundler?
    File.exists?('./Gemfile')
  end

  private

  # Sending RSpec command line options through Autotest.
  # Requires that Autotest has options[:extras] available.
  # For example:
  #
  #     $ autotest --extra t,my_tag
  #
  # This would send RSpec the option '-t my_tag'.
  # It is also possible to send multiple options.
  #
  #     $ autotest -x t,my_tag -x format,documentation
  #
  # This gives '-t my_tag --format documentation.
  # Using the 'rspec' command instead of 'bundle exec ...'
  # is default. If you want to use 'bundle exec ...',
  # you can pass 'bundle' as an option:
  #
  #    $ autotest -x bundle
  #
  def remove_rspec_options!
    opts = self.options.delete(:extras)
    return [] unless opts
    bundle = opts.flatten.delete('bundle')
    opts = opts.delete_if { |arr| arr[0] == 'bundle' }
    [opts, bundle]
  end

  def rspec_command(bundle)
    bundle ? "#{bundle_exec}#{ruby} #{require_rubygems}-S #{SPEC_PROGRAM}" : "rspec"
  end

  def rspec_options_string(opts)
    return "" if opts.nil?

    opts.inject("") do |string, arr|
      option, value = arr[0], arr[1]
      option_str = option.size == 1 ? "-#{option}" : "--#{option}"
      value_str = value ? value : ""
      string << "#{option_str} #{value} "
    end
  end
end
