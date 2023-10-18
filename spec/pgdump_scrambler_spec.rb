# frozen_string_literal: true
RSpec.describe PgdumpScrambler do
  it 'reads file' do
    yaml = <<~YAML
    ---
    dump_path: sample.dump
    tables:
      posts:
        content: sbytes
        title: sbytes
      users:
        email: email
        name: sbytes
    YAML
    path = File.expand_path('../fixtures/sample.yml',  __FILE__)
    config = PgdumpScrambler::Config.read_file(path)
    io = StringIO.new
    config.write(io)
    expect(io.string).to eq yaml
  end

  it 'reads and write yaml' do
    yaml = <<~YAML
    ---
    dump_path: scrambled.dump
    tables:
      posts:
        content: sbytes
        title: sbytes
      users:
        email: email
        name: sbytes
    YAML
    config = PgdumpScrambler::Config.read(StringIO.new(yaml))
    io = StringIO.new
    config.write(io)
    expect(io.string).to eq yaml
  end

  it 'merges configs' do
    yaml1 = <<~YAML
    ---
    dump_path: scrambled.dump
    tables:
      posts:
        content: sbytes
        created_at: nop
        title: nop
      users:
        email: email
        name: sbytes
    YAML

    yaml2 = <<~YAML
    ---
    dump_path: scrambled.dump
    tables:
      posts:
        author: nop
        content: unspecified
        title: sbytes
      users:
        email: nop
        name: unspecified
    YAML

    expected = <<~YAML
    ---
    dump_path: scrambled.dump
    tables:
      posts:
        author: nop
        content: sbytes
        created_at: nop
        title: nop
      users:
        email: email
        name: sbytes
    YAML

    config1 = PgdumpScrambler::Config.read(StringIO.new(yaml1))
    config2 = PgdumpScrambler::Config.read(StringIO.new(yaml2))
    merged = config1.update_with(config2)
    io = StringIO.new
    merged.write(io)
    expect(io.string).to eq expected
  end

  it 'creates obfuscator options' do
    yaml = <<~YAML
    ---
    dump_path: scrambled.dump
    tables:
      posts:
        author: nop
        content: sbytes
        title: sbytes
      users:
        email: uemail
        name: unspecified
        disabled: const(f)
    YAML
    config = PgdumpScrambler::Config.read(StringIO.new(yaml))
    expect(config.obfuscator_options).to eq "-c posts:content:sbytes -c posts:title:sbytes -c users:disabled:const\\(f\\) -c users:email:uemail"
  end

  it 'pgdump options' do
    yaml = <<~YAML
    ---
    dump_path: scrambled.dump
    pgdump_args: '-xc'
    tables:
      posts:
        author: nop
        content: sbytes
        title: sbytes
      users:
        email: uemail
        name: unspecified
    YAML
    config = PgdumpScrambler::Config.read(StringIO.new(yaml))
    expect(config.pgdump_args).to eq '-xc'
  end
end
