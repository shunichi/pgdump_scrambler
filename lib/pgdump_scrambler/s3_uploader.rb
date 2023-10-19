# frozen_string_literal: true

require 'net/http'
require 'uri'
require_relative 's3_request'

module PgdumpScrambler
  class S3UploadError < StandardError
    attr_reader :response

    def initialize(response)
      @response = response
      super "S3 upload failed: #{response.body}"
    end
  end

  class S3Uploader
    def initialize(s3_path:, local_path:, region:, bucket:, access_key_id:, secret_key:) # rubocop:disable Metrics/ParameterLists
      raise 'missing access_key_id' if access_key_id.nil? || access_key_id.empty?
      raise 'missing secret_key' if secret_key.nil? || secret_key.empty?

      @s3_request = S3Request.new(
        s3_path: s3_path,
        verb: 'PUT',
        region: region,
        bucket: bucket,
        access_key_id: access_key_id,
        secret_key: secret_key
      )
      @local_path = local_path
    end

    def run
      uri = URI.parse(@s3_request.url)
      puts "Uploading #{@local_path} to #{uri.host}#{uri.path}"
      File.open(@local_path, 'r') do |io|
        uri_path = uri.path
        uri_path += "?#{uri.query}" if uri.query
        req = Net::HTTP::Put.new(uri_path)
        req.body_stream = io
        req.content_length = io.size
        req.content_type = 'application/octet-stream'
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        res = http.request(req)
        raise S3UploadError, res if res.code != '200'
      end
      puts 'Done.'
    end
  end
end
