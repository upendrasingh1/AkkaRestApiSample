package platform
import org.apache.commons.daemon._

/**
  * Created by root on 11/2/16.
  */
//This code is to make an application deamon
trait ApplicationLifecycle {
  def start(): Unit
  def stop(): Unit
}

abstract class AbstractApplicationDaemon extends Daemon {
  def application: ApplicationLifecycle
  def init(daemonContext: DaemonContext) {}
  def start()   = application.start()
  def stop()    = application.stop()
  def destroy() = application.stop()
}

trait ServiceApplication extends App {

  def createApplication(): AbstractApplicationDaemon

  val application = createApplication()
  private[this] var cleanupAlreadyRun: Boolean = false

  def cleanup() {
    val previouslyRun = cleanupAlreadyRun
    cleanupAlreadyRun = true
    if (!previouslyRun) application.stop()
  }

  Runtime.getRuntime.addShutdownHook( new Thread( new Runnable {
    def run() {
      cleanup()
    }
  } ) )

  application.start()
}

abstract class ReferenceApplication extends ApplicationLifecycle {

  def startApplication(): Unit
  def stopApplication(): Unit

  private[this] var started: Boolean = false

  def start() = if (!started) {
    started = true
    startApplication()
  }

  def stop() = if (started) {
    started = false
    stopApplication()
  }
}
