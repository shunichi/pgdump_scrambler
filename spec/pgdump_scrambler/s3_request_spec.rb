# frozen_string_literal: true

RSpec.describe PgdumpScrambler::S3Request do
  let(:s3_request) do
    PgdumpScrambler::S3Request.new(
      verb: 'GET',
      s3_path: '/test.txt',
      region: 'us-east-1',
      bucket: 'examplebucket',
      access_key_id: 'AKIAIOSFODNN7EXAMPLE',
      secret_key: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
      time: Time.utc(2013, 5, 24, 0, 0, 0)
    )
  end

  # https://docs.aws.amazon.com/AmazonS3/latest/API/sigv4-query-string-auth.html
  it 'generates valid signature and url' do
    expected = <<~END_OF_REQUEST.chomp
      GET
      /test.txt
      X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAIOSFODNN7EXAMPLE%2F20130524%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20130524T000000Z&X-Amz-Expires=86400&X-Amz-SignedHeaders=host
      host:examplebucket.s3.amazonaws.com

      host
      UNSIGNED-PAYLOAD
    END_OF_REQUEST
    expect(s3_request.canonical_request).to eq expected
    expect(s3_request.signature).to eq 'aeeed9bbccd4d02ee5c0109b86d86835f995330da4c265957d157751f604d404'
    exected_url = 'https://examplebucket.s3.amazonaws.com/test.txt?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAIOSFODNN7EXAMPLE%2F20130524%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20130524T000000Z&X-Amz-Expires=86400&X-Amz-SignedHeaders=host&X-Amz-Signature=aeeed9bbccd4d02ee5c0109b86d86835f995330da4c265957d157751f604d404'
    expect(s3_request.url).to eq exected_url
  end
end
