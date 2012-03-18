express = require 'express'
path = require 'path'
fs = require 'fs'
portchecker = require 'portchecker'
#provisioner = require './provisioner'
args = require('optimist').argv
repoBaseUri = 'git@github.com:'
repo = args[1] || 'git@github.com:karlbohlmark/skill-search.git';

repoName = repo.match(/\/([^\/\.]*).git/)[1]

{ exec, spawn } = require 'child_process'

# State
processes = {}
# <--

baseRepo 	= __dirname + '/base'
installRoot = __dirname + '/installed'

mkdir = (dir)-> fs.mkdirSync dir if not path.existsSync dir
mkdir dir for dir in [baseRepo, installRoot]

checkout = (repo, hash, callback)->
	repoName = repo.match(/\/([^\/\.]*).git/)[1]
	repoPath = path.join baseRepo, repoName
	cloneCmd = "cd #{baseRepo} && git clone #{repo}"
	pullCmd = "cd #{repoPath} && git pull origin master"
	cloneOrPull = if path.existsSync(repoPath) then pullCmd else cloneCmd

	exec cloneOrPull, ()->
		installPath = path.join( installRoot, repoName )
		commitPath = path.join( installPath, hash )
		localrepo = path.join( baseRepo, repoName )
		mkdir installPath
		mkdir commitPath

		exec "cd #{localrepo} && git checkout #{hash}", (err)->
			exec "cd #{localrepo} && cp -a [!.]*  #{commitPath}/", (err)->
				callback(commitPath)
		
provision = (repo, hash, callback)->
	checkout repo, hash, (checkoutDir)->
		portchecker.getFirstAvailable 8000, 10000, 'localhost', (port)->
			console.log "got port #{port}"
			env = process.env
			env.DB_NAME = hash
			env.PORT = port
			runOptions = {
				cwd: checkoutDir,
				env:env
			}

			exec "npm run-script reset-db", runOptions, (code, out, err)->
				console.log('reset db')
				console.log code
				console.log out.toString()
				console.log err.toString()
				
				package = require(path.join(checkoutDir, 'package.json'))

				startScript = package.scripts.start
				cmdParts = startScript.split ' '
				args = cmdParts.splice(1)
				console.log(cmdParts[0])
				console.log args
				p = spawn cmdParts[0], args, runOptions

				p.stderr.setEncoding 'utf8'
				p.stderr.on('data', (data)-> console.log(data))
				p.stdout.setEncoding 'utf8'
				p.stdout.on('data', (data)-> console.log(data))
				processes[hash] = { process: p, port}

				callback(port)

http = require('http').createServer().listen(8081)
srv = require('distribute')(http)
srv.use express.bodyParser()
srv.use (req, res, next) ->
	host = req.headers['x-host']
	hash = if host then host.split('.')[0] else (req.body && req.body.commit || req.url.match(/\/\?([^\/]*)$/)[1])
	p = processes[hash]
	if not p
		res.writeHead(404)
		res.end("commit #{hash} not available")
		return
	console.log "proxy to port #{p.port}"
	next(p.port)

app = express.createServer()
app.use express.bodyParser()
app.use app.router
app.post '/deploy', (req, res)->
	commit = req.body.commit
	repoMatch = commit.match(/([^\/]*\/[^\/]*)\/commit\/([0-9a-f]{40})/)
	repo = repoBaseUri + repoMatch[1] + '.git'
	hash = repoMatch[2]
	provision repo, hash, (port)->
		console.log "provisioned commit #{hash} of #{repo} running on port #{port}"
		console.log Object.keys(processes)
		res.json {repo, hash, port}

app.get '/online', (req, res)->
	res.json Object.keys(processes)


app.listen(8080)

###
provision repo, hash, ()->
	console.log "provisioned commit #{hash} of #{repo}"
###