# frozen_string_literal: true

require "spec_helper"

describe Bundle::Commands::Cleanup do
  context "read Brewfile and currently installation" do
    before do
      Bundle::Commands::Cleanup.reset!
      allow(ARGV).to receive(:value).and_return(nil)
      allow_any_instance_of(Pathname).to receive(:read).and_return <<~EOS
        tap 'x'
        tap 'y'
        cask '123'
        brew 'a'
        brew 'b'
        brew 'd2'
        brew 'homebrew/tap/f'
        brew 'homebrew/tap/g'
        brew 'homebrew/tap/h'
        brew 'homebrew/tap/i2'
        brew 'homebrew/tap/hasdependency'
        brew 'hasbuilddependency1'
        brew 'hasbuilddependency2'
      EOS
    end

    it "computes which casks to uninstall" do
      allow(Bundle::CaskDumper).to receive(:casks).and_return(%w[123 456])
      expect(Bundle::Commands::Cleanup.casks_to_uninstall).to eql(%w[456])
    end

    it "computes which formulae to uninstall" do
      allow(Bundle::BrewDumper).to receive(:formulae).and_return [
        { name: "a2", full_name: "a2", aliases: ["a"], dependencies: ["d"] },
        { name: "c", full_name: "c" },
        { name: "d", full_name: "homebrew/tap/d", aliases: ["d2"] },
        { name: "e", full_name: "homebrew/tap/e" },
        { name: "f", full_name: "homebrew/tap/f" },
        { name: "h", full_name: "other/tap/h" },
        { name: "i", full_name: "homebrew/tap/i", aliases: ["i2"] },
        { name: "hasdependency", full_name: "homebrew/tap/hasdependency", dependencies: ["isdependency"] },
        { name: "isdependency", full_name: "homebrew/tap/isdependency" },
        { name: "hasbuilddependency1", full_name: "hasbuilddependency1", poured_from_bottle?: true, build_dependencies: ["builddependency1"] },
        { name: "hasbuilddependency2", full_name: "hasbuilddependency2", poured_from_bottle?: false, build_dependencies: ["builddependency2"] },
        { name: "builddependency1", full_name: "builddependency1" },
        { name: "builddependency2", full_name: "builddependency2" },
      ].map { |f| { dependencies: [], build_dependencies: [] }.merge(f) }
      expect(Bundle::Commands::Cleanup.formulae_to_uninstall).to eql %w[
        c
        homebrew/tap/e
        other/tap/h
        builddependency1
      ]
    end

    it "computes which tap to untap" do
      allow(Bundle::TapDumper).to receive(:tap_names).and_return(%w[z homebrew/bundle homebrew/core])
      expect(Bundle::Commands::Cleanup.taps_to_untap).to eql(%w[z])
    end
  end

  context "no formulae to uninstall and no taps to untap" do
    before do
      Bundle::Commands::Cleanup.reset!
      allow(Bundle::Commands::Cleanup).to receive(:casks_to_uninstall).and_return([])
      allow(Bundle::Commands::Cleanup).to receive(:formulae_to_uninstall).and_return([])
      allow(Bundle::Commands::Cleanup).to receive(:taps_to_untap).and_return([])
      expect(Bundle::Commands::Cleanup).to receive(:system_output_no_stderr).and_return("")
      allow(ARGV).to receive(:force?).and_return(true)
    end

    it "does nothing" do
      expect(Kernel).not_to receive(:system)
      Bundle::Commands::Cleanup.run
    end
  end

  context "there are casks to uninstall" do
    before do
      Bundle::Commands::Cleanup.reset!
      allow(Bundle::Commands::Cleanup).to receive(:casks_to_uninstall).and_return(%w[a b])
      allow(Bundle::Commands::Cleanup).to receive(:formulae_to_uninstall).and_return([])
      allow(Bundle::Commands::Cleanup).to receive(:taps_to_untap).and_return([])
      expect(Bundle::Commands::Cleanup).to receive(:system_output_no_stderr).and_return("")
      allow(ARGV).to receive(:force?).and_return(true)
    end

    it "uninstalls casks" do
      expect(Kernel).to receive(:system).with("brew", "cask", "uninstall", "--force", "a", "b")
      expect { Bundle::Commands::Cleanup.run }.to output(/Uninstalled 2 casks/).to_stdout
    end
  end

  context "there are casks to zap" do
    before do
      Bundle::Commands::Cleanup.reset!
      allow(Bundle::Commands::Cleanup).to receive(:casks_to_uninstall).and_return(%w[a b])
      allow(Bundle::Commands::Cleanup).to receive(:formulae_to_uninstall).and_return([])
      allow(Bundle::Commands::Cleanup).to receive(:taps_to_untap).and_return([])
      expect(Bundle::Commands::Cleanup).to receive(:system_output_no_stderr).and_return("")
      allow(ARGV).to receive(:force?).and_return(true)
      ARGV << "--zap"
    end

    it "uninstalls casks" do
      expect(Kernel).to receive(:system).with("brew", "cask", "zap", "--force", "a", "b")
      expect { Bundle::Commands::Cleanup.run }.to output(/Uninstalled 2 casks/).to_stdout
    end
  end

  context "there are formulae to uninstall" do
    before do
      Bundle::Commands::Cleanup.reset!
      allow(Bundle::Commands::Cleanup).to receive(:casks_to_uninstall).and_return([])
      allow(Bundle::Commands::Cleanup).to receive(:formulae_to_uninstall).and_return(%w[a b])
      allow(Bundle::Commands::Cleanup).to receive(:taps_to_untap).and_return([])
      expect(Bundle::Commands::Cleanup).to receive(:system_output_no_stderr).and_return("")
      allow(ARGV).to receive(:force?).and_return(true)
    end

    it "uninstalls formulae" do
      expect(Kernel).to receive(:system).with("brew", "uninstall", "--force", "a", "b")
      expect { Bundle::Commands::Cleanup.run }.to output(/Uninstalled 2 formulae/).to_stdout
    end
  end

  context "there are taps to untap" do
    before do
      Bundle::Commands::Cleanup.reset!
      allow(Bundle::Commands::Cleanup).to receive(:casks_to_uninstall).and_return([])
      allow(Bundle::Commands::Cleanup).to receive(:formulae_to_uninstall).and_return([])
      allow(Bundle::Commands::Cleanup).to receive(:taps_to_untap).and_return(%w[a b])
      expect(Bundle::Commands::Cleanup).to receive(:system_output_no_stderr).and_return("")
      allow(ARGV).to receive(:force?).and_return(true)
    end

    it "untaps taps" do
      expect(Kernel).to receive(:system).with("brew", "untap", "a", "b")
      Bundle::Commands::Cleanup.run
    end
  end

  context "there are casks and formulae to uninstall and taps to untap but without passing `--force`" do
    before do
      Bundle::Commands::Cleanup.reset!
      allow(Bundle::Commands::Cleanup).to receive(:casks_to_uninstall).and_return(%w[a b])
      allow(Bundle::Commands::Cleanup).to receive(:formulae_to_uninstall).and_return(%w[a b])
      allow(Bundle::Commands::Cleanup).to receive(:taps_to_untap).and_return(%w[a b])
      expect(Bundle::Commands::Cleanup).to receive(:system_output_no_stderr).and_return("")
      allow(ARGV).to receive(:force?).and_return(false)
    end

    it "lists casks, formulae and taps" do
      expect(Formatter).to receive(:columns).with(%w[a b]).exactly(3).times
      expect(Kernel).not_to receive(:system)
      expect { Bundle::Commands::Cleanup.run }.to output(/Would uninstall formulae:.*Would untap:/m).to_stdout
    end
  end

  context "there is brew cleanup output" do
    before do
      Bundle::Commands::Cleanup.reset!
      allow(Bundle::Commands::Cleanup).to receive(:casks_to_uninstall).and_return([])
      allow(Bundle::Commands::Cleanup).to receive(:formulae_to_uninstall).and_return([])
      allow(Bundle::Commands::Cleanup).to receive(:taps_to_untap).and_return([])
      expect(Bundle::Commands::Cleanup).to receive(:system_output_no_stderr).and_return("cleaned")
    end

    context "with --force" do
      before do
        allow(ARGV).to receive(:force?).and_return(true)
      end

      it "prints output" do
        expect { Bundle::Commands::Cleanup.run }.to output(/cleaned/).to_stdout
      end
    end

    context "without --force" do
      before do
        allow(ARGV).to receive(:force?).and_return(false)
      end

      it "prints output" do
        expect { Bundle::Commands::Cleanup.run }.to output(/cleaned/).to_stdout
      end
    end
  end

  context "#system_output_no_stderr" do
    it "shells out" do
      expect(IO).to receive(:popen).and_return(StringIO.new("true"))
      Bundle::Commands::Cleanup.system_output_no_stderr("true")
    end
  end
end
