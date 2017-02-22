package loadbalancing

/**
  * Created by root on 10/28/16.
  */
import akka.cluster._
import com.typesafe.config.ConfigFactory
import akka.cluster.ClusterEvent.{ClusterDomainEvent, MemberUp}
import akka.actor.{Actor, ActorRef, ActorSystem, Props, RootActorPath}
import akka.routing.FromConfig
import platform.{AbstractApplicationDaemon, ReferenceApplication, ZookeeperClusterSeed}

case class Add(num1: Int, num2: Int)
case class AdditionResult(result : Int)

/*
class BackendReciever extends Actor{
  def receive = {
    case msg: Any =>
      //backend forward msg
      //context.actorSelection("/user/backendRouter") forward msg
      val backend = context.actorOf(Props[Backend])
      backend forward msg
      println("BackendReciever: I'll forward add operation to the backend actor to handle it.")
  }
}*/

class Backend extends Actor {

  def receive = {
    case Add(num1, num2) =>
      println(s"I'm a backend with path: ${self} and I received add operation.Result=($num1+$num2)")
      val result = num1 + num2
      sender() ! AdditionResult(result)
    case DoAddition(input) =>
      println(s"I'm backend with path: ${self} and I recieved add operation. ")
      val result = input.num1 + input.num2
      sender() ! AdditionResult(result)
  }
}


class ApplicationDaemon() extends AbstractApplicationDaemon{
  def application = new Application
}

class Application() extends ReferenceApplication{
  val config = ConfigFactory.parseString("akka.cluster.roles = [backend]").
    withFallback(ConfigFactory.load("loadbalancer"))

  implicit val system = ActorSystem("ClusterSystem", config)

  def startApplication(): Unit ={
    //ZookeeperClusterSeed(system).join()
    //val Backend = system.actorOf(Props[BackendReciever], name = "backendReciever")
  }

  def stopApplication(): Unit = {
    system.terminate()
  }
}

class SeedApplicationDaemon() extends AbstractApplicationDaemon{
  def application = new SeedApplication
}

class SeedApplication() extends ReferenceApplication{
  val config = ConfigFactory.parseString("akka.cluster.roles = [backend]").
    withFallback(ConfigFactory.parseString("akka.remote.netty.tcp.hostname=akkaseed")).
    withFallback(ConfigFactory.parseString("akka.remote.netty.tcp.port=2552")).
    withFallback(ConfigFactory.load("loadbalancer"))

  implicit val system = ActorSystem("ClusterSystem", config)

  def startApplication(): Unit ={
    //ZookeeperClusterSeed(system).join()
    //val Backend = system.actorOf(Props[Backend], name = "backend")
    //val Backend = system.actorOf(Props[BackendReciever], name = "backendReciever")
  }

  def stopApplication(): Unit = {
    system.terminate()
  }
}
//-Dakka.remote.netty.tcp.hostname=LUPES01.Tally.Tallysolutions.com -Dakka.remote.netty.tcp.port=2552

/*
object Backend {
  def initiate(port: Int){
    val config = ConfigFactory.parseString(s"akka.remote.netty.tcp.port=$port").
      withFallback(ConfigFactory.parseString("akka.cluster.roles = [backend]")).
      withFallback(ConfigFactory.load("loadbalancer"))

    val system = ActorSystem("ClusterSystem", config)


    val Backend = system.actorOf(Props[Backend], name = "backend")
  }

  def initiate(): Unit ={

    val config = ConfigFactory.parseString("akka.cluster.roles = [backend]").
      withFallback(ConfigFactory.load("loadbalancer"))

    val system = ActorSystem("ClusterSystem", config)
    ZookeeperClusterSeed(system).join()

    val Backend = system.actorOf(Props[Backend], name = "backend")
  }
}
*/