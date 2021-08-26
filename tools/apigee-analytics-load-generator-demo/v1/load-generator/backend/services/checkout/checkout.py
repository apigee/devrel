import time
import random

def getCheckout(id):
    sleepTime = random.randint(1,20)
    print("random sleep: ",sleepTime)
    if id == 1:
        checkout = {
                "id":21,
                "items":[

                ],
                "itemsTotal":0,
                "adjustments":[

                ],
                "adjustmentsTotal":0,
                "total":0,
                "customer":{
                    "id":1,
                    "email":"shop@example.com",
                    "firstName":"John",
                    "lastName":"Doe",
                    "user":{
                        "id":1,
                        "username":"shop@example.com",
                        "enabled":"true"
                    },
                    "_links":{
                        "self":{
                            "href":"\/api\/v1\/customers\/1"
                        }
                    }
                },
                "channel":{
                    "id":1,
                    "code":"US_WEB",
                    "_links":{
                        "self":{
                            "href":"\/api\/v1\/channels\/US_WEB"
                        }
                    }
                },
                "currencyCode":"USD",
                "localeCode":"en_US",
                "checkoutState":"cart"
            }
    elif id == 2:
        checkout = {
                "id":21,
                "items":[

                ],
                "itemsTotal":0,
                "adjustments":[

                ],
                "adjustmentsTotal":0,
                "total":0,
                "customer":{
                    "id":1,
                    "email":"shop@example.com",
                    "firstName":"John",
                    "lastName":"Doe",
                    "user":{
                        "id":1,
                        "username":"shop@example.com",
                        "enabled":"true"
                    },
                    "_links":{
                        "self":{
                            "href":"\/api\/v1\/customers\/1"
                        }
                    }
                },
                "channel":{
                    "id":1,
                    "code":"US_WEB",
                    "_links":{
                        "self":{
                            "href":"\/api\/v1\/channels\/US_WEB"
                        }
                    }
                },
                "currencyCode":"USD",
                "localeCode":"en_US",
                "checkoutState":"cart"
            }
    elif id == 3:
        checkout = {
                "id":21,
                "items":[

                ],
                "itemsTotal":0,
                "adjustments":[

                ],
                "adjustmentsTotal":0,
                "total":0,
                "customer":{
                    "id":1,
                    "email":"shop@example.com",
                    "firstName":"John",
                    "lastName":"Doe",
                    "user":{
                        "id":1,
                        "username":"shop@example.com",
                        "enabled":"true"
                    },
                    "_links":{
                        "self":{
                            "href":"\/api\/v1\/customers\/1"
                        }
                    }
                },
                "channel":{
                    "id":1,
                    "code":"US_WEB",
                    "_links":{
                        "self":{
                            "href":"\/api\/v1\/channels\/US_WEB"
                        }
                    }
                },
                "currencyCode":"USD",
                "localeCode":"en_US",
                "checkoutState":"cart"
            }
    elif id == 4:
        checkout = {
                "id":21,
                "items":[

                ],
                "itemsTotal":0,
                "adjustments":[

                ],
                "adjustmentsTotal":0,
                "total":0,
                "customer":{
                    "id":1,
                    "email":"shop@example.com",
                    "firstName":"John",
                    "lastName":"Doe",
                    "user":{
                        "id":1,
                        "username":"shop@example.com",
                        "enabled":"true"
                    },
                    "_links":{
                        "self":{
                            "href":"\/api\/v1\/customers\/1"
                        }
                    }
                },
                "channel":{
                    "id":1,
                    "code":"US_WEB",
                    "_links":{
                        "self":{
                            "href":"\/api\/v1\/channels\/US_WEB"
                        }
                    }
                },
                "currencyCode":"USD",
                "localeCode":"en_US",
                "checkoutState":"cart"
            }
    elif id == 5:
        checkout = {
                "id":21,
                "items":[

                ],
                "itemsTotal":0,
                "adjustments":[

                ],
                "adjustmentsTotal":0,
                "total":0,
                "customer":{
                    "id":1,
                    "email":"shop@example.com",
                    "firstName":"John",
                    "lastName":"Doe",
                    "user":{
                        "id":1,
                        "username":"shop@example.com",
                        "enabled":"true"
                    },
                    "_links":{
                        "self":{
                            "href":"\/api\/v1\/customers\/1"
                        }
                    }
                },
                "channel":{
                    "id":1,
                    "code":"US_WEB",
                    "_links":{
                        "self":{
                            "href":"\/api\/v1\/channels\/US_WEB"
                        }
                    }
                },
                "currencyCode":"USD",
                "localeCode":"en_US",
                "checkoutState":"cart"
            }
    else:
        return Exception
    if sleepTime == id:
        print("sleeping")
        time.sleep (random.randint(0,7))
    return checkout