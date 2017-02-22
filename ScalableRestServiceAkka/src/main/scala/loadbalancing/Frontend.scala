package loadbalancing

/**
  * Created by root on 10/28/16.
  */

import scala.concurrent.duration._
import com.typesafe.config.ConfigFactory
import akka.actor.{Actor, ActorLogging, ActorRef, ActorSystem, Props, ReceiveTimeout}
import akka.cluster.Cluster
import akka.cluster.ClusterEvent.ClusterDomainEvent
import akka.cluster.routing.{AdaptiveLoadBalancingPool, ClusterRouterPool, ClusterRouterPoolSettings, SystemLoadAverageMetricsSelector}
import akka.pattern.ask
import akka.util.Timeout
import akka.routing.{BalancingPool, BroadcastPool, FromConfig}
import akka.stream.ActorMaterializer
import akka.http.scaladsl.Http
import akka.http.scaladsl.marshallers.sprayjson.SprayJsonSupport
import akka.http.scaladsl.model.StatusCodes
import akka.http.scaladsl.server.Directives._
import akka.http.scaladsl.server.Route
import org.apache.curator.framework.CuratorFramework
import platform._
import spray.json.DefaultJsonProtocol

import scala.util.Random
import scala.io.StdIn

trait ResultJsonSupport extends SprayJsonSupport with DefaultJsonProtocol {
  implicit val resultFormat = jsonFormat1(AdditionResult)
  implicit val inputFormat = jsonFormat2(Add)
}

//case class Add(num1: Int, num2: Int)
case class DoAddition(add: Add)

class ApplicationDaemonFrontend() extends AbstractApplicationDaemon {
  def application = new FrontendApplication
}


class FrontendApplication() extends ReferenceApplication with ResultJsonSupport with ZooKeeperConfiguration {

  private var _frontend: ActorRef = _

  def props(): Props = {
    Props(classOf[Frontend])
  }

  val host = "0.0.0.0"

  val fconfig = ConfigFactory.parseString("akka.cluster.roles = [frontend]").
    withFallback(ConfigFactory.load("loadbalancer"))

  //val port = fconfig getInt "application.exposed-port"

  //Define the route
  val route: Route = {
    //import system.dispatcher

    implicit val timeout = Timeout(20 seconds)
    path("addition") {
      post {
        //val frontend = system.actorOf(Props[Frontend], name = "frontend")
        val frontend = system.actorOf(Props[Frontend])
        entity(as[Add]) { input =>

          onSuccess(frontend.ask(DoAddition(input))) {
            case response: AdditionResult =>
              complete(StatusCodes.OK, s"Result of addition is: ${response.result}!")

            case _ =>
              complete(StatusCodes.InternalServerError, s"Call failed!")
          }
          /*
          onSuccess(_frontend.ask(DoAddition(input))) {
            case response: AdditionResult =>
              complete(StatusCodes.OK, s"Result of addition is: ${response.result}!")
            case _ =>
              complete(StatusCodes.InternalServerError, s"Call failed!")
          }*/
        }
      }
    }
  }
  implicit val system = ActorSystem("ClusterSystem", fconfig)
  //implicit val backend = system.actorOf(FromConfig.props(), name = "backendRouter")
  implicit val backend = system.actorOf(
    ClusterRouterPool(AdaptiveLoadBalancingPool(
      /*SystemLoadAverageMetricsSelector*/), ClusterRouterPoolSettings(
      totalInstances = 1000, maxInstancesPerNode = 10,
      allowLocalRoutees = false, useRole = Some("backend"))).props(Props[Backend]),
    name = "BackendRouter")
  /*implicit val backend = system.actorOf(ClusterRouterPool(BroadcastPool(10),
    ClusterRouterPoolSettings(totalInstances = 1000,
      maxInstancesPerNode = 20,
      allowLocalRoutees = false,
      useRole = None)).props(Props[Backend]),name="backendRouter")*/


