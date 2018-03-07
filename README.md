# testResourcesPruner

To build and run:
curl -sSL https://get.haskellstack.org/ | sh
stack build
stack exec -- testResourcesPruner-exe -w /Users/username/git/some-scala-project -a sub-project/test -d sub-project/src/test/resources
