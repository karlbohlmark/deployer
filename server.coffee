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

hash = '215ea622cb0a82'


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
				
				p = spawn 'npm', ['start'], runOptions

				p.stderr.setEncoding 'utf8'
				p.stderr.on('data', (data)-> console.log(data))
				p.stdout.setEncoding 'utf8'
				p.stdout.on('data', (data)-> console.log(data))
				processes[hash] = p
				callback(port)

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



app.listen(8080)

###
provision repo, hash, ()->
	console.log "provisioned commit #{hash} of #{repo}"
###