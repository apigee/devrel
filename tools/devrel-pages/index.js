/**
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

const fs = require("fs");
const path = require("path");
const showdown = require("showdown");

(function generateDevrelEntryPage() {
  const readmePath = path.join(__dirname, "..", "..", "README.md");
  const readmeContent = fs.readFileSync(readmePath, "utf8");

  const converter = new showdown.Converter();
  const html = converter.makeHtml(readmeContent);

  const titleRegex = new RegExp('^<h[123] id="(.*)">.*</h[123]>');
  const relativeLinkRegex = new RegExp(
    '.*href="((?:tools|labs|references)/.*)".*'
  );

  const githubServerName =
    process.env.GITHUB_SERVER_URL || "https://github.com";
  const githubRepoName = process.env.GITHUB_REPOSITORY || "apigee/devrel";

  const devrelCategories = {
    references: [],
    labs: [],
    tools: [],
  };

  let currentCategory = null;

  html.split("\n").forEach((l) => {
    const matchedTitle = l.match(titleRegex);
    if (matchedTitle && devrelCategories[matchedTitle[1]]) {
      currentCategory = matchedTitle[1];
    } else if (matchedTitle) {
      currentCategory = null;
    }

    if (currentCategory && devrelCategories[currentCategory]) {
      linkMatches = l.match(relativeLinkRegex);
      if (linkMatches) {
        const relativeLink = linkMatches[1];
        const generatedDocsPath = path.join(
          __dirname,
          "..",
          "..",
          "generated",
          relativeLink
        );
        if (!fs.existsSync(generatedDocsPath)) {
          l = l.replace(
            `href="${relativeLink}"`,
            `href="${githubServerName}/${githubRepoName}/tree/main/${relativeLink}"`
          );
        }
      }

      devrelCategories[currentCategory].push(l);
    }
  });

  const overviewPage = `
    <!DOCTYPE html>
    <html>
    <head>
      <link rel="stylesheet" href="https://fonts.googleapis.com/icon?family=Material+Icons">
      <link rel="stylesheet" href="https://code.getmdl.io/1.3.0/material.indigo-pink.min.css">
      <script defer src="https://code.getmdl.io/1.3.0/material.min.js"></script>
      <title>Apigee DevRel</title>
      <style>
        body {
          background-color: #f5f5f5 !important
        }
    
        .doc-content {
          border-radius: 2px;
          padding: 80px 56px;
          margin: 20px 0;
        }
    
        h1 {
          text-transform: capitalize;
        }
    
        h2 {
          font-size: 32px;
          line-height: 36px;
          margin: 24px 0;
        }
    
        h3 {
          font-size: 22px;
          line-height: 26px;
          margin: 14px 0;
        }
    
        h4 {
          font-size: 18px;
          line-height: 18px;
        }
      </style>
    </head>
    <body>
    <header class="mdl-layout__header mdl-layout__header--scroll mdl-color--primary-dark mdl-color-text--grey-200">
      <div class="mdl-layout__header-row">
        <span class="mdl-layout-title">Apigee DevRel</span>
      </div>
    </header>
    <div class="mdl-grid mdl-color--grey-100">
      <div class="mdl-cell mdl-cell--1-col mdl-cell--hide-tablet mdl-cell--hide-phone"></div>
      <div class="doc-content mdl-color--white mdl-shadow--4dp content mdl-color-text--grey-800 mdl-cell mdl-cell--10-col-desktop mdl-cell--12-col-phone mdl-cell--12-col-tablet">    
        <div class="mdl-cell mdl-cell--12-col mdl-cell--hide-desktop">
            <h1>Apigee DevRel</h1>
        </div>
        ${devrelCategories["references"].join("")}
        ${devrelCategories["labs"].join("")}
        ${devrelCategories["tools"].join("")}
      </div>
    </div>
    </body>
    </html>
    `;

  const indexPath = path.join(__dirname, "..", "..", "generated", "index.html");
  fs.writeFileSync(indexPath, overviewPage, "utf-8");
})();
