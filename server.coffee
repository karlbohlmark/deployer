http = require 'http'
path = require 'path'
fs = require 'fs'
portchecker = require 'portchecker'
#provisioner = require './provisioner'
args = require('optimist').argv
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
			exec "export DB_NAME=#{hash} && npm run-script reset-db", ()->
				console.log('reset db')
				env = process.env
				env.DB_NAME = hash
				env.PORT = port
				p = spawn 'npm', ['start'], { 
					cwd: checkoutDir,
					env:env
				}

				p.stderr.setEncoding 'utf8'
				p.stderr.on('data', (data)-> console.log(data))
				p.stdout.setEncoding 'utf8'
				p.stdout.on('data', (data)-> console.log(data))
				processes[hash] = p

provision repo, hash, ()->
	console.log "provisioned commit #{hash} of #{repo}"
