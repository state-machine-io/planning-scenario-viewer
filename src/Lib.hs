module Lib
  ( startApp,
  )
where

import qualified Controller
import qualified Data.ByteString as BS
import qualified Data.Pool as Pool
import qualified Data.Text as Text
import qualified Database.PostgreSQL.Simple as PGSimple
import Network.Wai
import Network.Wai.Handler.Warp (run)
import qualified Routes
import Servant
import qualified Types.Config as Config
import qualified Web.Browser as Browser

debug :: Middleware
debug app req resp = do
  putStrLn "Request headers:"
  print (requestHeaders req)
  app req resp

startApp :: Config.Config -> IO ()
startApp config@Config.Config {..} = do
  let connStr =
        PGSimple.defaultConnectInfo
          { PGSimple.connectHost = Config._host _configPG,
            PGSimple.connectDatabase = Config._database _configPG,
            PGSimple.connectUser = Config._user _configPG,
            PGSimple.connectPassword = Config._password _configPG
          }
  conns <- initConnectionPool (PGSimple.postgreSQLConnectionString connStr)
  b <- Browser.openBrowser $ Text.unpack _configApplicationDomain ++ ":" ++ (show _configApplicationPort)
  if b
    then run _configApplicationPort $ debug $ serve Routes.api (Controller.server config conns)
    else print "Failed to start browser"

initConnectionPool :: BS.ByteString -> IO (Pool.Pool PGSimple.Connection)
initConnectionPool connStr =
  Pool.createPool
    (PGSimple.connectPostgreSQL connStr)
    PGSimple.close
    2 -- stripes
    60 -- unused connections are kept open for a minute
    10 -- max. 10 connections open per stripe
