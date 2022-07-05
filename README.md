# ![Logo](logo.png) fastly2git

Create a git repository from Fastly service generated VCL.

[![Build
Status](https://travis-ci.org/fastly/fastly2git.svg?branch=master)](https://travis-ci.org/fastly/fastly2git/)

# Screencast

![Screencast](fastly2git.gif)

# Synopsis

```
Usage: fastly2git [options]

Create a git repository from Fastly service generated VCL.

Options
    -a, --apikey APIKEY              Fastly API key
    -s, --serviceid SERVICEID        Fastly service ID
    -d, --directory DIRECTORY        Directory
    -v, --verbose                    Run verbosely
    -h, --help                       Show this message
```

fastly2git will even work incrementally, pulling all new locked versions.

# Installation
Clone the repo and then run the following command while in fastly2git
directory:
```
bundle install # to install dependencies
bundle exec rake test # to run tests
bundle exec rake install # to install the gem
bundle exec rake -T # to see the list of other available rake tasks
```

# Example
```
$ fastly2git -v --apikey XXX --serviceid YYY --directory /tmp/vcl
Service Name: uuid.astray.com
Importing version...
Importing version...
Importing version...
Importing version...
Importing version...
Importing version...
Importing version...
Importing version...
Importing version...
Importing version...
.... done! Imported to /tmp/vcl
```

# Inspect

Then change to the new directory:

```
$ cd /tmp/vcl
```

Inspect the changes version by version:

```
$ git log -p
...
commit d150836cae065e4e9fbc42879c6b9dd7dfc0be0d
Author: Fastly User <user@fastly.com>
Date:   Tue Oct 20 10:05:52 2015 +0100

    Version 9

diff --git a/generated.vcl b/generated.vcl
index 9b183a1..c48023e 100644
--- a/generated.vcl
+++ b/generated.vcl
@@ -32,6 +32,7 @@ sub vcl_recv {


 #--FASTLY RECV CODE END
+    set req.http.vcl = req.vcl;

     if (req.request != "HEAD" && req.request != "GET" && req.request !=
"FASTLYPURGE") {
       return(pass);
@@ -289,6 +290,7 @@ sub vcl_error {
     set obj.response = "OK";
     synthetic "X-Varnish: " req.http.X-Varnish {"
 "} "server.identity: " server.identity {"
+"} "req.vcl: " req.http.vcl {"
 "} "req.service_id: " req.service_id;
     return(deliver);
   }
...
```

Or annotate the VCL by version:

```
$ git annotate --line-porcelain generated.vcl | perl -lne 'if ($_ =~
s/^\t//) { printf "%-10.10s %s\n", $s, $_} else { ($k, $v) = split(" ",
$_,2); $s = $v if $k eq "summary" }'
...
Version 2    if (obj.status == 900) {
Version 2      set obj.status = 200;
Version 2      set obj.response = "OK";
Version 6      synthetic "X-Varnish: " req.http.X-Varnish {"
Version 8  "} "server.identity: " server.identity {"
Version 9  "} "req.vcl: " req.http.vcl {"
Version 8  "} "req.service_id: " req.service_id;
Version 2      return(deliver);
Version 2    }
...
```

## License

The gem is available as open source under the terms of the [MIT
License](http://opensource.org/licenses/MIT).

# Future

Is this useful? Let me know! Léon Brocard <<lbrocard@fastly.com>>
