
# Usage
```
bntools::createApp(tags=c('test','test2'), mainCategory = 'test')
bntools::deployApp(username = 'me', password='mypassword')

```

# Storing username and password in .Rprofile

save the following in .Rprofile file

```
options("pamcloud.username"="myusername")
options("pamcloud.password"="mypassword")

```

```
bntools::createApp(tags=c('test','test2'), mainCategory = 'test')
bntools::deployApp()

```

