
#' @import bnutil
#' @import R6
#' @import XML
#' @import httr
#' @export
createApp = function(packagePath = getwd(),
                     repository=NULL,
                     repositoryType='bitbucket',
                     tags=character(),
                     mainCategory='pamapp'){
  app = bnutil::PamAppDefinition$new()
  app$fromPackage(packagePath = packagePath, repository = repository, repositoryType = repositoryType)
  app$tags = tags
  app$mainCategory = mainCategory

  xml = app$toXML()
  file = paste0(packagePath, '/pamapp.padf')
  write(xml, file = file)
  return(app)
}

deployApp = function(packagePath = getwd(),
                     username=getOption("pamcloud.username"),
                     password=getOption("pamcloud.password"),
                     baseUrl = getOption("pamcloud.pamapp.url",
                                         default='https://pamcloud.pamgene.com/jackrabbit/repository/default/PamApps2') ) {


  if (is.null(username)){
    stop('username is required')
  }

  if (is.null(password)){
    stop('password is required')
  }

  app = bnutil::PamAppDefinition$new()
  app$fromFolder(packagePath=packagePath)

  x <- read.dcf(file = paste0(packagePath, "/DESCRIPTION"))

  if (app$package != x[1,'Package']){
    stop(paste0('Wrong package name, found ' , app$package, ' expected ' , x[1,'Package']))
  }

  if (app$version != x[1,'Version']){
    stop(paste0('Wrong version, found ' , app$version, ' expected ' , x[1,'Version']))
  }


  url = paste0(baseUrl, '/',  app$package, '_' , app$version, '.paf')

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

  cat(paste0('Uploading app at ' , url,'\n'))

  response = PUT(url, authenticate(username, password, type = "basic"), body = bytes)
  if (response$status != 201 ){
    stop(paste0("Failed to upload file to ", url , ", response$status " , response$status))
  }

#   cat('Deployed successfully\n')
#   cat('----------------------------------------\n')
#   cat('WARNING\n')
#   cat(paste0('Make sure to create a git tag ' , app$version, '\n'))
#   cat('git add -A && ')
#   cat(paste0('git commit -m "' , app$version, '" && '))
#   cat(paste0('git tag -a ' , app$version, ' -m "++" && '))
#   cat('git push origin master && ')
#   cat('git push origin --tags\n')
#   cat('----------------------------------------\n')

}

#' @import devtools
#' @export
deployPackage = function(packagePath = getwd(),
                         repoFolder = getOption("pamcloud.pgcran.folder", default='x:/')){


  oldwd = getwd()
  setwd(packagePath)
  on.exit(setwd(oldwd))

  # build source
  sourceFile = devtools::build()
  # build binary
  binaryFile = devtools::build(binary=TRUE)

  drat::insertPackage(sourceFile, repoFolder)
  drat::insertPackage(binaryFile, repoFolder)

}

#' @import devtools
#' @export
deployGitPackage = function(git,
                            ref=NULL,
                            repoFolder = getOption("pamcloud.pgcran.folder", default='x:/')){

  if (is.null(ref)){
    stop('deployGitPackage : git ref is null')
  }

  tmp = tempfile()
  dir.create(tmp)

  oldwd = getwd()
  setwd(tmp)
  on.exit(setwd(oldwd))

  # git clone
  cmd = sprintf(paste("git clone %s"), git)
  code = system(cmd)
  if (code != 0) stop('git clone as failed')

  # get git repo dir
  dir = list.dirs(tmp, recursive = FALSE)

  setwd(dir)

  # git checkout branch or tag or commit
  cmd = sprintf(paste("git checkout %s"), ref)
  code = system(cmd)
  if (code != 0) stop('git checkout as failed')

  deployPackage(repoFolder=repoFolder)

  unlink(tmp, recursive = TRUE)
}

#' @export
deployGitApp = function(git, ref=NULL,
                     username=getOption("pamcloud.username"),
                     password=getOption("pamcloud.password"),
                     baseUrl = getOption("pamcloud.pamapp.url", default='https://pamcloud.pamgene.com/jackrabbit/repository/default/PamApps2'),
                     repoFolder = getOption("pamcloud.pgcran.folder", default='x:/')){

  if (is.null(ref)){
    stop('deployGitPackage : git ref is null')
  }

  tmp = tempfile()
  dir.create(tmp)

  oldwd = getwd()
  setwd(tmp)
  on.exit(setwd(oldwd))

  # git clone
  cmd = sprintf(paste("git clone %s"), git)
  code = system(cmd)
  if (code != 0) stop('git clone as failed')

  # get git repo dir
  dir = list.dirs(tmp, recursive = FALSE)

  setwd(dir)

  # git checkout branch or tag or commit
  cmd = sprintf(paste("git checkout %s"), ref)
  code = system(cmd)
  if (code != 0) stop('git checkout as failed')

  deployPackage(repoFolder=repoFolder)
  deployApp(username=username, password=password, baseUrl=baseUrl)

  unlink(tmp, recursive = TRUE)

}




