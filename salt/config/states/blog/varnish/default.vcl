# This is a basic vcl.conf file for varnish.
# Modifying this file should be where you store your modifications to
# varnish. Settnigs here will override defaults.
vcl 4.0;

backend default {
 .host = "127.0.0.1";
 .port = "8080";
}

acl purge {
 "localhost";
 "127.0.0.1";
}

sub vcl_recv {
 call device_detection;
 if (req.restarts == 0) {
  if (req.http.X-Forwarded-For) {
   set req.http.X-Forwarded-For = req.http.X-Forwarded-For + ", " + client.ip;
  } else {
   set req.http.X-Forwarded-For = client.ip;
  }
 }
 if (req.method == "PURGE") {
  if (!client.ip ~ purge) {
   return (synth(504,"Not allowed."));
  }
  return (hash);
 }
 # Only deal with "normal" types
 if (req.method != "GET" &&
   req.method != "HEAD" &&
   req.method != "PUT" &&
   req.method != "POST" &&
   req.method != "TRACE" &&
   req.method != "OPTIONS" &&
   req.method != "PATCH" &&
   req.method != "DELETE") {
  /* Non-RFC2616 or CONNECT which is weird. */
  return (pipe);
 }

 if (req.method != "GET" && req.method != "HEAD") {
  # We only deal with GET and HEAD by default
  return (pass);
 }

 # Normalize Accept-Encoding header
 # straight from the manual: https://www.varnish-cache.org/docs/3.0/tutorial/vary.html
 if (req.http.Accept-Encoding) {
  if (req.url ~ "\.(jpg|png|gif|gz|tgz|bz2|tbz|mp3|ogg)$") {
   # No point in compressing these
   unset req.http.Accept-Encoding;
  } elsif (req.http.Accept-Encoding ~ "gzip") {
   set req.http.Accept-Encoding = "gzip";
  } elsif (req.http.Accept-Encoding ~ "deflate") {
   set req.http.Accept-Encoding = "deflate";
  } else {
   # unkown algorithm
   unset req.http.Accept-Encoding;
  }
 }

 # Remove all cookies for static files
 # A valid discussion could be held on this line: do you really need to cache static files that don't cause load? Only if you have memory left.
 # Sure, there's disk I/O, but chances are your OS will already have these files in their buffers (thus memory).
 # Before you blindly enable this, have a read here: http://mattiasgeniar.be/2012/11/28/stop-caching-static-files/
 if (req.url ~ "^[^?]*\.(bmp|bz2|css|doc|eot|flv|gif|gz|ico|jpeg|jpg|js|less|mp[34]|pdf|png|rar|rtf|swf|tar|tgz|txt|wav|woff|xml|zip)(\?.*)?$") {
  unset req.http.cookie;
  return (hash);
 }

 if(req.http.X-Requested-With == "XMLHttpRequest" || req.url ~ "nocache" || req.url ~ "(control.php|wp-comments-post.php|wp-login.php|bb-login.php|bb-reset-password.php|register.php|xmlrpc.php)") {
  return (pass);
 }

 if (!(req.url ~ "wp-(login|admin)") &&
     !(req.url ~ "rss")) {
  unset req.http.cookie;
 }

 if (req.http.Authorization || req.http.Cookie) {
  # Not cacheable by default
  return (pass);
 }
 return(hash);
}

sub vcl_pipe {
 set bereq.http.Connection = "close";
 return (pipe);
}

sub vcl_hit {
 if (req.method == "PURGE")
  {ban(req.url);
   return (synth(200, "Purged"));}

 if (!(obj.ttl > 0s)) {
  return(pass);
 }
}

sub vcl_miss {
 if (req.method == "PURGE") {
  return (synth(200, "Not in cache."));
 }
}

