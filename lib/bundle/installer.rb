# frozen_string_literal: true

module Bundle
  module Installer
    module_function

    def install(entries, global: false, file: nil, no_lock: false, no_upgrade: false, verbose: false)
      success = 0
      failure = 0

      entries.each do |entry|
        args = [entry.name]
        options = {}
        verb = "Installing"
        cls = case entry.type
        when :brew
          options = entry.options
          Bundle::BrewInstaller
        when :cask
          options = entry.options
          Bundle::CaskInstaller
        when :mas
          args << entry.options[:id]
          Bundle::MacAppStoreInstaller
        when :whalebrew
          Bundle::WhalebrewInstaller
        when :tap
          verb = "Tapping"
          options = entry.options
          Bundle::TapInstaller
        end

        next if Bundle::Skipper.skip? entry

        case cls.install(*args, **options, no_upgrade: no_upgrade, verbose: verbose)
        when :success
          puts Formatter.success("#{verb} #{entry.name}")
          success += 1
        when :skipped
          puts "Using #{entry.name}"
          success += 1
        when :aborted
          puts Formatter.error("#{verb} #{entry.name} has failed! Aborting!")
          failure += 1
          break
        else
          puts Formatter.error("#{verb} #{entry.name} has failed!")
          failure += 1
        end
      end

      unless failure.zero?
        puts Formatter.error "Homebrew Bundle failed! "\
                             "#{failure} Brewfile #{Bundle::Dsl.pluralize_dependency(failure)} failed to install."
        if (lock = Bundle::Locker.lockfile(global: global, file: file)) && lock.exist?
          puts Formatter.error("Check for differences in your #{lock.basename}!")
        end
        return false
      end

      Bundle::Locker.lock(entries, global: global, file: file, no_lock: no_lock)

      puts Formatter.success "Homebrew Bundle complete! "\
                             "#{success} Brewfile #{Bundle::Dsl.pluralize_dependency(success)} now installed."
      true
    end
  end
end
