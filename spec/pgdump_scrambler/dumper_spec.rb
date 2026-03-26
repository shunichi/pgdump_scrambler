# frozen_string_literal: true

RSpec.describe PgdumpScrambler::Dumper do
  let(:db_config) { { 'database' => 'testdb', 'username' => 'testuser', 'host' => 'localhost' } }

  def build_config(compression: nil)
    yaml = +''
    yaml << "---\n"
    yaml << "dump_path: scrambled.dump\n"
    if compression
      yaml << "compression:\n"
      yaml << "  method: #{compression['method']}\n"
      yaml << "  level: #{compression['level']}\n" if compression['level']
    end
    yaml << "tables:\n"
    yaml << "  users:\n"
    yaml << "    email: nop\n"
    PgdumpScrambler::Config.read(StringIO.new(yaml))
  end

  describe '#full_command' do
    it 'uses gzip by default' do
      config = build_config
      dumper = described_class.new(config, db_config)
      expect(dumper.full_command).to end_with('| gzip -c > scrambled.dump')
    end

    it 'uses gzip with level' do
      config = build_config(compression: { 'method' => 'gzip', 'level' => 6 })
      dumper = described_class.new(config, db_config)
      expect(dumper.full_command).to end_with('| gzip -c -6 > scrambled.dump')
    end

    it 'uses zstd without level' do
      config = build_config(compression: { 'method' => 'zstd' })
      dumper = described_class.new(config, db_config)
      expect(dumper.full_command).to end_with('| zstd -c > scrambled.dump')
    end

    it 'uses zstd with level < 20' do
      config = build_config(compression: { 'method' => 'zstd', 'level' => 3 })
      dumper = described_class.new(config, db_config)
      expect(dumper.full_command).to end_with('| zstd -c -3 > scrambled.dump')
    end

    it 'uses zstd with --ultra for level >= 20' do
      config = build_config(compression: { 'method' => 'zstd', 'level' => 22 })
      dumper = described_class.new(config, db_config)
      expect(dumper.full_command).to end_with('| zstd -c --ultra -22 > scrambled.dump')
    end

    it 'includes pg_dump with database options' do
      config = build_config
      dumper = described_class.new(config, db_config)
      command = dumper.full_command
      expect(command).to include('pg_dump')
      expect(command).to include('--username=testuser')
      expect(command).to include("--host='localhost'")
      expect(command).to include('testdb')
    end
  end
end
