describe RunLoop::CoreSimulator do

  before do
    allow(RunLoop::CoreSimulator).to receive(:terminate_core_simulator_processes).and_return true
    allow(RunLoop::Environment).to receive(:debug?).and_return true
    allow(RunLoop::CoreSimulator).to receive(:term_or_kill).and_return true
  end

  describe '.new' do

    it 'sets instance variable from arguments' do
      core_sim = RunLoop::CoreSimulator.new(:a, :b)

      expect(core_sim.instance_variable_get(:@device)).to be == :a
      expect(core_sim.instance_variable_get(:@app)).to be == :b
    end

    describe 'respects options' do
      let(:options) { { } }

      describe ':xcode' do
        it 'uses when available' do
          options[:xcode] = :xcode
          core_sim = RunLoop::CoreSimulator.new(:a, :b, options)

          expect(core_sim.instance_variable_get(:@xcode)).to be == :xcode
        end

        it 'ignores if not' do
          core_sim = RunLoop::CoreSimulator.new(:a, :b, options)

          expect(core_sim.instance_variable_get(:@xcode)).to be == nil
        end
      end

      describe ':quit_on_init' do
        it 'does not quit the simulator' do
          options[:quit_sim_on_init] = false
          expect(RunLoop::CoreSimulator).not_to receive(:quit_simulator)

          RunLoop::CoreSimulator.new(:a, :b, options)
        end

        it 'does quit the simulator' do
          expect(RunLoop::CoreSimulator).to receive(:quit_simulator).and_return true

          RunLoop::CoreSimulator.new(:a, :b, options)
        end
      end
    end
  end

  describe 'attrs' do
    let(:core_sim) { RunLoop::CoreSimulator.new(:a, :b) }

    it '#pbuddy' do
      pbuddy = core_sim.pbuddy
      expect(pbuddy).to be_a_kind_of(RunLoop::PlistBuddy)
      expect(core_sim.pbuddy).to be == pbuddy
      expect(core_sim.instance_variable_get(:@pbuddy)).to be == pbuddy
    end

    it '#xcode' do
      xcode = core_sim.xcode
      expect(xcode).to be_a_kind_of(RunLoop::Xcode)
      expect(core_sim.xcode).to be == xcode
      expect(core_sim.instance_variable_get(:@xcode)).to be == xcode
    end

    it '#xcrun' do
      xcrun = core_sim.xcrun
      expect(xcrun).to be_a_kind_of(RunLoop::Xcrun)
      expect(core_sim.xcrun).to be == xcrun
      expect(core_sim.instance_variable_get(:@xcrun)).to be == xcrun
    end
  end

  let(:app) { RunLoop::App.new(Resources.shared.cal_app_bundle_path) }
  let(:device) { RunLoop::Device.new('iPhone 5s', '8.1',
                                     'A08334BE-77BD-4A2F-BA25-A0E8251A1A80') }
  let(:core_sim) { RunLoop::CoreSimulator.new(device, app) }

  describe 'Mocked file system' do

    describe '#sdk_gte_8?' do
      it 'returns true' do
        expect(core_sim.send(:sdk_gte_8?)).to be_truthy
      end

      it 'returns false' do
        expect(device).to receive(:version).and_return RunLoop::Version.new('7.1')

        expect(core_sim.send(:sdk_gte_8?)).to be_falsey
      end
    end

    it '#device_data_dir' do
      base = RunLoop::LifeCycle::CoreSimulator::CORE_SIMULATOR_DEVICE_DIR
      expected = File.join(base, device.udid, 'data')

      actual = core_sim.send(:device_data_dir)
      expect(actual).to be == expected
      expect(core_sim.instance_variable_get(:@device_data_dir)).to be == expected
    end

    describe '#device_applications_dir' do
      before do
        expect(core_sim).to receive(:device_data_dir).and_return '/'
      end

      it 'iOS >= 8.0' do
        expected = '/Containers/Bundle/Application'

        expect(core_sim.send(:device_applications_dir)).to be == expected
        expect(core_sim.instance_variable_get(:@device_app_dir)).to be == expected
      end

      it 'iOS < 8.0' do
        expect(device).to receive(:version).and_return RunLoop::Version.new('7.1')

        expected = '/Applications'

        expect(core_sim.send(:device_applications_dir)).to be == expected
        expect(core_sim.instance_variable_get(:@device_app_dir)).to be == expected
      end
    end

    describe '#app_sandbox_dir' do
      it 'returns nil if there is no app bundle' do
        expect(core_sim).to receive(:installed_app_bundle_dir).and_return nil

        expect(core_sim.send(:app_sandbox_dir)).to be == nil
      end

      describe 'app is installed' do
        before do
          expect(core_sim).to receive(:installed_app_bundle_dir).and_return '/'
        end

        it 'iOS >= 8.0' do
          expect(core_sim).to receive(:app_sandbox_dir_sdk_gte_8).and_return 'match'

          expect(core_sim.send(:app_sandbox_dir)).to be == 'match'
        end

        it 'iOS < 8.0' do
          expect(device).to receive(:version).and_return RunLoop::Version.new('7.1')

          expect(core_sim.send(:app_sandbox_dir)).to be == '/'
        end
      end
    end

    describe '#app_library_dir' do
      it 'returns nil when app is not installed' do
        expect(core_sim).to receive(:app_sandbox_dir).and_return nil

        expect(core_sim.send(:app_library_dir)).to be == nil
      end

      it 'returns Library dir when app is installed' do
        expect(core_sim).to receive(:app_sandbox_dir).and_return '/'

        expect(core_sim.send(:app_library_dir)).to be == '/Library'
      end
    end

    describe '#app_library_preferences_dir' do
      it 'returns nil when app is not installed' do
        expect(core_sim).to receive(:app_library_dir).and_return nil

        expect(core_sim.send(:app_library_preferences_dir)).to be == nil
      end

      it 'returns Library/Preferences dir when app is installed' do
        expect(core_sim).to receive(:app_library_dir).and_return '/'

        expect(core_sim.send(:app_library_preferences_dir)).to be == '/Preferences'
      end
    end

    describe '#app_documents_dir' do
      it 'returns nil when app is not installed' do
        expect(core_sim).to receive(:app_sandbox_dir).and_return nil

        expect(core_sim.send(:app_documents_dir)).to be == nil
      end

      it 'returns Documents dir when app is installed' do
        expect(core_sim).to receive(:app_sandbox_dir).and_return '/'

        expect(core_sim.send(:app_documents_dir)).to be == '/Documents'
      end
    end

    describe '#app_tmp_dir' do
      it 'returns nil when app is not installed' do
        expect(core_sim).to receive(:app_sandbox_dir).and_return nil

        expect(core_sim.send(:app_tmp_dir)).to be == nil
      end

      it 'returns tmp dir when app is installed' do
        expect(core_sim).to receive(:app_sandbox_dir).and_return '/'

        expect(core_sim.send(:app_tmp_dir)).to be == '/tmp'
      end
    end

    it '#device_library_cache_dir' do
      expect(core_sim).to receive(:device_data_dir).and_return('/')

      expect(core_sim.send(:device_caches_dir)).to be == '/Library/Caches'
    end

    describe '#app_is_installed?' do
      it 'returns false when app is not installed' do
        expect(core_sim).to receive(:installed_app_bundle_dir).and_return nil

        expect(core_sim.app_is_installed?).to be == false
      end

      it 'returns true when app is installed' do
        expect(core_sim).to receive(:installed_app_bundle_dir).and_return '/'

        expect(core_sim.app_is_installed?).to be == true
      end
    end
  end
end
