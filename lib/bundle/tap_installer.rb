# frozen_string_literal: true

module Bundle
  module TapInstaller
    module_function

    def install(name, verbose: false, **options)
      if installed_taps.include? name
        puts "Skipping install of #{name} tap. It is already installed." if verbose
        return :skipped
      end

      puts "Installing #{name} tap. It is not currently installed." if verbose
      success = if options[:clone_target]
        Bundle.system HOMEBREW_BREW_FILE, "tap", name, options[:clone_target], verbose: verbose
      else
        Bundle.system HOMEBREW_BREW_FILE, "tap", name, verbose: verbose
      end

      return :aborted unless success

      installed_taps << name
      :success
    end

    def installed_taps
      @installed_taps ||= Bundle::TapDumper.tap_names
    end
  end
end
