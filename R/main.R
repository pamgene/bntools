library(R6)
library(XML)
library(httr)

# #' @export
# shinyServerRun = function(){
#
# }

# #' @export
# dataFrameOperator = function(){
#
# }

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


#' @export
shinyServerShowResults = function(){

}

#' @export
test = function(){
  p = PamAppDefinition$new()
  p$fromPackage()
  xml = p$toXML()

  print(xml)
}


#' @import R6 XML httr
#' @export
createApp = function(packagePath = getwd(), name = NULL, repository=NULL, repositoryType='bitbucket', tags=character(), mainCategory='pamapp'){
  app = PamAppDefinition$new()
  app$fromPackage(packagePath = packagePath, name = name, repository = repository, repositoryType = repositoryType)
  app$tags = tags
  app$mainCategory = mainCategory

  xml = app$toXML()
  file = paste0(packagePath, '/pamapp.padf')
  write(xml, file = file)
  return(app)
}

#' @export
deployApp = function(packagePath = getwd(), username=NULL, pwd=NULL, baseUrl = 'https://pamcloud.pamgene.com/jackrabbit/repository/default/PamApps' ) {

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

  response = HEAD(url, authenticate(username, pwd, type = "basic"))
  if (response$status_code != 404 || response$status_code == 200){
    stop(paste0("File ", url , " already exists, please increase the package version number. status ", response$status))
  }

  image = paste0(packagePath, '/pamapp.png')
  if (!file.exists(image) ) stop('No image file, please provide an image file named pamapp.png in current directory')

  files = c(paste0(packagePath, '/pamapp.padf'), image)
  zipFilename = tempfile(fileext = ".zip")
  utils::zip(zipFilename, files)
  zz = file(zipFilename, "rb")
  bytes = readBin(zz, raw(), 8, size = 1)

  # response = HEAD('https://pamcloud.pamgene.com/jackrabbit/repository/default/PamApps/Visualization/Shiny%20PCA%20V5.paf', authenticate('alex', 'norton73', type = "basic"))

  print(paste0('Uploading app at ' , url))

  response = PUT(url, authenticate(username, pwd, type = "basic"), body = bytes)
  if (response$status != 201 ){
    stop(paste0("Failed to upload file to ", url , ", response$status " , response$status))
  }

  print('Deployed successfully')
  print('----------------------------------------')
  print('WARNING')
  print(paste0('Make sure to create a git tag ' , app$version))
  print('git add -A')
  print(paste0('git commit -m "' , app$version, '"'))
  print(paste0('git tag -a ' , app$version, ' -m "++"'))
  print('git push origin master')
  print('git push origin --tags')
  print('----------------------------------------')

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

    package = NULL,
    repository = NULL,
    repositoryType = NULL,

    initialize = function(){
      self$webLink = 'https://pamcloud.pamgene.com/wiki/Wiki.jsp?page=PamApp%20default%20help%20page'
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

    fromPackage = function(packagePath = getwd(), name = NULL, repository=NULL, repositoryType='bitbucket'){

      filename = paste0(packagePath, "/DESCRIPTION")
      if (!file.exists(filename) ) stop('No DESCRIPTION file')

      x <- read.dcf(file = filename)

      self$package = x[1,'Package']
      if (is.null(name)){
        self$name = self$package
      } else {
        self$name = name
      }

      self$version = x[1,'Version']
      self$description = x[1,'Description']
      self$author = x[1,'Author']
      self$date = x[1,'Date']

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

      if (hasShinyServerRun || hasDataFrameOperator){
        self$type = 'RDataStepOperator'
      } else if (hasShinyServerShowResults) {
        self$type = 'RDataScript'
      } else {
        stop('Package does not export bn app functions')
      }
    },

    toXML = function(){
      doc = newXMLNode("pamAppDef")

      addAttributes(doc, "type"=self$type)
      addAttributes(doc, "name"=self$name)
      addAttributes(doc, "version"=self$version)
      addAttributes(doc, "author"=self$author)
      addAttributes(doc, "description"=self$description)
      addAttributes(doc, "date"=self$date)

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


