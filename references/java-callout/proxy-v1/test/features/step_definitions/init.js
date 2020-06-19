const apickli = require('apickli')
const {
  Before,
  setDefaultTimeout
} = require('cucumber')

Before(function() {
  this.apickli = new apickli.Apickli(
    'https', 
    process.env.APIGEE_ORG + '-' + 
    process.env.APIGEE_ENV + '.apigee.net/apigee-java/v1'
  )
})

setDefaultTimeout(60 * 1000)
