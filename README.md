# Basic step to create an app

- choose app name as lower case ex. myapp
- create git repository at bitbucket

use the same name as the app ex. myapp

Team : bnoperator

Project : bn_shiny_app

Repository name : myapp

- create R package with RStudio

use the same name as the app ex. myapp

git remote add origin https://username@bitbucket.org/bnoperator/myapp.git

- RStudio config

Build > Configure Build Tools

check generate documentation with Roxygen

then

check Roxygen options > Build & Reload

see [Roxygen2](https://cran.r-project.org/web/packages/roxygen2/vignettes/roxygen2.html)

see [Roxygen2 managing your NAMESPACE](https://cran.r-project.org/web/packages/roxygen2/vignettes/namespace.html)

```
 #' @import somepackage, anotherpackage
 #' @export
 myfunction = function(){ 
    ...
 }
```

- set package Title, it will be the app name once deployed
- set package Date
- set package Description
- set package URL, help url
- set package Version
- app icon : place an image file named pamapp.png at the project root

# Operator

Create file R/main.R and define the following functions

## Operator Properties

return the operator properties, this function is required.

```
#' @export
operatorProperties = function() {
  return (list(
    list('TestProperty', 'aDefault value'),
    list('TestEnum',list('aa','bb'))))
}
```

## Compute

One of the following function is required.


```
#' @export
shinyServerRun = function(input, output, session, context) {
  ...
}
```

```
#' @export
dataFrameOperator = function(data=data,properties=properties,folder=folder) {
  ...
}
```

## Show result

This function is optional.

```
#' @export
shinyServerShowResults = function(input, output, session, context) {
  ...
}
```

## Curve fitting

This function is optional.

```
#' @export
curveFitOperatorFunction = function(dataX , result)  {
  ...
}
```
  
# Crosstab Operator

Create file R/main.R and define the following functions

## Show result

This function is required.

```
#' @export
shinyServerShowResults = function(input, output, session, context) {
  ...
}
```

# Deploy

```
bntools::createApp(tags=c('test','test2'), mainCategory = 'test')
bntools::deployApp(username = 'me', password='mypassword')

```

## Storing username and password in .Rprofile

save the following in .Rprofile file

```
options("pamcloud.username"="myusername")
options("pamcloud.password"="mypassword")

```

```
bntools::createApp(tags=c('test','test2'), mainCategory = 'test')
bntools::deployApp()

```






