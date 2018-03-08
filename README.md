# testResourcesPruner

This tool was created in a very specific purpose: to clean up src/test/resources which over time accumulated various test input files. Over time tests were refactored, rewritten, removed, moved to another sub-projects but the input files were not always updated. Analyzing the code to figure out which files are not used is laborious and it's better to use this tool. Just fire it up with appropriate arguments and have a cup of coffee (or maybe a lot more often: go to sleep). The tool will check if tests pass without the files from given directory, most often src/test/resources, by checking files one by one. While there are faster options for monitoring which files were used by a process in Linux/Unix systems this approach has the advantage of being platform independent - should work on Windows (also, it was just fun to implement).

## How to build and run

1. Install Haskell Stack:
```
> curl -sSL https://get.haskellstack.org/ | sh
```

2. Build
```
> stack build
```

3. Run
```
> stack exec -- testResourcesPruner-exe \
  --workdir /Users/username/git/some-scala-project \
  --cmdArg sub-project/test \
  --dirToCheck sub-project/src/test/resources
```

4. More detailed information
```
> stack exec -- testResourcesPruner-exe --help
testResourcesPruner - a simple tool for cleaning up src/test/resources

Usage: testResourcesPruner-exe (-w|--workdir WORKDIR) [--cmd CMD]
                               (-a|--cmdArg CMD_ARG)
                               (-d|--dirToCheck DIR_TO_CHECK)
  This program for each element found in the DIR_TO_CHECK directory performs: 1)
  renames the file by adding a 'CAN_BE_DELETED__' prefix 2) in directory WORKDIR
  executes the CMD with CMD_ARG - this is intended to run all tests 3) if all
  tests were successful the file remains with the prefix, otherwise it is
  renamed back to its original name

Available options:
  -w,--workdir WORKDIR     Working directory in which to execute the command
  --cmd CMD                Command to execute, like 'sbt' or
                           'mvn' (default: "sbt")
  -a,--cmdArg CMD_ARG      Command argument
  -d,--dirToCheck DIR_TO_CHECK
                           Directory to check for unnecessary files (relative to
                           the workdir)
  -h,--help                Show this help text
```
