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


var assert = require('assert');
var firestoreconverter = require('../sharedflowbundle/resources/jsc/firestoreconverter')

describe('Firestore converters', function() {
  describe('#Convert Firestore response to REST()', function() {
    it('should return valid and correct JSON object of Firestore input', function() {
      assert.equal(JSON.stringify(firestoreconverter.convertFirestoreResponse(firestore_payload, "jokes", "jokeId")), JSON.stringify({
        jokes: [
          {
            jokeId: "1",
            location: "-50, 50"
          },
          {
            jokeId: '2'
          }        
        ]
      }));
    });
  });
});

let firestore_payload = {
  documents: [
    {
      name: "projects/bruno-1407a/databases/(default)/documents/jokes/1",
      fields: {
        jokeId: {
          stringValue: "1"
        },
        location: {
          geoPointValue: {
            latitude: -50,
            longitude: 50
          }
        },
        comments: {
          arrayValue: {
            values: [
              {
                mapValue: {
                  fields: {
                    commentId: {
                      stringValue: "1"
                    }
                  }
                }
              },
              {
                mapValue: {
                  fields: {
                    commentId: {
                      stringValue: "2"
                    }
                  }
                }
              }                   
            ]
          }
        }
      }
    },
    {
      name: "projects/bruno-1407a/databases/(default)/documents/jokes/2",
      fields: {
        jokeId: {
          stringValue: "2"
        },
        comments: {
          arrayValue: {
            values: [
              {
                mapValue: {
                  fields: {
                    commentId: {
                      stringValue: "1"
                    }
                  }
                }
              }               
            ]
          }
        }
      }
    }
  ]
}