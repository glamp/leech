    handlebars = require 'handlebars'
    aws = require 'aws-sdk'
    shortid = require 'shortid'

Setup the connection to s3

    aws.config.update {
        accessKeyId: process.env["AWS_ACCESS_KEY"],
        secretAccessKey: process.env["AWS_SECRET_KEY"]
    }
    aws.config.region = 'us-east-1'
    s3 = new aws.S3()

--------
We're going to make `remora` (this module) exportable so that we can use it in
the app, as a command line tool, and as it's own funciton. It takes 1 argument
(the url) which makes it easy to plug-n-play in other stuff.

    module.exports = (url) ->
      # maybe these should be args?
      DOMAIN = process.env["DOMAIN"] || "remora.link"
      BUCKET = process.env["BUCKET"] || DOMAIN
      GA_ID = process.env["GA_ID"]

      shortid.characters "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ()"

This is our basic HTML template that we'll use for doing the redirect. It's just
going to send the user to another page as soon as it's loaded. There's no server
since it's just a static file, but everything will be tracked by GA.

      source = """
      <html>
          <title>{{url}}</title>
          <body>
            <!-- Google Analytics -->
            <script type="text/javascript">
              (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
              (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
              m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
              })(window,document,'script','//www.google-analytics.com/analytics.js','ga');

              ga('create', '{{ga_id}}', 'auto');
              ga('send', 'pageview');

            </script>
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

      data = { url: url, ga_id: GA_ID }
      html = template(data)

We're going to generate a shortlink for the URL. [`shortid`](https://github.com/dylang/shortid) does a pretty good job at balancing between being short, and also
being unique! We'll take that `_id` and turn it into the key for an S3 object.

      _id = shortid.generate()
      params = {
          Bucket: BUCKET,
          Key: _id
          ACL: "public-read",
          Body: html
      }
      s3.putObject params, (err, data) ->
          if err
              console.log err

*The remainder is a nice to have*. We'll keep a running record of all links
we've shortened and throw it into a basic HTML page just to make it easy to do
lookups.

      source = """
      <html>
          <title>Shortened Links</title>
          <body>
              <h1>Shortened Links</h1>
              <ul>
              {{#objs}}
                  <li><a href='{{ Key }}'>{{ Key }}</a></li>
              {{/objs}}
              </ul>
          </body>
      </html>
      """
      params = { Bucket: BUCKET }
      s3.listObjects params, (err, objs) ->
        if err
            console.log "[ERROR]: could not list objects: " + err
        objs = objs.Contents.filter (obj) ->
          ! /index.html$/.test obj.Key
        html = handlebars.compile(source)({ objs: objs })
        params = {
            Bucket: BUCKET,
            Key: "index.html",
            ACL: "public-read",
            Body: html
        }
        s3.putObject params, (err, data) ->
            if err
                console.log "[ERROR]: " + err
        console.error "Visit: https://s3.amazonaws.com/#{BUCKET}/index.html"
