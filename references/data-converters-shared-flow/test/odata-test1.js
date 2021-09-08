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
let odataconverter = require('../sharedflowbundle/resources/jsc/odataconverter')

describe('OData converters', function() {
  describe('#ConvertODataToRest()', function() {
    it('should return valid and correct JSON object of OData input', function() {
      assert.equal(JSON.stringify(odataconverter.convertODataResponse(odataPayload, "orders")), JSON.stringify(restPayload));
    });
  });
});

let odataPayload = {
  "d": {
      "results": [
          {
              "__metadata": {
                  "id": "https://sap-orders-mock-h7pi7igbcq-ew.a.run.app/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SalesOrder('1')",
                  "uri": "https://sap-orders-mock-h7pi7igbcq-ew.a.run.app/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SalesOrder('1')",
                  "type": "API_SALES_ORDER_SRV.A_SalesOrderType",
                  "etag": "W/\"datetimeoffset'2016-09-02T06%3A15%3A47.1257050Z'\""
              },
              "SalesOrder": "9000000232",
              "SalesOrderType": "ZOR",
              "SalesOrganization": "2000",
              "DistributionChannel": "01",
              "OrganizationDivision": "",
              "SalesGroup": "",
              "SalesOffice": "",
              "SalesDistrict": "",
              "SoldToParty": "1004186",
              "CreationDate": "3/18/2021",
              "CreatedByUser": "SERGEY",
              "LastChangeDate": "",
              "SenderBusinessSystemName": "",
              "ExternalDocumentID": "",
              "LastChangeDateTime": "",
              "ExternalDocLastChangeDateTime": "",
              "PurchaseOrderByCustomer": "",
              "PurchaseOrderByShipToParty": "",
              "CustomerPurchaseOrderType": "",
              "CustomerPurchaseOrderDate": "",
              "SalesOrderDate": "3/15/2021",
              "TotalNetAmount": "1356.08",
              "TransactionCurrency": "EUR",
              "SDDocumentReason": "",
              "PricingDate": "3/18/2021",
              "PriceDetnExchangeRate": "",
              "RequestedDeliveryDate": "6/10/2021",
              "ShippingCondition": "",
              "CompleteDeliveryIsDefined": "",
              "ShippingType": "",
              "HeaderBillingBlockReason": "",
              "DeliveryBlockReason": "",
              "DeliveryDateTypeRule": "",
              "IncotermsClassification": "",
              "IncotermsTransferLocation": "",
              "IncotermsLocation1": "",
              "IncotermsLocation2": "",
              "IncotermsVersion": "",
              "CustomerPriceGroup": "",
              "PriceListType": "",
              "CustomerPaymentTerms": "",
              "PaymentMethod": "",
              "FixedValueDate": "",
              "AssignmentReference": "",
              "ReferenceSDDocument": "",
              "ReferenceSDDocumentCategory": "",
              "AccountingDocExternalReference": "",
              "CustomerAccountAssignmentGroup": "",
              "AccountingExchangeRate": "",
              "CustomerGroup": "",
              "AdditionalCustomerGroup1": "",
              "AdditionalCustomerGroup2": "",
              "AdditionalCustomerGroup3": "",
              "AdditionalCustomerGroup4": "",
              "AdditionalCustomerGroup5": "",
              "SlsDocIsRlvtForProofOfDeliv": "",
              "CustomerTaxClassification1": "",
              "CustomerTaxClassification2": "",
              "CustomerTaxClassification3": "",
              "CustomerTaxClassification4": "",
              "CustomerTaxClassification5": "",
              "CustomerTaxClassification6": "",
              "CustomerTaxClassification7": "",
              "CustomerTaxClassification8": "",
              "CustomerTaxClassification9": "",
              "TaxDepartureCountry": "",
              "VATRegistrationCountry": "",
              "SalesOrderApprovalReason": "",
              "SalesDocApprovalStatus": "",
              "OverallSDProcessStatus": "",
              "TotalCreditCheckStatus": "",
              "OverallTotalDeliveryStatus": "SCHEDULED",
              "OverallSDDocumentRejectionSts": "",
              "to_Item": {
                  "__deferred": {
                      "uri": "https://sap-orders-mock-h7pi7igbcq-ew.a.run.app/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SalesOrder('1')/to_Item"
                  }
              },
              "to_Partner": {
                  "__deferred": {
                      "uri": "https://sap-orders-mock-h7pi7igbcq-ew.a.run.app/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SalesOrder('1')/to_Partner"
                  }
              },
              "to_PaymentPlanItemDetails": {
                  "__deferred": {
                      "uri": "https://sap-orders-mock-h7pi7igbcq-ew.a.run.app/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SalesOrder('1')/to_PaymentPlanItemDetails"
                  }
              },
              "to_PricingElement": {
                  "__deferred": {
                      "uri": "https://sap-orders-mock-h7pi7igbcq-ew.a.run.app/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SalesOrder('1')/to_PricingElement"
                  }
              },
              "to_Text": {
                  "__deferred": {
                      "uri": "https://sap-orders-mock-h7pi7igbcq-ew.a.run.app/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SalesOrder('1')/to_Text"
                  }
              }
            }]
  }
};

let restPayload = {
  "orders": [
      {
          "SalesOrder": "9000000232",
          "SalesOrderType": "ZOR",
          "SalesOrganization": "2000",
          "DistributionChannel": "01",
          "SoldToParty": "1004186",
          "CreationDate": "3/18/2021",
          "CreatedByUser": "SERGEY",
          "SalesOrderDate": "3/15/2021",
          "TotalNetAmount": "1356.08",
          "TransactionCurrency": "EUR",
          "PricingDate": "3/18/2021",
          "RequestedDeliveryDate": "6/10/2021",
          "OverallTotalDeliveryStatus": "SCHEDULED"
      }]
    };