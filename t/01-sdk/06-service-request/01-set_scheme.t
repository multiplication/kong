use strict;
use warnings FATAL => 'all';
use Test::Nginx::Socket::Lua;
use File::Spec;
use t::Util;

$ENV{TEST_NGINX_HTML_DIR} ||= html_dir();
$ENV{TEST_NGINX_CERT_DIR} ||= File::Spec->catdir(server_root(), '..', 'certs');

plan tests => repeat_each() * (blocks() * 3);

run_tests();

__DATA__

=== TEST 1: service.request.set_scheme() errors if not a string
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local SDK = require "kong.sdk"
            local sdk = SDK.new()

            ngx.ctx.balancer_address = 8000

            local pok, err = pcall(sdk.service.request.set_scheme)
            ngx.say(err)
        }
    }
--- request
GET /t
--- response_body
scheme must be a string
--- no_error_log
[error]



=== TEST 2: service.request.set_scheme() errors if not a valid scheme
--- http_config eval: $t::Util::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local SDK = require "kong.sdk"
            local sdk = SDK.new()

            ngx.ctx.balancer_address = 8000

            local pok, err = pcall(sdk.service.request.set_scheme, "HTTP")
            ngx.say(err)
        }
    }
--- request
GET /t
--- response_body
invalid scheme: HTTP
--- no_error_log
[error]



=== TEST 3: service.request.set_scheme() sets the scheme to https
--- http_config eval
qq{
    $t::Util::HttpConfig

    server {
        listen unix:$ENV{TEST_NGINX_HTML_DIR}/nginx.sock ssl;
        ssl_certificate $ENV{TEST_NGINX_CERT_DIR}/test.crt;
        ssl_certificate_key $ENV{TEST_NGINX_CERT_DIR}/test.key;

        location /t {
            content_by_lua_block {
                ngx.say("scheme: ", ngx.var.scheme)
            }
        }
    }
}
--- config
    location = /t {

        set $upstream_scheme 'http';

        access_by_lua_block {
            local SDK = require "kong.sdk"
            local sdk = SDK.new()

            local ok, err = sdk.service.request.set_scheme("https")
        }

        proxy_pass $upstream_scheme://unix:$TEST_NGINX_HTML_DIR/nginx.sock;
    }
--- request
GET /t
--- response_body
scheme: https
--- no_error_log
[error]



=== TEST 4: service.request.set_scheme() sets the scheme to http
--- http_config eval
qq{
    $t::Util::HttpConfig

    server {
        listen unix:$ENV{TEST_NGINX_HTML_DIR}/nginx.sock;

        location /t {
            content_by_lua_block {
                ngx.say("scheme: ", ngx.var.scheme)
            }
        }
    }
}
--- config
    location = /t {

        set $upstream_scheme 'https';

        access_by_lua_block {
            local SDK = require "kong.sdk"
            local sdk = SDK.new()

            local ok, err = sdk.service.request.set_scheme("http")
        }

        proxy_pass http://unix:/$TEST_NGINX_HTML_DIR/nginx.sock;
    }
--- request
GET /t
--- response_body
scheme: http
--- no_error_log
[error]