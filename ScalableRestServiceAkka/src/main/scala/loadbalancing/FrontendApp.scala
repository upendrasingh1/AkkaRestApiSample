package loadbalancing
import org.apache.curator.framework.CuratorFramework
import platform.{ServiceApplication, ZooKeeperConfiguration}

/**
  * Created by root on 10/28/16.
  */

/*
object FrontendApp extends App with ZooKeeperConfiguration{
  // Initializes ZooKeeper client
  val zkClient: CuratorFramework = initZooKeeperClient(service = Service, environment = Environment)
  val host = getSetting(s"$Service.host")(zkClient).asString
  val port = getSetting(s"$Service.port")(zkClient).asInt
  Frontend.initiate(host, port)
}
*/

object FrontendApp extends ServiceApplication {
  def createApplication() = new ApplicationDaemonFrontend()
}
