(function() {
  var args, baseRepo, deploy, dir, exec, fs, hash, http, installRoot, mkdir, path, ports, provision, repo, repoName, spawn, _i, _len, _ref, _ref2;

  http = require('http');

  path = require('path');

  fs = require('fs');

  ports = {
    claim: function() {
      return 8008;
    }
  };

  args = require('optimist').argv;

  repo = args[1] || 'git@github.com:karlbohlmark/skill-search.git';

  repoName = repo.match(/\/([^\/\.]*).git/)[1];

  _ref = require('child_process'), exec = _ref.exec, spawn = _ref.spawn;

  baseRepo = __dirname + '/base';

  installRoot = __dirname + '/installed';

  mkdir = function(dir) {
    if (!path.existsSync(dir)) return fs.mkdirSync(dir);
  };

  _ref2 = [baseRepo, installRoot];
  for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
    dir = _ref2[_i];
    mkdir(dir);
  }

  hash = '8a4fd391a6659c0293c96';

  exec("cd " + baseRepo + " && git clone " + repo, function() {
    var commitPath, installPath, localrepo;
    installPath = installRoot + repoName;
    commitPath = path.join(installPath, hash);
    localrepo = path.join(baseRepo, repoName);
    mkdir(installPath);
    mkdir(commitPath);
    return exec("cd " + localrepo + " && git checkout " + hash, function(err) {
      console.log(err);
      console.log('checked out hash');
      return exec("cd " + installPath + " cp -r [!.]*  " + commitPath + "/", function(err) {
        console.log(err);
        return console.log('copied commit');
      });
    });
  });

  deploy = function(hash) {
    var installPath, localrepo;
    provisioner.provision({
      repo: repo,
      hash: hash
    });
    installPath = installRoot + repoName;
    localrepo = path.join(baserepo, repoName);
    return exec("rm -rf " + installPath + " && cd " + installRoot + " && git clone " + localrepo, function() {
      return console.log('cloned the repo');
    });
  };

  provision = function(descriptor) {
    var installDir, port;
    port = ports.claim(repo, hash);
    installDir = location + hash.substring(0, 5);
    mkdir(installDir);
    return checkout(installDir, repo, hash);
  };

}).call(this);
