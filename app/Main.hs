module Main where

import Lib
import System.Process
import System.Exit
import System.Directory
import GHC.IO.Handle
import Data.Monoid (mempty, mappend)
import Data.List
import qualified Data.ByteString as BS
import Options.Applicative
import Data.Semigroup ((<>))

data Args = Args
  { workdir    :: String
  , cmd        :: String
  , cmdArg     :: String
  , dirToCheck :: String }

args :: Parser Args
args = Args
      <$> strOption
          ( long "workdir"
         <> short 'w'
         <> metavar "WORKDIR"
         <> help "Working directory in which to execute the command" )
      <*> strOption
          ( long "cmd"
         <> metavar "CMD"
         <> showDefault
         <> value "sbt"
         <> help "Command to execute, like 'sbt' or 'mvn'" )
      <*> strOption
          ( long "cmdArg"
         <> short 'a'
         <> metavar "CMD_ARG"
         <> help "Command argument" )
      <*> strOption
          ( long "dirToCheck"
         <> short 'd'
         <> metavar "DIR_TO_CHECK"
         <> help "Directory to check for unnecessary files (relative to the workdir)" )

tailOfAppended :: Int -> BS.ByteString -> BS.ByteString -> BS.ByteString
tailOfAppended atMost bs1 bs2 = accTail
    where
        acc = mappend bs1 bs2
        len = BS.length(acc)
        accTail = if len > atMost
            then BS.drop (len - atMost) acc
            else acc

-- from https://passingcuriosity.com/2015/haskell-reading-process-safe-deadlock/
gatherOutput :: Int -> ProcessHandle -> Handle -> IO (ExitCode, BS.ByteString)
gatherOutput atMost ph h = work mempty
  where
    work acc = do
        -- Read any outstanding input.
        bs <- BS.hGetNonBlocking h (64 * 1024)
        let acc' = tailOfAppended atMost acc bs
        -- Check on the process.
        s <- getProcessExitCode ph
        -- Exit or loop.
        case s of
            Nothing -> work acc'
            Just ec -> do
                -- Get any last bit written between the read and the status
                -- check.
                last <- BS.hGetContents h
                return (ec, tailOfAppended atMost acc' last)


--runLs :: IO (ExitCode, String, String)
--runLs = readProcessWithExitCode "ls" ["-a"] ""

--runSbt :: String -> String -> IO (ExitCode, String, String)
--runSbt arg workdir = readCreateProcessWithExitCode ((proc "sbt" [arg]) { cwd = Just workdir }) ""

runTests :: String -> String -> String -> IO Bool
runTests workdir cmd cmdArg = do
    let p = (proc cmd [cmdArg])
                { cwd = Just workdir
                , std_in  = Inherit
                , std_out = CreatePipe
                , std_err = NoStream
                }
    (Nothing, Just out, Nothing, ph) <- createProcess p
    let atMost = 300
    (exitcode, stdout) <- gatherOutput atMost ph out
    let outStr = show stdout
    -- TODO: make this test framework agnostic by using the exitcode instead of checkong contents of outStr
    let allTestsSuccessful = (isInfixOf "All tests passed." outStr) && (isInfixOf "failed 0, canceled 0" outStr)
    --putStrLn ("exitcode: " ++ (show exitcode))
    --putStrLn ("allTestsSuccessful: " ++ (show allTestsSuccessful))
    --putStrLn ("stdout: " ++ (show stdout))
    return allTestsSuccessful

checkElement :: String -> String -> String -> String -> String -> IO ()
checkElement workdir dirToCheck cmd cmdArg path = do
    putStr ("checking: " ++ path)
    let prefixed = dirToCheck ++ "/CAN_BE_DELETED__" ++ path
    let original = dirToCheck ++ "/" ++ path
    renamePath original prefixed
    allTestsSuccessful <- runTests workdir cmd cmdArg
    if allTestsSuccessful
        then do
            putStrLn ("  all tests passed, file can be deleted ")
        else do
            putStrLn ("  some tests failed, file cannot be deleted ")
            renamePath prefixed original

main :: IO ()
main = checkDirectory =<< execParser opts
  where
    opts = info (args <**> helper)
      ( fullDesc
     <> progDesc ("This program for each element found in the DIR_TO_CHECK directory performs: \n"
                ++ "  1) renames the file by adding a 'CAN_BE_DELETED__' prefix \n"
                ++ "  2) in directory WORKDIR executes the CMD with CMD_ARG - this is intended to run all tests \n"
                ++ "  3) if all tests were successful the file remains with the prefix, otherwise it is renamed back to its original name")
     <> header "testResourcesPruner - a simple tool for cleaning up src/test/resources" )

checkDirectory :: Args -> IO ()
checkDirectory (Args workdir cmd cmdArg subdirToCheck) = do
    let dirToCheck = workdir ++ "/" ++ subdirToCheck
    dirElems <- listDirectory dirToCheck
    putStrLn ("dirElems length: " ++ (show $ length dirElems))
    putStrLn ("dirElems take 5: " ++ (show $ take 5 dirElems))
    sequence_ $ map (checkElement workdir dirToCheck cmd cmdArg) dirElems