sub vcl_backend_response {
 if (!beresp.http.Vary) { # no Vary at all
  set beresp.http.Vary = "X-Mobile";
 } elseif (beresp.http.Vary !~ "X-Mobile") { # add to existing Vary
  set beresp.http.Vary = beresp.http.Vary + ", X-Mobile";
 }
 # If the request to the backend returns a code is 5xx, restart the loop
 # If the number of restarts reaches the value of the parameter max_restarts,
 # the request will be error'ed. max_restarts defaults to 4. This prevents
 # an eternal loop in the event that, e.g., the object does not exist at all.
 if (beresp.status >= 500 && beresp.status <= 599){
  return(retry);
 }

 # Enable cache for all static files
 # The same argument as the static caches from above: monitor your cache size, if you get data nuked out of it, consider giving up the static file cache.
 # Before you blindly enable this, have a read here: http://mattiasgeniar.be/2012/11/28/stop-caching-static-files/
 if (bereq.url ~ "^[^?]*\.(bmp|bz2|css|doc|eot|flv|gif|gz|ico|jpeg|jpg|js|less|mp[34]|pdf|png|rar|rtf|swf|tar|tgz|txt|wav|woff|xml|zip)(\?.*)?$") {
  unset beresp.http.set-cookie;
 }

 # Sometimes, a 301 or 302 redirect formed via Apache's mod_rewrite can mess with the HTTP port that is being passed along.
 # This often happens with simple rewrite rules in a scenario where Varnish runs on :80 and Apache on :8080 on the same box.
 # A redirect can then often redirect the end-user to a URL on :8080, where it should be :80.
 # This may need finetuning on your setup.
 #
 # To prevent accidental replace, we only filter the 301/302 redirects for now.
 if (beresp.status == 301 || beresp.status == 302) {
  set beresp.http.Location = regsub(beresp.http.Location, ":[0-9]+", "");
 }

 if (!(bereq.url ~ "wp-(login|admin)") &&
     !(bereq.url ~ "rss")) {
  unset beresp.http.set-cookie;
 }
 # Set 2min cache if unset for static files
 if (beresp.ttl <= 0s || beresp.http.Set-Cookie || beresp.http.Vary == "*") {
  set beresp.ttl = 120s;
  set beresp.uncacheable = true;
 }
 return(deliver);
}

# The routine when we deliver the HTTP request to the user
# Last chance to modify headers that are sent to the client
sub vcl_deliver {
 if (obj.hits > 0) {
  set resp.http.X-Cache = "cached";
 } else {
  set resp.http.x-Cache = "uncached";
 }

 # Remove some headers: PHP version
 unset resp.http.X-Powered-By;

 # Remove some headers: Apache version & OS
 unset resp.http.Server;
 unset resp.http.X-Varnish;
 unset resp.http.Via;
 unset resp.http.Link;

 return (deliver);
}

sub vcl_init {
 return (ok);
}

sub vcl_fini {
 return (ok);
}

sub device_detection {

 if (req.http.User-Agent ~ "Android"){
  set req.http.X-Mobile = "yes";
 }
 if (req.http.User-Agent ~ "iPhone"){
  set req.http.X-Mobile = "yes";
 }
 if (req.http.User-Agent ~ "iPhone OS 2"){
  set req.http.X-Mobile = "yes";
 }
 if (req.http.User-Agent ~ "Series60"){
  set req.http.X-Mobile = "yes";
 }
 if (req.http.User-Agent ~ "webOS"){
  set req.http.X-Mobile = "yes";
 }
 if (req.http.User-Agent ~ "Opera Mini"){
  set req.http.X-Mobile = "yes";
 }
 if (req.http.User-Agent ~ "Opera Mobi"){
  set req.http.X-Mobile = "yes";
 }
 if (req.http.User-Agent ~ "Kindle/1.0"){
  set req.http.X-Mobile = "yes";
 }
 if (req.http.User-Agent ~ "Kindle/2.0"){
  set req.http.X-Mobile = "yes";
 }
 if (req.http.User-Agent ~ "NetFront"){
  set req.http.X-Mobile = "yes";
 }
 if (req.http.User-Agent ~ "SEMC-Browser"){
  set req.http.X-Mobile = "yes";
 }
 if (req.http.User-Agent ~ "PlayStation Portable"){
  set req.http.X-Mobile = "yes";
 }
 if (req.http.User-Agent ~ "PLAYSTATION 3"){
  set req.http.X-Mobile = "yes";
 }
 if (req.http.User-Agent ~ "BlackBerry"){
  set req.http.X-Mobile = "yes";
 }
}
