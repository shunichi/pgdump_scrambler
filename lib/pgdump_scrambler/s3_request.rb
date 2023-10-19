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
        self.class.uri_encode(@s3_path),
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
      encoded_path = self.class.uri_encode(@s3_path)
      File.join("https://#{@bucket}.s3.amazonaws.com/",
        "#{encoded_path}?#{canonical_query_string}&X-Amz-Signature=#{signature}")
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

    class << self
      # https://docs.aws.amazon.com/AmazonS3/latest/API/sigv4-query-string-auth.html
      # * URI encode every byte except the unreserved characters: 'A'-'Z', 'a'-'z', '0'-'9', '-', '.', '_', and '~'.
      # * The space character is a reserved character and must be encoded as "%20" (and not as "+").
      # * Each URI encoded byte is formed by a '%' and the two-digit hexadecimal value of the byte.
      # * Letters in the hexadecimal value must be uppercase, for example "%1A".
      # * Encode the forward slash character, '/', everywhere except in the object key name.
      #   For example, if the object key name is photos/Jan/sample.jpg,
      #   the forward slash in the key name is not encoded.
      def uri_encode(str)
        str.gsub(%r{[^A-Za-z0-9\-._~/]}) do
          us = Regexp.last_match(0)
          tmp = +''
          us.each_byte do |uc|
            tmp << sprintf('%%%02X', uc)
          end
          tmp
        end.force_encoding(Encoding::US_ASCII)
      end
    end
  end
end
