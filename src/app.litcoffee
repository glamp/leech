Setup dependencies

    bodyParser = require "body-parser"
    express = require "express"
    exphbs = require "express-handlebars"
    fs = require "fs"
    http = require "http"
    async = require "async"
    lessMiddleware = require "less-middleware"
    methodOverride = require "method-override"
    path = require "path"
    AWS = require "aws-sdk"
    leech = require "./leech"

    DOMAIN = process.env["DOMAIN"]
    AWS.config.update {
        accessKeyId: process.env["AWS_ACCESS_KEY"],
        secretAccessKey: process.env["AWS_SECRET_KEY"]
    }
    AWS.config.region = 'us-east-1'

    s3 = new AWS.S3()
    app = express()
    app.set "port", process.env.PORT || 3000

Set up views

    app.set "views", path.join(__dirname, "..", "views")
    app.set "view engine", "html"
    app.engine "html", exphbs(
      defaultLayout: "main"
      extname: ".html"
    )
    #helpers: helpers
    app.enable "view cache"

Set up static assests

    app.use lessMiddleware(path.join(__dirname, "..", "public"), {}, {},
      compress: true
      sourceMap: true
    )
    app.use express.static(path.join(__dirname, "..", "public"))


Add methods PUT & DELETE

    app.use methodOverride()

Body parsing middleware

    app.use bodyParser.urlencoded(extended: true)
    app.use bodyParser.json()

Ze routes...

    app.get "/", (req, res) ->
      res.render "index", { isHome: true }

Simple route to look at all the URLs we've shortened.

    app.get "/history", (req, res) ->
      params = { Bucket: DOMAIN }
      s3.listObjects params, (err, objs) ->
        if err
            console.log "[ERROR]: could not list objects: " + err
            return res.redirect "/"

        urls = []
        async.each objs.Contents, (obj, callback) ->
          s3.headObject { Bucket: DOMAIN, Key: obj.Key }, (err, data) ->
            if err
              console.log "error", data
            url = { key: "http://#{DOMAIN}/#{obj.Key}", url: data.Metadata.url }
            if url.url
              urls.push url
            callback()
        , (err) ->
          res.render "history", { isHistory: true, urls: urls }

    app.get "/about", (req, res) ->
      res.render "about", { isAbout: true }

    app.get "/setup", (req, res) ->
      res.render "setup", { isSetup: true }

    app.post "/", (req, res) ->
      if req.body.url
        leech req.body.url, (err, url) ->
          if err
            res.render "index", { isHome: true, url: "ERROR" }
          else
            if req.query.format=="json"
              res.json { status: "OK", short_url: url, original_url: req.body.url }
            else
              res.render "index", { isHome: true, url: url }
      else
        res.json { status: "ERROR", error: "No URL Provided" }

    app.get "*", (req, res) ->
      res.render "404"

    http.createServer(app).listen app.get("port"), ->
        console.log "Express server listening on port " + app.get("port")
