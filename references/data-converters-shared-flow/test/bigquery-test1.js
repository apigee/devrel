var assert = require('assert');
var bigqueryconverter = require('../sharedflowbundle/resources/jsc/bigqueryconverter')

describe('BigQuery converters', function() {
  describe('#ConvertBigQueryToRest()', function() {
    it('should return valid and correct JSON object of BigQuery input', function() {
      assert.equal(JSON.stringify(bigqueryconverter.ConvertBigQueryResponse(bigquery_payload, "trends")), JSON.stringify({
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

var bigquery_payload = {
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