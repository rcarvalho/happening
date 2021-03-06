require 'uri'
require 'cgi'

module Happening
  module S3
    class Bucket
      include Utils
    
      REQUIRED_FIELDS = [:server]
      VALID_HEADERS = ['Cache-Control', 'Content-Disposition', 'Content-Encoding', 'Content-Length', 'Content-MD5', 'Content-Type', 'Expect', 'Expires']
    
      attr_accessor :bucket, :options

      def initialize(bucket, options = {})
        @marker = options.delete(:marker)
        @options = {
          :timeout => 10,
          :server => 's3.amazonaws.com',
          :protocol => 'https',
          :aws_access_key_id => nil,
          :aws_secret_access_key => nil,
          :retry_count => 4,
          :permissions => 'private',
          :ssl => Happening::S3.ssl_options
        }.update(symbolize_keys(options))
        assert_valid_keys(options, :timeout, :server, :protocol, :aws_access_key_id, :aws_secret_access_key, :retry_count, :permissions, :ssl)
        @bucket = bucket.to_s
      
        validate
      end
    
      def get(request_options = {}, &blk)
        headers = needs_to_sign? ? aws.sign("GET", path) : {}
        request_options[:on_success] = blk if blk
        request_options.update(:headers => headers)
        Happening::S3::Request.new(:get, url, {:ssl => options[:ssl]}.update(request_options)).execute
      end
          
      def url
        marker = @marker.nil? ? nil : "marker=#{CGI.escape(@marker)}"
        URI::Generic.new(options[:protocol], nil, server, port, nil, path(!dns_bucket?), nil, marker, nil).to_s
      end
      
      def server
        dns_bucket? ? "#{bucket}.#{options[:server]}" : options[:server]
      end
      
      def path(with_bucket=true)
        with_bucket ? "/#{bucket}/" : "/"
      end
    
    protected
        
      def needs_to_sign?
        present?(options[:aws_access_key_id])
      end
    
      def dns_bucket?
        # http://docs.amazonwebservices.com/AmazonS3/2006-03-01/index.html?BucketRestrictions.html
        return false unless (3..63) === bucket.size
        bucket.split('.').each do |component|
          return false unless component[/^[a-z0-9]([a-z0-9-]*[a-z0-9])?$/]
        end
        true
      end
    
      def port
        (options[:protocol].to_s == 'https') ? 443 : 80
      end
    
      def validate
        raise ArgumentError, "need a bucket name" unless present?(bucket)
      
        REQUIRED_FIELDS.each do |field|
          raise ArgumentError, "need field #{field}" unless present?(options[field])
        end
      
        raise ArgumentError, "unknown protocoll #{options[:protocol]}" unless ['http', 'https'].include?(options[:protocol])
      end
      
      def aws
        @aws ||= Happening::AWS.new(options[:aws_access_key_id], options[:aws_secret_access_key])
      end
      
    end
  end
end