  def startApplication() {
    //ZookeeperClusterSeed(system).join()
    system.log.info("Frontend will start when 2 backend members in the cluster.")
    implicit val materializer = ActorMaterializer()
    implicit val executionContext = system.dispatcher
    val host = "0.0.0.0"
    val port = 8080

    //#registerOnUp
    Cluster(system) registerOnMemberUp {
      _frontend = system.actorOf(Props[Frontend],
        name = "frontend")
    }
    Cluster(system) registerOnMemberUp()

    //Startup and listen for requests
    val bindingFuture = Http().bindAndHandle(route, host, port)
    println(s"Waiting for requests at http://$host:$port/  ...\nHit Return to terminate")
    StdIn.readLine()

    //#registerOnUp
    //val zkClient: CuratorFramework = initZooKeeperClient(service = Service, environment = Environment)
    //val host = getSetting(s"$Service.host")(zkClient).asString
    //val port = getSetting(s"$Service.port")(zkClient).asInt


  }

    def stopApplication() {
      //Shutdown
      //bindingFuture.flatMap(_.unbind())
      system.terminate()

    }


}

/*
object FrontendApp extends ServiceApplication {
  def createApplication() = new ApplicationDaemonFrontend()
}*/


/*
object Frontend extends ResultJsonSupport{

  private var _frontend: ActorRef = _

  val upToN = 200

  def props(): Props = {
    Props(classOf[Frontend])
  }

  def initiate(host:String, port: Int) = {
    //val host = "0.0.0.0"

    val config = ConfigFactory.parseString("akka.cluster.roles = [frontend]").
      withFallback(ConfigFactory.load("loadbalancer"))

    //val port = config getInt "application.exposed-port"

    implicit val system = ActorSystem("ClusterSystem", config)
    ZookeeperClusterSeed(system).join()
    system.log.info("Frontend will start when 2 backend members in the cluster.")
    implicit val materializer = ActorMaterializer()
    implicit val executionContext = system.dispatcher

    //#registerOnUp
    Cluster(system) registerOnMemberUp {
      _frontend = system.actorOf(Props[Frontend],
        name = "frontend")
    }
    Cluster(system) registerOnMemberUp()
    //#registerOnUp



    //Define the route
    val route : Route = {

      implicit val timeout = Timeout(20 seconds)

      path("addtion") {
        post {
          entity(as[Add]) { input =>
            onSuccess(_frontend.ask(DoAddition(input))) {
              case response: AdditionResult =>
                complete(StatusCodes.OK,s"Result of addition is: ${response.result}!")
              case _ =>
                complete(StatusCodes.InternalServerError, s"Call failed!")
            }
          }
        }
      }
    }


    //Startup and listen for requests
    val bindingFuture = Http().bindAndHandle(route, host, port)
    println(s"Waiting for requests at http://$host:$port/  ...\nHit Return to terminate")
    StdIn.readLine()

    //Shutdown
    bindingFuture.flatMap(_.unbind())
    system.terminate()
  }

  def getFrontend = _frontend
} */


class Frontend extends Actor with ActorLogging {

  import context.dispatcher

  //val backend = context.actorOf(FromConfig.props(), name = "backendRouter")
  /*
  val backend = context.actorOf(
    ClusterRouterPool(AdaptiveLoadBalancingPool(
      SystemLoadAverageMetricsSelector), ClusterRouterPoolSettings(
      totalInstances = 100, maxInstancesPerNode = 3,
      allowLocalRoutees = false, useRole = Some("backend"))).props(Props[Backend]),
    name = "BackendRouter")*/
  def receive = {
    /*
    case addOp: Add =>
      println("Frontend: I'll forward add operation to backend node to handle it.")
      backend forward addOp

    case doadd: DoAddition =>
      println("Frontend: I'll forward add operation to the backend node to handle it.")
      backend forward doadd
      */
    case msg: Any =>
      //backend forward msg
      context.actorSelection("/user/BackendRouter") forward msg
      println("Frontend: I'll forward add operation to the backend node to handle it.")
  }
}


