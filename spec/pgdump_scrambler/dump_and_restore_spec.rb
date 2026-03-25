# frozen_string_literal: true

require 'fileutils'
require 'yaml'

RSpec.describe 'Dump and restore' do # rubocop:disable RSpec/MultipleMemoizedHelpers
  let(:tmpdir) { 'tmp/dump_test' }
  let(:yaml) do
    YAML.safe_load_file(
      'config/database.yml',
      permitted_classes: [],
      permitted_symbols: [],
      aliases: true
    )
  end
  let(:database) { yaml.dig('test', 'database') || 'pgdump_scrambler_test' }
  let(:host) { yaml.dig('test', 'host') || 'localhost' }
  let(:port) { yaml.dig('test', 'port') || 5432 }
  let(:username) { yaml.dig('test', 'username') || 'postgres' }
  let(:password) { yaml.dig('test', 'password') || 'postgres' }
  let(:env) { { 'PGPASSWORD' => password.to_s } }
  let(:db_config) do
    {
      'database' => database,
      'host' => host,
      'port' => port.to_s,
      'username' => username,
      'password' => password.to_s,
    }
  end
  let(:create_table_sql) do
    <<~SQL
      CREATE TABLE public.users (
          id bigint NOT NULL,
          name character varying DEFAULT ''::character varying NOT NULL,
          email character varying DEFAULT ''::character varying NOT NULL
      );
    SQL
  end
  let(:insert_sql) do
    <<~SQL
      INSERT INTO public.users (id, name, email) VALUES
        (1, 'Alice', 'alice@example.com'),
        (2, 'Bob', 'bob@example.com');
    SQL
  end
  let(:restore_database) { "#{database}_restore" }

  before do
    system(env, "dropdb --if-exists -h #{host} -p #{port} -U #{username} #{database} 2> /dev/null", exception: true)
    system(env, "createdb -h #{host} -p #{port} -U #{username} #{database}", exception: true)
    system(env, %(psql --quiet -h #{host} -p #{port} -U #{username} -d #{database} -c "#{create_table_sql}"),
      exception: true)
    system(env, %(psql --quiet -h #{host} -p #{port} -U #{username} -d #{database} -c "#{insert_sql}"),
      exception: true)
    FileUtils.rm_rf(tmpdir)
    FileUtils.mkdir_p(tmpdir)
  end

  after do
    system(env, "dropdb --if-exists -h #{host} -p #{port} -U #{username} #{database} 2> /dev/null", exception: true)
    system(env, "dropdb --if-exists -h #{host} -p #{port} -U #{username} #{restore_database} 2> /dev/null",
      exception: true)
    FileUtils.rm_rf(tmpdir)
  end

  def restore_dump(dump_path, decompress_command)
    system(env, "createdb -h #{host} -p #{port} -U #{username} #{restore_database}", exception: true)
    system(env,
      "#{decompress_command} #{dump_path} " \
      "| psql --quiet -h #{host} -p #{port} -U #{username} -d #{restore_database} 2> /dev/null",
      exception: true)
  end

  def query_users
    sql = 'SELECT id, name, email FROM users ORDER BY id'
    cmd = "psql -t -A -F',' -h #{host} -p #{port} -U #{username} " \
          "-d #{restore_database} -c \"#{sql}\""
    output = `PGPASSWORD=#{password} #{cmd}`
    output.strip.split("\n").map { |line| line.split(',', 3) }
  end

  it 'dumps and restores with gzip, scrambling specified columns' do
    dump_path = "#{tmpdir}/scrambled.dump.gz"
    config_yaml = <<~YAML
      ---
      dump_path: #{dump_path}
      tables:
        users:
          email: email
          name: sbytes
    YAML
    config = PgdumpScrambler::Config.read(StringIO.new(config_yaml))
    dumper = PgdumpScrambler::Dumper.new(config, db_config)
    dumper.run

    expect(File.exist?(dump_path)).to be true
    expect(File.size(dump_path)).to be > 0

    restore_dump(dump_path, 'gunzip -c')
    rows = query_users

    expect(rows.size).to eq 2
    rows.each do |row|
      id, name, email_val = row
      expect(id).to match(/\A[12]\z/)
      # name and email should be scrambled (different from originals)
      expect(name).not_to eq('Alice')
      expect(name).not_to eq('Bob')
      expect(email_val).not_to eq('alice@example.com')
      expect(email_val).not_to eq('bob@example.com')
    end
  end

  it 'dumps and restores with zstd compression' do
    dump_path = "#{tmpdir}/scrambled.dump.zst"
    config_yaml = <<~YAML
      ---
      dump_path: #{dump_path}
      compression:
        method: zstd
        level: 3
      tables:
        users:
          email: email
          name: sbytes
    YAML
    config = PgdumpScrambler::Config.read(StringIO.new(config_yaml))
    dumper = PgdumpScrambler::Dumper.new(config, db_config)
    dumper.run

    expect(File.exist?(dump_path)).to be true
    expect(File.size(dump_path)).to be > 0

    restore_dump(dump_path, 'zstd -d -c')
    rows = query_users

    expect(rows.size).to eq 2
    rows.each do |row|
      id, name, email_val = row
      expect(id).to match(/\A[12]\z/)
      expect(name).not_to eq('Alice')
      expect(name).not_to eq('Bob')
      expect(email_val).not_to eq('alice@example.com')
      expect(email_val).not_to eq('bob@example.com')
    end
  end

  it 'preserves nop columns without scrambling' do
    dump_path = "#{tmpdir}/nop_test.dump.gz"
    config_yaml = <<~YAML
      ---
      dump_path: #{dump_path}
      tables:
        users:
          email: nop
          name: nop
    YAML
    config = PgdumpScrambler::Config.read(StringIO.new(config_yaml))
    dumper = PgdumpScrambler::Dumper.new(config, db_config)
    dumper.run

    restore_dump(dump_path, 'gunzip -c')
    rows = query_users

    expect(rows.size).to eq 2
    expect(rows).to contain_exactly(
      ['1', 'Alice', 'alice@example.com'],
      ['2', 'Bob', 'bob@example.com']
    )
  end
end
