# PgdumpScrambler

Generate scrambled potgresql dump for rails application.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pgdump_scrambler'
```

And then execute:

    $ bundle

## Usage

Genarate config file.

```
bundle exec rake pgdump_scrambler:config_from_db
```

Fix column scramble functions in config/pgdump_scrambler.yml

from:

```
tables:
  users:
    email: unspecified
    name: unspecified
    age: unspecified
```

to:

```
tables:
  users:
    email: uemail
    name: sbytes
    age: nop
```

Dump the scrambled database.

```
bundle exec rake pgdump_scrambler:dump
```

## scramble functions

- `bytes` random bytes (each byte is one of `0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ+-_`)
- `sbytes` random bytes (each byte is one of `0123456789abcdefghijklmnopqrstuvwxyz`)
- `digits` random digits
- `email` random email address
- `uemail` random unique email address
- `inet` random ip address
- `json` string value to random bytes, number value to random digits, keep data structure and key names
- `nullify` NULL
- `empty` empty string
- `const[VALUE]` constant value
- `nop` untouched

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/shunichi/pgdump_scrambler.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
