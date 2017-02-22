package loadbalancing
import platform._

/**
  * Created by root on 10/28/16.
  */


object BackendApp extends ServiceApplication{
  def createApplication() = new ApplicationDaemon()
}

object SeedBackendApp extends ServiceApplication{
  def createApplication() = new SeedApplicationDaemon()
}

/*
object BackendApp extends App{
  Backend.initiate()
}*/
