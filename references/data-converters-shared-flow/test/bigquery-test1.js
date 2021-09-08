/**
 * Copyright 2021 Google LLC
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

let assert = require('assert');
let bigqueryconverter = require('../sharedflowbundle/resources/jsc/bigqueryconverter')

describe('BigQuery converters', function() {
  describe('#ConvertBigQueryToRest()', function() {
    it('should return valid and correct JSON object of BigQuery input', function() {
      assert.equal(JSON.stringify(bigqueryconverter.convertBigQueryResponse(bigQueryPayload, "trends")), JSON.stringify({
        "trends": [
            {
                "dma_id": "522",
                "term": "steven johnson nfl",
                "week": "2021-08-22",
                "score": null,
                "rank": "3",
                "percent_gain": "1400",
                "refresh_date": "2021-08-25",
                "dma_name": "Columbus GA"
            }
        ]}));
    });
  });
});

let bigQueryPayload = {
  "kind": "bigquery#queryResponse",
  "schema": {
      "fields": [
          {
              "name": "dma_id",
              "type": "INTEGER",
              "mode": "NULLABLE"
          },
          {
              "name": "term",
              "type": "STRING",
              "mode": "NULLABLE"
          },
          {
              "name": "week",
              "type": "DATE",
              "mode": "NULLABLE"
          },
          {
              "name": "score",
              "type": "INTEGER",
              "mode": "NULLABLE"
          },
          {
              "name": "rank",
              "type": "INTEGER",
              "mode": "NULLABLE"
          },
          {
              "name": "percent_gain",
              "type": "INTEGER",
              "mode": "NULLABLE"
          },
          {
              "name": "refresh_date",
              "type": "DATE",
              "mode": "NULLABLE"
          },
          {
              "name": "dma_name",
              "type": "STRING",
              "mode": "NULLABLE"
          }
      ]
  },
  "jobReference": {
      "projectId": "bruno-1407a",
      "jobId": "job_Ju_yPwuiOrn-hWJVu6hllXQ5_-K1",
      "location": "US"
  },
  "totalRows": "1000",
  "pageToken": "BEGXTEE3PMAQAAASA4EAAEEAQCAAKGQEBBSBAZBAWCXBK===",
  "rows": [
      {
          "f": [
              {
                  "v": "522"
              },
              {
                  "v": "steven johnson nfl"
              },
              {
                  "v": "2021-08-22"
              },
              {
                  "v": null
              },
              {
                  "v": "3"
              },
              {
                  "v": "1400"
              },
              {
                  "v": "2021-08-25"
              },
              {
                  "v": "Columbus GA"
              }
          ]
      }]
    };