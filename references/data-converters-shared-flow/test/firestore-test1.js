var assert = require('assert');
var firestoreconverter = require('../sharedflowbundle/resources/jsc/firestoreconverter')

describe('Firestore converters', function() {
  describe('#Convert Firestore response to REST()', function() {
    it('should return valid and correct JSON object of Firestore input', function() {
      assert.equal(JSON.stringify(firestoreconverter.convertFsResponse(firestore_payload, "jokes", "jokeId")), JSON.stringify({
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