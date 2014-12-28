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
    aws = require "aws-sdk"
    leech = require "./leech"

    DOMAIN = process.env["DOMAIN"]
    aws.config.update {
        accessKeyId: process.env["AWS_ACCESS_KEY"],
        secretAccessKey: process.env["AWS_SECRET_KEY"]
    }
    aws.config.region = 'us-east-1'

    s3 = new aws.S3()
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
      res.render "index"

Simple route to look at all the URLs we've shortened.

    app.get "/urls", (req, res) ->
      params = { Bucket: DOMAIN }
      s3.listObjects params, (err, objs) ->
        if err
            console.log "[ERROR]: could not list objects: " + err
            return res.redirect "/"

        urls = []
        async.each objs.Contents, (obj, callback) ->
            if err
              console.log "error", data
            url = { key: "http://#{DOMAIN}/#{obj.Key}", url: data.Metadata.url }
            if url.url
              urls.push url
            callback()
        , (err) ->
          res.render "index", { urls: urls }

    app.get "/about", (req, res) ->
      res.render "about"

    app.get "/setup", (req, res) ->
      res.render "setup"

    app.post "/", (req, res) ->
      if req.body.url
        leech req.body.url, (err, url) ->
          if err
            res.render "index", { url: "ERROR" }
          else
            res.render "index", { url: url }
      else
        res.json { "error": "No URL Provided" }

    http.createServer(app).listen app.get("port"), ->
        console.log "Express server listening on port " + app.get("port")
