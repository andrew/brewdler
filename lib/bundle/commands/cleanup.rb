module Bundle::Commands
  class Cleanup
    def self.reset!
      @dsl = nil
      Bundle::CaskDumper.reset!
      Bundle::BrewDumper.reset!
      Bundle::TapDumper.reset!
      Bundle::BrewServices.reset!
    end

    def self.run
      casks = casks_to_uninstall
      formulae = formulae_to_uninstall
      taps = taps_to_untap
      unless ARGV.force?
        if casks.any?
          puts "Would uninstall casks:"
          puts_columns casks
        end

        if formulae.any?
          puts "Would uninstall formulae:"
          puts_columns formulae
        end

        if taps.any?
          puts "Would untap:"
          puts_columns taps
        end
      else
        if casks.any?
          Kernel.system "brew", "cask", "uninstall", "--force", *casks
          puts "Uninstalled #{casks.size} cask#{casks.size == 1 ? "" : "s"}"
        end

        if formulae.any?
          Kernel.system "brew", "uninstall", "--force", *formulae
          puts "Uninstalled #{formulae.size} formula#{formulae.size == 1 ? "" : "e"}"
        end

        if taps.any?
          Kernel.system "brew", "untap", *taps
        end
      end
    end

    private

    def self.casks_to_uninstall
      @dsl ||= Bundle::Dsl.new(Bundle.brewfile)
      kept_casks = @dsl.entries.select { |e| e.type == :cask }.map(&:name)
      current_casks = Bundle::CaskDumper.casks
      current_casks - kept_casks
    end

    def self.formulae_to_uninstall
      @dsl ||= Bundle::Dsl.new(Bundle.brewfile)
      kept_formulae = @dsl.entries.select { |e| e.type == :brew }.map(&:name)
      kept_formulae.map! { |f| Bundle::BrewDumper.formula_aliases[f] || f }
      current_formulae = Bundle::BrewDumper.formulae
      all_deps = Hash[current_formulae.map { |f| [f[:name], f[:dependencies]] }]
      all_reqs = Hash[current_formulae.map { |f|
        [f[:name], f[:requirements].map { |r| r["default_formula"] }.select {
          |r| ! r.nil? } ]
      }]
      all_deps.merge!(all_reqs) { |k, deps, reqs| deps + reqs }
      dependencies = {}
      kept_formulae.each { |f| dependencies[f] = all_deps[f] }
      # Work out nested dependencies
      old_dep_count = 0
      while old_dep_count != dependencies.count do
        old_dep_count = dependencies.count
        nested_deps = {}
        dependencies.values.flatten.each { |f| nested_deps[f] = all_deps[f] }
        dependencies.merge!(nested_deps)
      end
      kept_dependencies = dependencies.values.flatten.uniq
      kept_dependencies.map! { |f| Bundle::BrewDumper.formula_aliases[f] || f }
      kept_formulae.concat(kept_dependencies)
      current_formulae.reject do |f|
        Bundle::BrewInstaller.formula_in_array?(f[:full_name], kept_formulae)
      end.map { |f| f[:full_name] }
    end

    IGNORED_TAPS = %w[homebrew/core homebrew/bundle].freeze

    def self.taps_to_untap
      @dsl ||= Bundle::Dsl.new(Bundle.brewfile)
      kept_taps = @dsl.entries.select { |e| e.type == :tap }.map(&:name)
      current_taps = Bundle::TapDumper.tap_names
      current_taps - kept_taps - IGNORED_TAPS
    end
  end
end
