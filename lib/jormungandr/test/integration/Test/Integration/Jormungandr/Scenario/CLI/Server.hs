{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module Test.Integration.Jormungandr.Scenario.CLI.Server
    ( spec
    ) where

import Prelude

import Control.Concurrent
    ( threadDelay )
import System.IO.Temp
    ( withSystemTempDirectory )
import System.Process
    ( terminateProcess, withCreateProcess )
import Test.Hspec
    ( SpecWith, describe, it )
import Test.Hspec.Expectations.Lifted
    ( shouldBe )
import Test.Integration.Framework.DSL
    ( Context (..)
    , KnownCommand (..)
    , collectStreams
    , expectPathEventuallyExist
    , proc'
    , shouldContainT
    , shouldNotContainT
    )
import Test.Integration.Framework.TestData
    ( versionLine )

spec :: forall t. KnownCommand t => SpecWith (Context t)
spec = do
    describe "SERVER - cardano-wallet serve" $ do
        it "SERVER - Can start cardano-wallet serve --database" $ \_ -> do
            withTempDir $ \d -> do
                let db = d ++ "/db-file"
                let args =
                        [ "serve", "--database", db, "--genesis-hash"
                        , "dba597bee5f0987efbf56f6bd7f44c38\
                          \158a7770d0cb28a26b5eca40613a7ebd"
                        ]
                let process = proc' (commandName @t) args
                withCreateProcess process $ \_ _ _ ph -> do
                    expectPathEventuallyExist db
                    terminateProcess ph
            threadDelay oneSecond

    describe "LOGGING - cardano-wallet serve logging" $ do
        it "LOGGING - Launch can log --verbose" $ \_ -> do
            let args =
                    ["serve"
                    , "--random-port"
                    , "--verbose"
                    , "--genesis-hash"
                    , "dba597bee5f0987efbf56f6bd7f44c38\
                      \158a7770d0cb28a26b5eca40613a7ebd"
                    ]
            let process = proc' (commandName @t) args
            (out, _) <- collectStreams (20, 0) process
            out `shouldContainT` versionLine
            out `shouldContainT` "Debug"
            out `shouldContainT` "Info"
            out `shouldContainT` "Notice"

        it "LOGGING - Serve --quiet logs Error only" $ \_ -> do
            let args =
                    ["serve"
                    , "--random-port"
                    , "--quiet"
                    , "--genesis-hash"
                    , "dba597bee5f0987efbf56f6bd7f44c38\
                      \158a7770d0cb28a26b5eca40613a7ebd"
                    ]
            let process = proc' (commandName @t) args
            (out, err) <- collectStreams (10, 10) process
            out `shouldBe` mempty
            err `shouldBe` mempty

        it "LOGGING - Serve default logs Info" $ \_ -> do
            let args =
                    ["serve"
                    , "--random-port"
                    , "--genesis-hash"
                    , "dba597bee5f0987efbf56f6bd7f44c38\
                      \158a7770d0cb28a26b5eca40613a7ebd"
                    ]
            let process = proc' (commandName @t) args
            (out, _) <- collectStreams (5, 0) process
            out `shouldNotContainT` "Debug"
            out `shouldContainT` versionLine
            out `shouldContainT` "Info"
            out `shouldContainT` "Notice"


oneSecond :: Int
oneSecond = 1000000

withTempDir :: (FilePath -> IO a) -> IO a
withTempDir = withSystemTempDirectory "integration-state"