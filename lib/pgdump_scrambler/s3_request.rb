# frozen_string_literal: true

require 'uri'
require 'digest'
require 'openssl'

module PgdumpScrambler
  class S3Request
    def initialize(s3_path:, verb:, region:, bucket:, access_key_id:, secret_key:, time: nil) # rubocop:disable Metrics/ParameterLists
      @s3_path = s3_path.start_with?('/') ? s3_path : "/#{s3_path}"
      @verb = verb
      @time = time || Time.now.utc
      @region = region
      @bucket = bucket
      @access_key_id = access_key_id
      @secret_key = secret_key
    end

    def canonical_request
      [
        @verb,
        URI.encode(@s3_path), # rubocop:disable Lint/UriEscapeUnescape
        canonical_query_string,
        "host:#{@bucket}.s3.amazonaws.com\n", # canonical headers
        'host', # signed headers
        'UNSIGNED-PAYLOAD'
      ].join("\n")
    end

    def signature_key
      date_key = hmac_sha256("AWS4#{@secret_key}", iso_date)
      date_region_key = hmac_sha256(date_key, @region)
      date_region_service_key = hmac_sha256(date_region_key, 's3')
      hmac_sha256(date_region_service_key, 'aws4_request')
    end

    def signature
      hmac_sha256_hex(signature_key, string_to_sign)
    end

    def url
      File.join("https://#{@bucket}.s3.amazonaws.com/",
                "#{@s3_path}?#{canonical_query_string}&X-Amz-Signature=#{signature}")
    end

    private

    def iso_time
      @time.strftime('%Y%m%dT%H%M%SZ')
    end

    def iso_date
      @time.strftime('%Y%m%d')
    end

    def hmac_sha256(key, message)
      OpenSSL::HMAC.digest(OpenSSL::Digest.new('SHA256'), key, message)
    end

    def hmac_sha256_hex(key, message)
      OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('SHA256'), key, message)
    end

    def canonical_query_string
      # rubocop:disable Layout/LineLength
      "X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=#{@access_key_id}%2F#{iso_date}%2F#{@region}%2Fs3%2Faws4_request&X-Amz-Date=#{iso_time}&X-Amz-Expires=86400&X-Amz-SignedHeaders=host"
      # rubocop:enable Layout/LineLength
    end

    def string_to_sign
      [
        'AWS4-HMAC-SHA256',
        iso_time,
        "#{iso_date}/#{@region}/s3/aws4_request",
        Digest::SHA256.hexdigest(canonical_request)
      ].join("\n")
    end
  end
end

if $PROGRAM_NAME == __FILE__
  # https://docs.aws.amazon.com/AmazonS3/latest/API/sigv4-query-string-auth.html
  require 'minitest/autorun'
  class TestS3Request < Minitest::Test
    def setup
      @s3_request = PgdumpScrambler::S3Request.new(
        verb: 'GET',
        s3_path: '/test.txt',
        region: 'us-east-1',
        bucket: 'examplebucket',
        access_key_id: 'AKIAIOSFODNN7EXAMPLE',
        secret_key: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
        time: Time.utc(2013, 5, 24, 0, 0, 0)
      )
    end

    def test_canonical_request
      assert_equal <<~END_OF_REQUEST.chomp, @s3_request.canonical_request
        GET
        /test.txt
        X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAIOSFODNN7EXAMPLE%2F20130524%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20130524T000000Z&X-Amz-Expires=86400&X-Amz-SignedHeaders=host
        host:examplebucket.s3.amazonaws.com

        host
        UNSIGNED-PAYLOAD
      END_OF_REQUEST
    end

    def test_signature
      assert_equal 'aeeed9bbccd4d02ee5c0109b86d86835f995330da4c265957d157751f604d404', @s3_request.signature
    end

    def test_url
      exected_url = 'https://examplebucket.s3.amazonaws.com/test.txt?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAIOSFODNN7EXAMPLE%2F20130524%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20130524T000000Z&X-Amz-Expires=86400&X-Amz-SignedHeaders=host&X-Amz-Signature=aeeed9bbccd4d02ee5c0109b86d86835f995330da4c265957d157751f604d404'
      assert_equal exected_url, @s3_request.url
    end
  end
end
