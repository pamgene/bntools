library(R6)
library(XML)
library(httr)

#' @export
parseTags = function(str){
  list = unlist(strsplit(str, "[;]"))
  list = lapply(list, function(each){
    return(substr(each, 2, length(list)-1))
  })
  return(as.character(list))
}

#' @export
tagsToString = function(list){
  str = paste0('_',paste(list,collapse='_;_'), '_')
  return(str)
}


#' @import R6 XML httr
#' @export
createApp = function(packagePath = getwd(), repository=NULL, repositoryType='bitbucket', tags=character(), mainCategory='pamapp'){
  app = PamAppDefinition$new()
  app$fromPackage(packagePath = packagePath, repository = repository, repositoryType = repositoryType)
  app$tags = tags
  app$mainCategory = mainCategory

  xml = app$toXML()
  file = paste0(packagePath, '/pamapp.padf')
  write(xml, file = file)
  return(app)
}

#' @export
deployApp = function(packagePath = getwd(), username=getOption("pamcloud.username"), password=getOption("pamcloud.password"), baseUrl = 'https://pamcloud.pamgene.com/jackrabbit/repository/default/PamApps2' ) {

  if (is.null(username)){
    stop('username is required')
  }

  if (is.null(password)){
    stop('password is required')
  }

  app = PamAppDefinition$new()
  app$fromFolder(packagePath=packagePath)

  x <- read.dcf(file = paste0(packagePath, "/DESCRIPTION"))

  if (app$package != x[1,'Package']){
    stop(paste0('Wrong package name, found ' , app$package, ' expected ' , x[1,'Package']))
  }

  if (app$version != x[1,'Version']){
    stop(paste0('Wrong version, found ' , app$version, ' expected ' , x[1,'Version']))
  }


  url = paste0(baseUrl, '/', app$mainCategory, '/', app$package, '_' , app$version, '.paf')

  response = HEAD(url, authenticate(username, password, type = "basic"))
  if (response$status_code != 404 || response$status_code == 200){
    stop(paste0("File ", url , " already exists, please increase the package version number. status ", response$status))
  }

  image = paste0(packagePath, '/pamapp.png')
  if (!file.exists(image) ) stop('No image file, please provide an image file named pamapp.png in current directory')

  workingDir = getwd()

  files = c('pamapp.padf', 'pamapp.png')
  zipFilename = tempfile(fileext = ".zip")
  utils::zip(zipFilename, files)

  setwd(workingDir)

  fileSize = file.info(zipFilename)$size
  zz = file(zipFilename, "rb")
  bytes = readBin(zz, raw(), n=fileSize, size = 1)

  cat(paste0('Uploading app at ' , url))

  response = PUT(url, authenticate(username, password, type = "basic"), body = bytes)
  if (response$status != 201 ){
    stop(paste0("Failed to upload file to ", url , ", response$status " , response$status))
  }

  cat('Deployed successfully\n')
  cat('----------------------------------------\n')
  cat('WARNING\n')
  cat(paste0('Make sure to create a git tag ' , app$version, '\n'))
  cat('git add -A && ')
  cat(paste0('git commit -m "' , app$version, '" && '))
  cat(paste0('git tag -a ' , app$version, ' -m "++" && '))
  cat('git push origin master && ')
  cat('git push origin --tags\n')
  cat('----------------------------------------\n')

}


