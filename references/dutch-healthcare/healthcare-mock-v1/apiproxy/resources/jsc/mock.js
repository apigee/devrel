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

const verb = context.getVariable("request.verb");
const path = context.getVariable("mock.path");
var response = {"error": "not found"};
var status = 404;

// metadata
if(verb === "GET" && path === "/metadata") {
  status = 200;
  response = {
    "resourceType": "CapabilityStatement",
    "id": "0c18f1d5-d005-4031-9e67-6222ea0308b3",
    "meta": {
      "versionId": "417234b7-56dc-4e10-b977-0a915de914e0",
      "lastUpdated": "2021-05-18T07:01:07.7159006+00:00"
    },
    "language": "en-US",
    "url": "metadata",
    "version": "1.0",
    "name": "Vonk FHIR server 3.6.0 CapabilityStatement",
    "status": "active",
    "experimental": true,
    "date": "2021-05-18T07:01:07.7402625+00:00",
    "publisher": "Firely",
    "contact": [
      {
        "name": "Firely",
        "telecom": [
          {
            "system": "email",
            "value": "server@fire.ly",
            "use": "work"
          }
        ]
      },
      {
        "name": "Firely",
        "telecom": [
          {
            "system": "email",
            "value": "vonk@fire.ly",
            "use": "work"
          }
        ]
      },
      {
        "name": "Licensed to",
        "telecom": [
          {
            "system": "email",
            "value": "simplifier@fire.ly",
            "use": "work"
          }
        ]
      }
    ],
    "kind": "instance",
    "software": {
      "name": "Vonk",
      "version": "3.6.0",
      "releaseDate": "2020-05-26T08:07:30+00:00"
    },
    "fhirVersion": "3.0.2",
      "format": [
      "xml",
      "json"
    ],
    "rest": [
      {
        "mode": "server",
        "interaction": [
          {
            "code": "search-system"
          }
        ],
        "searchParam": [
          {
            "name": "_count",
            "type": "number",
            "documentation": "The number of resources returned per page"
          },
          {
            "name": "_format",
            "type": "string",
            "documentation": "Specify the returned format of the payload response"
          },
          {
            "name": "_has",
            "type": "string",
            "documentation": "Enables querying a reverse chain"
          },
          {
            "name": "_id",
            "definition": "http://hl7.org/fhir/SearchParameter/Resource-id",
            "type": "token",
            "documentation": "Logical id of this artifact"
          },
          {
            "name": "_lastUpdated",
            "definition": "http://hl7.org/fhir/SearchParameter/Resource-lastUpdated",
            "type": "date",
            "documentation": "When the resource version last changed"
          },
          {
            "name": "_profile",
            "definition": "http://hl7.org/fhir/SearchParameter/Resource-profile",
            "type": "uri",
            "documentation": "Profiles this resource claims to conform to"
          },
          {
            "name": "_security",
            "definition": "http://hl7.org/fhir/SearchParameter/Resource-security",
            "type": "token",
            "documentation": "Security Labels applied to this resource"
          },
          {
            "name": "_tag",
            "definition": "http://hl7.org/fhir/SearchParameter/Resource-tag",
            "type": "token",
            "documentation": "Tags applied to this resource"
          },
          {
            "name": "_type",
            "type": "string",
            "documentation": "Enables querying for a type of resource"
          }
        ]
      }
    ]
  };
}
// Patient
if(verb === "GET" && path === "/Patient/nl-core-patient-03") {
  status = 200;
  response = {
    "resourceType": "Patient",
    "id": "nl-core-patient-03",
    "meta": {
      "versionId": "1",
      "lastUpdated": "2021-04-29T08:06:45.378+00:00",
      "profile": [
        "http://fhir.nl/fhir/StructureDefinition/nl-core-patient"
      ]
    },
    "text": {
      "status": "additional",
      "div": "<div xmlns=\"http://www.w3.org/1999/xhtml\"><div><p>BSN: 123456782</p><p>Naam: Irma Jongeneel-de Haas</p><p>Geslacht: Vrouw</p><p>Geboortedatum: 1970-03-04</p><p>Telefoon: 030-2345456</p><p>E-mail: user@home.nl</p><p>Adres: Straatweg 12bII, 1000AA Amsterdam</p><p>Burgerlijke staat: gehuwd</p><p>Eerste relatie/contactpersoon is haar man Gerard Eckdom via telefoonnummer\r\n                    015-23456789</p><p>Huisarts: Huisartsenpraktijk Van Eijk</p></div></div>"
    },
    "identifier": [
      {
        "use": "official",
        "system": "http://fhir.nl/fhir/NamingSystem/bsn",
        "value": "123456782"
      }
    ],
    "active": true,
    "name": [
      {
        "extension": [
          {
            "url": "http://hl7.org/fhir/StructureDefinition/humanname-assembly-order",
            "valueCode": "NL4"
          }
        ],
        "use": "official",
        "family": "Jongeneel-de Haas",
        "_family": {
          "extension": [
            {
              "url": "http://hl7.org/fhir/StructureDefinition/humanname-own-name",
              "valueString": "Jongeneel"
            },
            {
              "url": "http://hl7.org/fhir/StructureDefinition/humanname-partner-prefix",
              "valueString": "de"
            },
            {
              "url": "http://hl7.org/fhir/StructureDefinition/humanname-partner-name",
              "valueString": "Haas"
            }
          ]
        },
        "given": [
          "Irma",
          "I."
        ],
        "_given": [
          {
            "extension": [
              {
                "url": "http://hl7.org/fhir/StructureDefinition/iso21090-EN-qualifier",
                "valueCode": "CL"
              }
            ]
          },
          {
            "extension": [
              {
                "url": "http://hl7.org/fhir/StructureDefinition/iso21090-EN-qualifier",
                "valueCode": "IN"
              }
            ]
          }
        ]
      }
    ],
    "telecom": [
      {
        "extension": [
          {
            "url": "http://nictiz.nl/fhir/StructureDefinition/zib-ContactInformation-TelecomType",
            "valueCodeableConcept": {
              "coding": [
                {
                  "system": "urn:oid:2.16.840.1.113883.2.4.3.11.60.40.4.22.1",
                  "code": "LL",
                  "display": "Vast telefoonnummer"
                }
              ]
            }
          }
        ],
        "system": "phone",
        "value": "030-23454567",
        "use": "home"
      },
      {
        "system": "email",
        "value": "user@home.nl",
        "use": "home"
      }
    ],
    "gender": "female",
    "_gender": {
      "extension": [
        {
          "url": "http://nictiz.nl/fhir/StructureDefinition/code-specification",
          "valueCodeableConcept": {
            "coding": [
              {
                "system": "http://hl7.org/fhir/v3/AdministrativeGender",
                "code": "F",
                "display": "Vrouw"
              }
            ]
          }
        }
      ]
    },
    "birthDate": "1970-03-04",
    "deceasedBoolean": false,
    "address": [
      {
        "extension": [
          {
            "url": "http://nictiz.nl/fhir/StructureDefinition/zib-AddressInformation-AddressType",
            "valueCodeableConcept": {
              "coding": [
                {
                  "system": "http://hl7.org/fhir/v3/AddressUse",
                  "code": "HP",
                  "display": "Officieel adres"
                }
              ]
            }
          },
          {
            "url": "http://fhir.nl/fhir/StructureDefinition/nl-core-address-official",
            "valueBoolean": true
          }
        ],
        "use": "home",
        "line": [
          "Straatweg 12bII"
        ],
        "_line": [
          {
            "extension": [
              {
                "url": "http://hl7.org/fhir/StructureDefinition/iso21090-ADXP-streetName",
                "valueString": "Straatweg"
              },
              {
                "url": "http://hl7.org/fhir/StructureDefinition/iso21090-ADXP-houseNumber",
                "valueString": "12"
              },
              {
                "url": "http://hl7.org/fhir/StructureDefinition/iso21090-ADXP-buildingNumberSuffix",
                "valueString": "bII"
              }
            ]
          }
        ],
        "city": "Weesp",
        "postalCode": "1012AB",
        "country": "NLD",
        "_country": {
          "extension": [
            {
              "url": "http://nictiz.nl/fhir/StructureDefinition/code-specification",
              "valueCodeableConcept": {
                "coding": [
                  {
                    "system": "urn:oid:2.16.840.1.113883.2.4.4.16.34",
                    "code": "6030",
                    "display": "Nederland"
                  }
                ]
              }
            }
          ]
        }
      }
    ],
    "maritalStatus": {
      "coding": [
        {
          "system": "http://hl7.org/fhir/v3/MaritalStatus",
          "code": "M",
          "display": "Married"
        }
      ]
    },
    "multipleBirthBoolean": false,
    "contact": [
      {
        "relationship": [
          {
            "coding": [
              {
                "system": "urn:oid:2.16.840.1.113883.2.4.3.11.22.472",
                "code": "1",
                "display": "Eerste relatie/contactpersoon"
              }
            ]
          },
          {
            "coding": [
              {
                "system": "http://hl7.org/fhir/v3/RoleCode",
                "code": "HUSB",
                "display": "Husband"
              }
            ]
          }
        ],
        "name": {
          "use": "official",
          "family": "Eckdom",
          "given": [
            "Gerard"
          ]
        },
        "telecom": [
          {
            "extension": [
              {
                "url": "http://nictiz.nl/fhir/StructureDefinition/zib-ContactInformation-TelecomType",
                "valueCodeableConcept": {
                  "coding": [
                    {
                      "system": "urn:oid:2.16.840.1.113883.2.4.3.11.60.40.4.22.1",
                      "code": "LL",
                      "display": "Vast telefoonnummer"
                    }
                  ]
                }
              }
            ],
            "system": "phone",
            "value": "015-23456789",
            "use": "home"
          }
        ]
      }
    ],
    "generalPractitioner": [
      {
        "reference": "https://fhir.simplifier.net/NictizSTU3-Zib2017/Organization/nl-core-organization-01",
        "display": "Maatschap Vaste Huisarts"
      }
    ]
  };
}
// AllergyIntolerance
if(verb === "GET" && path === "/AllergyIntolerance/zib-allergyintolerance-01") {
  status = 200;
  response = {
    "resourceType": "AllergyIntolerance",
    "id": "zib-allergyintolerance-01",
    "meta": {
      "profile": [
        "http://nictiz.nl/fhir/StructureDefinition/zib-AllergyIntolerance"
      ],
      "versionId": "1",
      "lastUpdated": "2021-04-29T08:06:45.385+00:00"
    },
    "text": {
      "status": "extensions",
      "div": "<div xmlns=\"http://www.w3.org/1999/xhtml\"><table><caption>\r\n                    Allergie/intolerantie. Patiënt: Johan XXX_Helleman. Categorie: \r\n                    <span title=\"Allergy to substance (419199007 - SNOMED CT)\">Allergy to substance</span>\r\n                    , Status: actief / bevestigd\r\n                </caption><tbody><tr><th>Code</th><td><span title=\"Bee venom (288328004 - SNOMED CT)\">Bee venom</span></td></tr><tr><th>Eerste symptomen</th><td>2008-11-08</td></tr><tr><th>Meest recente voorkomen</th><td>2009-11-15</td></tr><tr><th>Reactie</th><td><ul><li><div><span title=\"Severe (24484000 - SNOMED CT)\">Severe</span></div><div><span title=\"Nausea and vomiting (16932000 - SNOMED CT)\">Nausea and vomiting</span></div></li></ul></td></tr></tbody></table></div>"
    },
    "clinicalStatus": "active",
    "_clinicalStatus": {
      "extension": [
        {
          "url": "http://nictiz.nl/fhir/StructureDefinition/code-specification",
          "valueCodeableConcept": {
            "coding": [
              {
                "system": "http://hl7.org/fhir/v3/ActStatus",
                "code": "active",
                "display": "Active"
              }
            ]
          }
        }
      ]
    },
    "verificationStatus": "confirmed",
    "category": [
      "environment"
    ],
    "_category": [
      {
        "extension": [
          {
            "url": "http://nictiz.nl/fhir/StructureDefinition/code-specification",
            "valueCodeableConcept": {
              "coding": [
                {
                  "system": "http://snomed.info/sct",
                  "code": "419199007",
                  "display": "Allergy to substance"
                }
              ]
            }
          }
        ]
      }
    ],
    "criticality": "high",
    "_criticality": {
      "extension": [
        {
          "url": "http://nictiz.nl/fhir/StructureDefinition/code-specification",
          "valueCodeableConcept": {
            "coding": [
              {
                "system": "http://snomed.info/sct",
                "code": "24484000",
                "display": "Severe"
              }
            ]
          }
        }
      ]
    },
    "code": {
      "coding": [
        {
          "system": "http://snomed.info/sct",
          "code": "288328004",
          "display": "Bee venom"
        }
      ]
    },
    "patient": {
      "reference": "https://fhir.simplifier.net/NictizSTU3-Zib2017/Patient/nl-core-patient-01",
      "display": "Johan XXX_Helleman"
    },
    "onsetDateTime": "2008-11-08",
    "lastOccurrence": "2009-11-15",
    "reaction": [
      {
        "manifestation": [
          {
            "coding": [
              {
                "system": "http://snomed.info/sct",
                "code": "16932000",
                "display": "Nausea and vomiting"
              }
            ]
          }
        ],
        "severity": "severe",
        "_severity": {
          "extension": [
            {
              "url": "http://nictiz.nl/fhir/StructureDefinition/code-specification",
              "valueCodeableConcept": {
                "coding": [
                  {
                    "system": "http://snomed.info/sct",
                    "code": "24484000",
                    "display": "Severe"
                  }
                ]
              }
            }
          ]
        }
      }
    ]
  };
}

context.setVariable("response.status.code", status);
context.setVariable("response.content", JSON.stringify(response));
context.setVariable("response.header.Content-Type", "application/json");
