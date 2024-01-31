locals {
  tags_values = {

    APPLICATION : upper("devtest")
    BU : upper("BYS-BR")
    CREATION-DATE : formatdate("YYYYMM", timestamp())
    OWNER : "Carlos Marques"
    ENVIRONMENT : upper("DEV")
    #JOURNEY : upper("")
    #MODULE : upper("")
    TERRAFORM : upper("true")
    VP : upper("Tech")
    REPOS : upper("") 
  }
}