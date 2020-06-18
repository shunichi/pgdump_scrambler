# frozen_string_literal: true
namespace :pgdump_scrambler do
  default_config_path = ENV['SCRAMBLER_CONFIG_PATH'] || 'config/pgdump_scrambler.yml'

  desc 'create config from database'
  task config_from_db: :environment do
    config =
      if File.exist?(default_config_path)
        puts "#{default_config_path} found!\nmerge existing config with config from database"
        PgdumpScrambler::Config
          .read_file(default_config_path)
          .update_with(PgdumpScrambler::Config.from_db)
      else
        puts "craete config from database"
        PgdumpScrambler::Config.from_db
      end
    config.write_file(default_config_path)
  end

  desc 'check if new columns exist'
  task check: :environment do
    config = PgdumpScrambler::Config
      .read_file(default_config_path)
      .update_with(PgdumpScrambler::Config.from_db)
    unspecified_columns = config.unspecified_columns
    count = unspecified_columns.sum { |_, columns| columns.size }
    if count > 0
      unspecified_columns.each_key do |table_name|
        puts "#{table_name}:"
        unspecified_columns[table_name].each do |column_name|
          puts "  #{column_name}"
        end
      end
      puts "#{count} unspecified columns found!"
      exit 1
    else
      puts "No unspecified columns found."
    end
  end

  desc 'create scrambled dump'
  task dump: :environment do
    config = PgdumpScrambler::Config.read_file(default_config_path)
    PgdumpScrambler::Dumper.new(config).run
  end

  desc 'upload to s3'
  task s3_upload: :environment do
    config = PgdumpScrambler::Config.read_file(default_config_path)
    uploader = PgdumpScrambler::S3Uploader.new(
      s3_path: File.join(config.resolved_s3['prefix'], File::basename(config.dump_path)),
      local_path: config.dump_path,
      region: config.resolved_s3['region'],
      bucket: config.resolved_s3['bucket'],
      access_key_id: config.resolved_s3['access_key_id'],
      secret_key: config.resolved_s3['secret_key']
    )
    uploader.run
  end
end
