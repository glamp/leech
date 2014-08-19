Pretty simple setup here.

    fs = require 'fs'
    path = require 'path'
    handlebars = require 'handlebars'
    shortid = require 'shortid'
    mkdirp = require 'mkdirp'
    walk = require './walk'

Set the name for your domain.

    module.exports = (url) ->
      DOMAIN = process.env["DOMAIN"] || "shortcake.com"
      # other configs go here...
      shortid.characters "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZç√"

This is our basic HTML template that we'll use for doing the redirect. It's just
going to send the user to another page as soon as it's loaded. There's no server
since it's just a static file, but everything will be tracked by GA.

      source = """
      <html>
          <title>{{url}}</title>
          <body>
            <!-- Google Analytics -->
            <script type="text/javascript">var _gaq = _gaq || [];_gaq.push(['_setAccount', '{{ga_id}}']);_gaq.push(['_setDomainName', 'yhathq.com']);_gaq.push(['_trackPageview']);(function() {var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);})();</script>
            <!-- redirect -->
            <script type="text/javascript">
              window.location.replace('{{url}}');
            </script>
          </body>
      </html>
      """

      template = handlebars.compile(source)

Data should just be the user's Google Analytics Id and the URL that they want to
minify.

      data = { url: "http://blog.yhathq.com/", ga_id: "ga-1234" }
      html = template(data)

We're going to generate a shortlink for the URL. [`shortid`](https://github.com/dylang/shortid) does a pretty good job at balancing between being short, and also
being unique!

      _id = shortid.generate()

We'll break up the s3 bucket by the [first 3 letters in the id](http://docs.aws.amazon.com/AmazonS3/latest/dev/request-rate-perf-considerations.html).
This makes it much easier for S3 to distribute the bucket (and greatly improves performance).

      directory = _id.slice(0, 3)
      mkdirp.sync path.join(__dirname, DOMAIN, directory)
      filename = path.join(__dirname, DOMAIN, directory, _id.slice(3))
      ## TODO: save to s3 instead
      fs.writeFileSync filename, html

We'll keep a running record of all links we've shortened and throw it into a basic
HTML page just to make it easy to do lookups.

      url = path.join(DOMAIN, directory, _id.slice(3))
      source = "
      <html>
          <title>Shortened Links</title>
          <body>
              <h1>Shortened Links</h1>
              <ul>
              {{#urls}}
                  <li><a href='{{ . }}'>{{ . }}</a></li>
              {{/urls}}
              </ul>
          </body>
      </html>
      "
      walk path.join(__dirname, DOMAIN), (err, urls) ->
        urls = urls.filter (url) ->
          ! /index.html$/.test url
        html = handlebars.compile(source)({ urls: urls })
        ## TODO: save to s3 instead
        fs.writeFileSync(path.join(__dirname, DOMAIN, "index.html"), html)
