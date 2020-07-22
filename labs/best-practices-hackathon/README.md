## Apigee Best Practices Hackathon Docs

This project hosts Apigee partner training documentation.

Use [claat](https://github.com/googlecodelabs/tools/tree/master/claat/) to generate static HTML site from the Markdown document

    go get github.com/googlecodelabs/tools/claat

    claat export ./lab.md

This will create directory with static files. Serve it from any static file webserver.
