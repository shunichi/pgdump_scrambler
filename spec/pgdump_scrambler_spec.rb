# frozen_string_literal: true
RSpec.describe PgdumpScrambler do
  it 'reads file' do
    yaml = <<~YAML
    ---
    posts:
      content: sbytes
      title: sbytes
    users:
      email: email
      name: sbytes
    YAML
    path = File.expand_path('../fixtures/sample.yml',  __FILE__)
    table_set = PgdumpScrambler::TableSet.read_file(path)
    io = StringIO.new
    table_set.write(io)
    expect(io.string).to eq yaml
  end

  it 'reads and write yaml' do
    yaml = <<~YAML
    ---
    posts:
      content: sbytes
      title: sbytes
    users:
      email: email
      name: sbytes
    YAML
    table_set = PgdumpScrambler::TableSet.read(StringIO.new(yaml))
    io = StringIO.new
    table_set.write(io)
    expect(io.string).to eq yaml
  end

  it 'merges table sets' do
    yaml1 = <<~YAML
    ---
    posts:
      content: unspecified
      created_at: nop
      title: nop
    users:
      email: nop
      name: unspecified
    YAML
    
    yaml2 = <<~YAML
    ---
    posts:
      author: nop
      content: sbytes
      title: sbytes
    users:
      email: email
      name: sbytes
    YAML

    expected = <<~YAML
    ---
    posts:
      author: nop
      content: sbytes
      created_at: nop
      title: sbytes
    users:
      email: email
      name: sbytes
    YAML

    table_set1 = PgdumpScrambler::TableSet.read(StringIO.new(yaml1))
    table_set2 = PgdumpScrambler::TableSet.read(StringIO.new(yaml2))
    merged = table_set1.merge(table_set2)
    io = StringIO.new
    merged.write(io)
    expect(io.string).to eq expected
  end

  it 'creates obfuscator options' do
    yaml = <<~YAML
    ---
    posts:
      author: nop
      content: sbytes
      title: sbytes
    users:
      email: uemail
      name: unspecified
    YAML
    table_set = PgdumpScrambler::TableSet.read(StringIO.new(yaml))
    expect(table_set.obfuscator_options).to eq '-c posts:content:sbytes -c posts:title:sbytes -c users:email:uemail'
  end
end
