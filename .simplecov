# frozen_string_literal: true

require "simplecov-lcov"

SimpleCov::Formatter::LcovFormatter.config.report_with_single_file = true
SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
  SimpleCov::Formatter::LcovFormatter,
  SimpleCov::Formatter::HTMLFormatter,
])

SimpleCov.start do
  add_filter "/spec/"
  add_filter "/vendor/bundle/"
end
