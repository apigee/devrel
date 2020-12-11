# CardsControllerApi

All URIs are relative to *https://httpbin.org*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getCardsUsingGET**](CardsControllerApi.md#getCardsUsingGET) | **GET** /api/cards | Cards GET operation


<a name="getCardsUsingGET"></a>
# **getCardsUsingGET**
> CardsOut getCardsUsingGET(customerId)

Cards GET operation

### Example
```java
// Import classes:
//import io.swagger.client.ApiClient;
//import io.swagger.client.ApiException;
//import io.swagger.client.Configuration;
//import io.swagger.client.auth.*;
//import io.swagger.client.api.CardsControllerApi;

ApiClient defaultClient = Configuration.getDefaultApiClient();

// Configure OAuth2 access token for authorization: oauth2
OAuth oauth2 = (OAuth) defaultClient.getAuthentication("oauth2");
oauth2.setAccessToken("YOUR ACCESS TOKEN");

// Configure OAuth2 access token for authorization: oauth2-password
OAuth oauth2-password = (OAuth) defaultClient.getAuthentication("oauth2-password");
oauth2-password.setAccessToken("YOUR ACCESS TOKEN");

CardsControllerApi apiInstance = new CardsControllerApi();
String customerId = "customerId_example"; // String | customerId
try {
    CardsOut result = apiInstance.getCardsUsingGET(customerId);
    System.out.println(result);
} catch (ApiException e) {
    System.err.println("Exception when calling CardsControllerApi#getCardsUsingGET");
    e.printStackTrace();
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **customerId** | **String**| customerId |

### Return type

[**CardsOut**](CardsOut.md)

### Authorization

[oauth2](../README.md#oauth2), [oauth2-password](../README.md#oauth2-password)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

