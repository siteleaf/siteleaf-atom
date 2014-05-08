{View} = require 'atom'

module.exports =
class SiteleafAtomView extends View
  @content: ->
    @div class: 'siteleaf-atom overlay from-top', =>
      @div "The SiteleafAtom package is Alive! It's ALIVE!", class: "message"

  initialize: (serializeState) ->
    atom.workspaceView.command "siteleaf:preview", => @preview()

  # Returns an object that can be retrieved when package is activated
  serialize: ->

  # Tear down any state and detach
  destroy: ->
    @detach()

  port: 8000
  running: false
  api_base: 'https://api.siteleaf.com/v1'
  api_key: null
  api_secret: null
  site_id: null

  preview: ->
    if this.running
      open = require 'open'
      open "http://localhost:#{this.port}"
    else
      portfinder = require 'portfinder'
      portfinder.getPort (err, port) =>
        this.port = port
        this.server()

  server: ->
    open = require 'open'
    url = require 'url'
    fs = require 'fs'
    static_ = require 'node-static'
    request_ = require 'request'
    that = this

    fileServer = new static_.Server atom.project.getPath()

    require("http").createServer((req, res) ->
      path = decodeURI(url.parse(req.url).pathname)
      is_asset = path.match(/^\/?(?!(sitemap|feed)\.xml)(assets|.*\.)/)
      if is_asset
        project_path = atom.project.getPath()
        if fs.existsSync "#{project_path}#{path}"
          fileServer.serve req, res
        else
          that.resolve_url path, (body) ->
            if body
              request.get(body).pipe(res)
            else
              res.end "Not found."
      else if template = that.resolve_template(path)
        that.preview_url path, template, (body) ->
          res.writeHead 200, {"Content-Type": "text/html"}
          res.end body
      else
        res.end "No template found."
    ).listen this.port

    open "http://localhost:#{this.port}"

    this.running = true

  resolve_template: (path) ->
    fs = require 'fs'
    template_data = null

    path = path.replace(/^\/|\/$/g,'') #strip beginning and trailing slashes
    project_path = atom.project.getPath()

    templates = this.templates_for_path(path)

    for template in templates
      if fs.existsSync "#{project_path}/#{template}"
        template_data = fs.readFileSync("#{project_path}/#{template}", "utf8")
        break

    # compile liquid includes into a single page
    include_tags = /\{\%\s+include\s+['"]([A-Za-z0-9_\-\/]+)['"]\s+\%\}/g
    while template_data.match(include_tags)
      template_data = template_data.replace include_tags, (match, contents, offset, s) ->
        return fs.readFileSync("#{project_path}/_#{contents}.html", "utf8")

    return template_data

  templates_for_path: (path) ->
    slugs = path.split('/')
    paths = []

    if !path
      paths.push('index.html')
    else
      paths.push(
        "#{path}.html",
        "#{path}/index.html",
        "#{path}/default.html"
      )

    while slugs.length > 0
      slugs.pop()

      if slugs.length > 0
        paths.push("#{slugs.join('/')}/default.html")

    paths.push('default.html')
    paths

  load_settings: ->
    fs = require 'fs'

    home_path = process.env.HOME || process.env.HOMEPATH || process.env.USERPROFILE
    if fs.existsSync "#{home_path}/.siteleaf"
      if settings = fs.readFileSync("#{home_path}/.siteleaf", "utf8").match(/([a-z0-9]{32})/ig)
        this.api_key = settings[0]
        this.api_secret = settings[1]

    project_path = atom.project.getPath()
    if fs.existsSync "#{project_path}/config.ru"
      if settings = fs.readFileSync("#{project_path}/config.ru", "utf8").match(/:site_id => '([a-z0-9]{24})'/i)
        this.site_id = settings[1]

  preview_url: (url, template, callback) ->
    this.load_settings()

    request = require("request")
    request.post
      url: "#{this.api_base}/sites/#{this.site_id}/preview",
      auth:
        user: this.api_key
        pass: this.api_secret
      form:
        url: url
        template: template
    , (err, res, body) ->
      #if not err and res.statusCode is 200
      if body
        callback body
      else
        callback "no" #res.statusMessage

  resolve_url: (url, callback) ->
    this.load_settings()

    request = require("request")
    request.get
      url: "#{this.api_base}/sites/#{this.site_id}/resolve",
      json: true
      auth:
        user: this.api_key
        pass: this.api_secret
      form:
        url: url
    , (err, res, body) ->
      if not err and res.statusCode is 200
        callback body.file.url
      else
        callback null