#' @export
PamAppDefinition = R6Class(
  "PamAppDefinition",
  public = list(
    type = NULL,
    name = NULL,
    version = NULL,
    date = NULL,
    webLink = NULL,
    author = NULL,
    description = NULL,
    mainCategory = NULL,
    tags = NULL,
    capabilities = NULL,

    package = NULL,
    repository = NULL,
    repositoryType = NULL,

    initialize = function(){
      self$mainCategory = 'pamapp'
      self$tags = character()
    },

    addTag = function(tag){
      self$tags = union(self$tags, tag)
    },

    removeTag = function(tag){
      self$tags = setdiff(self$tags, tag)
    },

    hasTag = function(tag){
      return(is.element(tag, self$tags))
    },

    fromFolder = function(packagePath = getwd()){

      filename = paste0(packagePath, '/pamapp.padf')
      if (!file.exists(filename) ) stop('No app def file, please execute createApp first')

      doc = xmlParse(filename)
      root = xmlRoot(doc)

      self$type = xmlGetAttr(root, 'type')
      self$name = xmlGetAttr(root, 'name')
      self$version = xmlGetAttr(root, 'version')
      self$description = xmlGetAttr(root, 'description')
      self$author = xmlGetAttr(root, 'author')
      self$date = xmlGetAttr(root, 'date')
      self$capabilities = xmlGetAttr(root, 'capabilities')

      self$webLink = xmlGetAttr(root, 'webLink')
      self$mainCategory = xmlGetAttr(root, 'mainCategory')

      if (is.null(xmlGetAttr(root, 'tags'))){
        self$tags = character()
      } else {
        self$tags = parseTags(xmlGetAttr(root, 'tags'))
      }

      self$package = xmlGetAttr(root, 'package')
      self$repository = xmlGetAttr(root, 'repository')
      self$repositoryType = xmlGetAttr(root, 'repositoryType')
    },

    fromPackage = function(packagePath = getwd(), repository=NULL, repositoryType='bitbucket'){

      filename = paste0(packagePath, "/DESCRIPTION")
      if (!file.exists(filename) ) stop('No DESCRIPTION file')

      x <- read.dcf(file = filename)

      self$package = x[1,'Package']
      self$name = x[1,'Title']

      self$version = x[1,'Version']
      self$description = x[1,'Description']
      self$author = x[1,'Author']
      self$date = x[1,'Date']

      if ('URL' %in% colnames(x)){
        self$webLink = x[1,'URL']
      } else {
        self$webLink = 'https://pamcloud.pamgene.com/wiki/Wiki.jsp?page=PamApp%20default%20help%20page'
      }

      if (is.null(repository)){
        self$repository = paste0('bnoperator/', self$package)
      } else {
        self$repository = repository
      }

      self$repositoryType = repositoryType

      packageEnv = as.environment( paste0('package:', self$package) )

      hasShinyServerRun = exists( "shinyServerRun" , envir = packageEnv )
      hasDataFrameOperator = exists( "dataFrameOperator" , envir = packageEnv )
      hasShinyServerShowResults = exists( "shinyServerShowResults" , envir = packageEnv )
      hasOperatorProperties = exists( "operatorProperties" , envir = packageEnv )
      hasCurveFitOperatorFunction = exists( "curveFitOperatorFunction" , envir = packageEnv )

      if (hasShinyServerRun || hasDataFrameOperator){
        if (hasOperatorProperties){
          self$type = 'RDataStepOperator'
        } else {
          stop('Function operatorProperties is required')
        }
      } else if (hasShinyServerShowResults) {
        self$type = 'RDataScript'
      } else {
        stop('Package does not export any bn app functions : shinyServerRun | dataFrameOperator | shinyServerShowResults')
      }

      cap = list()
      if (hasShinyServerRun){
        cap$shinyServerRun = 'shinyServerRun'

      }
      if (hasDataFrameOperator){
        cap$dataFrameOperator = 'dataFrameOperator'
       }
      if (hasShinyServerShowResults){
        cap$shinyServerShowResults = 'shinyServerShowResults'
       }
      if (hasCurveFitOperatorFunction){
        cap$curveFitOperatorFunction = 'curveFitOperatorFunction'
       }

      self$capabilities = paste(cap,collapse=';' )
    },

    toXML = function(){
      doc = newXMLNode("pamAppDef")

      addAttributes(doc, "type"=self$type)
      addAttributes(doc, "name"=self$name)
      addAttributes(doc, "version"=self$version)
      addAttributes(doc, "author"=self$author)
      addAttributes(doc, "description"=self$description)
      addAttributes(doc, "date"=self$date)

      addAttributes(doc, "capabilities"=self$capabilities)

      addAttributes(doc, "package"=self$package)
      addAttributes(doc, "repository"=self$repository)
      addAttributes(doc, "repositoryType"=self$repositoryType)

      if (!is.null(self$webLink)) addAttributes(doc, "webLink"=self$webLink)
      if (!is.null(self$mainCategory)) addAttributes(doc, "mainCategory"=self$mainCategory)
      if (length(self$tags)>0) addAttributes(doc, "ztag"=tagsToString(self$tags))

      return(paste0('<?xml version="1.0" encoding="UTF-8"?>',saveXML(doc)))
    }
  )
)


