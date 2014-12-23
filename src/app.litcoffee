
Setup dependencies

    bodyParser = require "body-parser"
    express = require "express"
    exphbs = require "express-handlebars"
    fs = require "fs"
    http = require "http"
    lessMiddleware = require "less-middleware"
    methodOverride = require "method-override"
    path = require "path"
    leech = require "./leech"

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
    
    app.get "/about", (req, res) ->
        res.render "about"

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
